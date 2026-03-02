import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';

// --- MAPAS DE REFERENCIA ---

final Map<String, String> priorityMap = {'Urgente': '1', 'Alta': '3', 'Media': '5', 'Baja': '7', 'Menor': '9'};

// --- UTILIDADES DE FORMATO ---

String extractTime(String? val) {
  if (val == null || val.isEmpty) return '';
  String t = val;
  if (t.contains('T')) {
    t = t.split('T')[1];
  }
  return t.replaceAll('Z', '');
}

String ensureIsoDate(String val) {
  if (val.isEmpty) return "";
  if (val.contains('T')) return val;
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(val)) {
    return "${val}T00:00:00Z";
  }
  return val;
}

String ensureIsoTime(String? dateContext, String time) {
  if (time.isEmpty) return "";
  String timePart = time;
  if (time.contains('T')) {
    timePart = time.split('T')[1];
  }
  if (timePart.length == 5) timePart = "$timePart:00";
  if (!timePart.endsWith('Z')) timePart = "${timePart}Z";
  return timePart;
}

// --- LLAMADAS A LA API ---

/// Obtiene las solicitudes usando paginación para asegurar que se traigan todos los registros.
Future<List<Map<String, dynamic>>> fetchRequest({String? filter}) async {
  List<Map<String, dynamic>> allRecords = [];
  int skip = 0;
  const int pageSize = 100;
  bool hasMore = true;

  try {
    while (hasMore) {
      String url = '${Endpoint.request}?\$skip=$skip&\$top=$pageSize&\$limit=$pageSize&\$orderBy=Created desc';
      if (filter != null && filter.isNotEmpty) {
        url += '&\$filter=$filter';
      }

      final response = await http.get(Uri.parse(url), headers: {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': Token.token});

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final records = jsonResponse['records'] as List;

        if (records.isEmpty) {
          hasMore = false;
        } else {
          // Mapeo básico para asegurar que las llaves existan
          final mapped = records.map((r) => Map<String, dynamic>.from(r)).toList();
          allRecords.addAll(mapped);

          if (records.length < pageSize) {
            hasMore = false;
          } else {
            skip += pageSize;
          }
        }
      } else {
        hasMore = false;
        if (allRecords.isEmpty) throw Exception('Error API: ${response.statusCode}');
      }
    }
  } catch (e) {
    debugPrint('Error en fetchRequest: $e');
  }
  return allRecords;
}

Future<Map<String, int>> fetchStatuses() async {
  try {
    final response = await http.get(Uri.parse('${Endpoint.baseUrl}/api/v1/models/R_Status'), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      final records = jsonResponse['records'] as List;
      return {for (var r in records) r['Name']: r['id']};
    }
  } catch (e) {
    debugPrint('Error fetching statuses: $e');
  }
  return {};
}

/// Procesa la lista cruda de la API para calcular horas y formatear la UI.
Future<Map<String, dynamic>> processRequests(List<dynamic> requests, Map<String, int> statusIdMap) async {
  List<dynamic> rawRequests = requests.map((req) {
    final newReq = Map<String, dynamic>.from(req);
    if (newReq['DateCompletePlan'] != null && newReq['DateCompletePlan'].toString().isNotEmpty) {
      newReq['DateStartPlan'] = newReq['DateCompletePlan'];
    }
    return newReq;
  }).toList();

  double consumed = 0.0;
  double estimated = 0.0;

  // Filtrar las que NO están vinculadas a tareas de proyecto (según tu lógica original)
  final visibleRequests = requests.where((req) => req['Record_UU'] == null || req['Record_UU'].toString().isEmpty).toList();

  List<Map<String, dynamic>> processedRequests = [];

  for (var req in visibleRequests) {
    final statusName = req['R_Status_ID']?['identifier'] ?? req['R_Status_Name'] ?? '';
    final qtyPlan = (req['QtyPlan'] as num?)?.toDouble() ?? 0.0;

    // Lógica de horas
    if (statusName == '9_Final Close' || req['R_Status_ID']?['id'] == 103) {
      consumed += qtyPlan;
    } else {
      estimated += qtyPlan;
    }

    // Formateo de UI
    String level = req['Priority']?['identifier'] ?? 'Baja';
    String status = statusName;
    int? statusId = req['R_Status_ID']?['id'];

    if (statusId != null && statusIdMap.isNotEmpty) {
      for (var entry in statusIdMap.entries) {
        if (entry.value == statusId) {
          status = entry.key;
          break;
        }
      }
    }

    Color baseColor = Colors.green;
    if (level == 'Urgente')
      baseColor = Colors.purple;
    else if (level == 'Alta')
      baseColor = Colors.red;
    else if (level == 'Media')
      baseColor = Colors.amber.shade800;
    else if (level == 'Menor')
      baseColor = Colors.grey;

    String formattedTime = req['Created'] ?? '';
    try {
      if (formattedTime.isNotEmpty) {
        final DateTime date = DateTime.parse(formattedTime).toLocal();
        formattedTime = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}

    processedRequests.add({
      'id': req['DocumentNo'] ?? req['id'].toString(),
      'realId': req['id'],
      'situation': req['R_RequestType_ID']?['identifier'] ?? 'Solicitud',
      'description': req['Summary'] ?? '',
      'level': level,
      'status': status,
      'statusId': statusId,
      'time': formattedTime,
      'levelColor': baseColor,
      'levelBgColor': baseColor.withOpacity(0.2),
      'statusColor': Colors.grey,
      'dateStartPlan': req['DateStartPlan'] ?? '',
      'dateCompletePlan': req['DateCompletePlan'] ?? '',
      'startTime': extractTime(req['StartTime']),
      'endTime': extractTime(req['EndTime']),
      'qtyPlan': req['QtyPlan']?.toString() ?? '',
      'startDate': req['StartDate'],
      'closeDate': req['CloseDate'],
      'userName': req['AD_User_ID']?['identifier'] ?? '',
      'bpName': req['C_BPartner_ID']?['identifier'] ?? '',
    });
  }

  return {'rawRequests': rawRequests, 'requests': processedRequests, 'consumedHours': consumed, 'estimatedHours': estimated};
}

Future<Map<String, dynamic>> updateRemoteRequest({required dynamic id, String? priority, int? statusId, String? statusIdentifier, String? summary, String? dateStartPlan, String? dateCompletePlan, String? startTime, String? endTime, double? qtyPlan, String? startDate, String? closeDate}) async {
  try {
    final url = Uri.parse('${Endpoint.request}/$id');
    final Map<String, dynamic> data = {};

    if (priority != null) data['Priority'] = priorityMap[priority];
    if (summary != null) data['Summary'] = summary;

    if (statusId != null) {
      data['R_Status_ID'] = statusId;
    } else if (statusIdentifier != null) {
      data['R_Status_ID'] = {'identifier': statusIdentifier};
    }

    if (dateStartPlan != null && dateStartPlan.isNotEmpty) data['DateStartPlan'] = ensureIsoDate(dateStartPlan);
    if (dateCompletePlan != null && dateCompletePlan.isNotEmpty) data['DateCompletePlan'] = ensureIsoDate(dateCompletePlan);
    if (startTime != null && startTime.isNotEmpty) data['StartTime'] = ensureIsoTime(dateStartPlan, startTime);
    if (endTime != null && endTime.isNotEmpty) data['EndTime'] = ensureIsoTime(dateCompletePlan ?? dateStartPlan, endTime);
    if (qtyPlan != null) data['QtyPlan'] = qtyPlan;

    if (startDate != null) data['StartDate'] = startDate;
    if (closeDate != null) data['CloseDate'] = closeDate;

    final response = await http.put(url, headers: {'Content-Type': 'application/json', 'Authorization': Token.token}, body: jsonEncode(data));

    if (response.statusCode != 200 && response.statusCode != 201) {
      return {'success': false, 'error': 'Error ${response.statusCode}'};
    }
    return {'success': true};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

Future<bool> deleteRequestApi(dynamic id) async {
  try {
    final response = await http.delete(Uri.parse('${Endpoint.request}/$id'), headers: {'Authorization': Token.token});
    return response.statusCode == 200 || response.statusCode == 204;
  } catch (e) {
    debugPrint('Error deleting request: $e');
    return false;
  }
}
