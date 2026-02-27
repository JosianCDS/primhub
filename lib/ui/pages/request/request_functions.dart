import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:http/http.dart';

import '../../../api/token.dart';

/// DEPRECATED: Use updateRequest instead for more flexibility.
Future<bool> updateRequestStatus(String id, String newStatusIdentifier) async {
  try {
    final response = await put(
      Uri.parse('${Endpoint.request}/$id'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': Token.token,
      },
      body: jsonEncode({
        'R_Status_ID': {'identifier': newStatusIdentifier},
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return true;
    } else {
      debugPrint('Error actualizando estado: ${response.body}');
      return false;
    }
  } catch (e) {
    debugPrint('Excepción al actualizar estado: $e');
    return false;
  }
}

Future<List<Map<String, dynamic>>> fetchRequest({String? filter}) async {
  List<Map<String, dynamic>> allRecords = [];
  int skip = 0;
  const int pageSize = 100; // Tamaño de bloque que el servidor parece permitir
  bool hasMore = true;

  try {
    while (hasMore) {
      String url =
          '${Endpoint.request}?\$skip=$skip&\$top=$pageSize&\$limit=$pageSize';
      if (filter != null && filter.isNotEmpty) {
        url += '&\$filter=$filter';
      }
      // Solicitamos por bloques usando $skip para avanzar
      final response = await get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': Token.token,
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final records = jsonResponse['records'] as List;

        if (records.isEmpty) {
          hasMore = false;
        } else {
          final mappedRecords = records.map((record) {
            return {
              'id': record['id'],
              'Summary': record['Summary'],
              'DocumentNo': record['DocumentNo'],
              'R_RequestType_ID': record['R_RequestType_ID']?['id'],
              'R_RequestType_Name': record['R_RequestType_ID']?['identifier'],
              'R_Status_ID': record['R_Status_ID']?['id'],
              'R_Status_Name': record['R_Status_ID']?['identifier'],
              'Priority': record['Priority']?['id'],
              'Priority_Name': record['Priority']?['identifier'],
              'EndTime': record['EndTime'],
              'StartTime': record['StartTime'],
              'DateCompletePlan': record['DateCompletePlan'],
              'DateStartPlan': record['DateStartPlan'],
              'QtyPlan': record['QtyPlan'],
              'Created': record['Created'],
              'StartDate': record['StartDate'],
              'CloseDate': record['CloseDate'],
              'AD_User_Name': record['AD_User_ID']?['identifier'],
              'C_BPartner_Name': record['C_BPartner_ID']?['identifier'],
              'identifier1': record['r status'],
              'Record_UU': record['Record_UU'],
            };
          }).toList();

          allRecords.addAll(mappedRecords);

          // Si recibimos menos de lo pedido, es la última página
          if (records.length < pageSize) {
            hasMore = false;
          } else {
            skip += pageSize;
          }
        }
      } else {
        debugPrint(
          'Error al cargar bloque (skip: $skip): ${response.statusCode}',
        );
        hasMore = false;
        // Si falló la primera carga, lanzamos error, si no, devolvemos lo que tenemos
        if (allRecords.isEmpty) {
          throw Exception(
            'Error al cargar solicitudes: ${response.statusCode}',
          );
        }
      }
    }
    return allRecords;
  } catch (e) {
    debugPrint(e.toString());
    return allRecords;
  }
}

Future<Map<String, dynamic>> updateRemoteRequest({
  required dynamic id,
  String? priority,
  Map<String, String>? priorityMap,
  int? statusId,
  String? statusIdentifier,
  String? summary,
  String? dateStartPlan,
  String? dateCompletePlan,
  String? startTime,
  String? endTime,
  double? qtyPlan,
  String? startDate,
  String? closeDate,
}) async {
  try {
    final url = Uri.parse('${Endpoint.request}/$id');
    final Map<String, dynamic> data = {};

    if (priority != null && priorityMap != null)
      data['Priority'] = priorityMap[priority];
    if (summary != null) data['Summary'] = summary;

    if (statusId != null) {
      data['R_Status_ID'] = statusId;
    } else if (statusIdentifier != null) {
      data['R_Status_ID'] = {'identifier': statusIdentifier};
    }

    if (dateStartPlan != null && dateStartPlan.isNotEmpty)
      data['DateStartPlan'] = _ensureIsoDate(dateStartPlan);
    if (dateCompletePlan != null && dateCompletePlan.isNotEmpty)
      data['DateCompletePlan'] = _ensureIsoDate(dateCompletePlan);
    if (startTime != null && startTime.isNotEmpty)
      data['StartTime'] = _ensureIsoTime(startTime);
    if (endTime != null && endTime.isNotEmpty)
      data['EndTime'] = _ensureIsoTime(endTime);
    if (qtyPlan != null) data['QtyPlan'] = qtyPlan;

    if (startDate != null) data['StartDate'] = startDate;
    if (closeDate != null) data['CloseDate'] = closeDate;

    final body = jsonEncode(data);

    debugPrint('Update Payload: $body');

    final response = await put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': Token.token,
      },
      body: body,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      debugPrint('Update Error ${response.statusCode}: ${response.body}');
      return {
        'success': false,
        'error': 'Error ${response.statusCode}: ${response.body}',
        'payload': body,
      };
    }
    return {'success': true};
  } catch (e) {
    debugPrint('Error updating request: $e');
    String errorMessage = e.toString();
    if (errorMessage.contains('SocketException') ||
        errorMessage.contains('Failed host lookup')) {
      errorMessage =
          'Error de conexión: No se puede acceder al servidor. Verifique su conexión a internet.';
    }
    return {
      'success': false,
      'error': errorMessage,
      'payload': 'Exception occurred',
    };
  }
}

String _ensureIsoDate(String val) {
  if (val.isEmpty) return "";
  if (val.contains('T')) return val;
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(val)) {
    return "${val}T00:00:00Z";
  }
  return val;
}

String _ensureIsoTime(String time) {
  if (time.isEmpty) return "";
  String timePart = time;
  if (time.contains('T')) {
    timePart = time.split('T')[1];
  }
  if (timePart.length == 5) timePart = "$timePart:00";
  if (!timePart.endsWith('Z')) timePart = "${timePart}Z";
  return timePart;
}
