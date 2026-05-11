import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/api/api_utils.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/ImagesManagment/postAttachments.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/api/global_cache.dart';

// --- MAPAS DE REFERENCIA ---

const Map<int, String> SUPPORT_STATUS_MAPPING = {
  1000003: 'Recibida',
  1000016: 'Asignada',
  1000019: 'Archivada',
  1000000: 'En proceso',
  1000009: 'En espera del cliente',
  1000017: 'En pruebas de calidad',
  1000001: 'Por entregar',
  1000030: 'En evaluacion del cliente',
  1000002: 'Aprobada por el cliente',
  1000018: 'Implementada en produccion',
  1000015: 'Anulada',
};

const Map<String, String> priorityMap = {'Urgente': '1', 'Alta': '3', 'Media': '5', 'Baja': '7', 'Menor': '9'};

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
  if (time.isEmpty) return '';

  // 1. Get a clean time part (HH:mm:ss)
  String timePart = time;
  if (time.contains('T')) {
    timePart = time.split('T')[1];
  }
  timePart = timePart.replaceAll('Z', '');
  if (timePart.length == 5) timePart = "$timePart:00";

  // 2. Return format specifically expected by iDempiere for Time fields (HH:mm:ss'Z')
  return "${timePart}Z";
}

String? getDropdownValue(dynamic rawValue) {
  final extracted = DocumentsLogic.extractValue(rawValue);
  return extracted == 'N/A' ? null : extracted;
}

String stripHtmlTags(String htmlString) {
  RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
  return htmlString.replaceAll(exp, ' ').replaceAll(RegExp(r'\s+'), ' ').replaceAll('&nbsp;', ' ').trim();
}

double? tryGetDouble(Map<String, dynamic> map, List<String> keys) {
  for (var key in keys) {
    if (map.containsKey(key) && map[key] != null) {
      final val = map[key];
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
    }
  }
  return null;
}

/// Extrae el ID de la ficha de producto de forma robusta.
int? extractProductChipId(Map<String, dynamic> req) {
  final raw = (req['C_BPartner_Product_Chip_ID'] is Map 
      ? req['C_BPartner_Product_Chip_ID']['id'] 
      : (req['C_BPartner_Product_Chip_ID'] ?? 
         req['C_BPartner_ProductChip_ID'] ?? 
         req['C_BPartner_Product_Chip'] ??
         req['C_BPartner_Product_Chip_ID_ID'] ?? 
         req['Product_Chip_ID']));
  
  if (raw == null) return null;
  if (raw is int) return raw;
  return int.tryParse(raw.toString());
}

/// Extrae el nombre (identifier) de la ficha de producto de forma robusta.
String? extractProductChipName(Map<String, dynamic> req) {
  if (req['C_BPartner_Product_Chip_ID'] is Map) {
    final map = req['C_BPartner_Product_Chip_ID'] as Map;
    return (map['identifier'] ?? map['Name'] ?? map['Description'])?.toString();
  }
  
  return (req['C_BPartner_Product_Chip_ID_Name'] ?? 
          req['C_BPartner_ProductChip_ID_Name'] ?? 
          req['Product_Chip_ID_Name'] ?? 
          req['C_BPartner_Product_Chip_Name'])?.toString();
}

// --- LLAMADAS A LA API ---

/// Obtiene las solicitudes usando paginación para asegurar que se traigan todos los registros.
Future<List<Map<String, dynamic>>> fetchRequest({String? model = 'R_Request', String? filter, int? top, int? initialSkip, String? select, String? orderBy, String? expand}) async {
  List<Map<String, dynamic>> allRecords = [];
  int skip = initialSkip ?? 0;
  // Si se especifica 'top', se usa como tamaño de página y no se pagina más.
  // Si no, se usa un tamaño de página estándar para la paginación completa.
  final int pageSize = top ?? 100;
  bool hasMore = true;

  try {
    while (hasMore) {
      final queryParams = {'\$skip': skip.toString(), '\$top': pageSize.toString(), '\$limit': pageSize.toString(), '\$orderBy': orderBy ?? 'Created desc'};

      if (filter != null && filter.isNotEmpty) {
        queryParams['\$filter'] = filter;
      }
      if (select != null && select.isNotEmpty) {
        queryParams['\$select'] = select;
      }
      if (expand != null && expand.isNotEmpty) {
        queryParams['\$expand'] = expand;
      }

      final endpoint = '${Endpoint.baseUrl}/api/v1/models/$model';
      final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);
      var response = await http.get(uri, headers: {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': Token.token});

      if (response.statusCode == 401) {
        final refreshed = await handleTokenRefresh();
        if (refreshed) {
          response = await http.get(uri, headers: {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': Token.token});
        } else {
          return [];
        }
      }

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final records = jsonResponse['records'] as List;

        if (records.isEmpty) {
          hasMore = false;
        } else {
          // Mapeo básico para asegurar que las llaves existan
          final mapped = records.map((r) => Map<String, dynamic>.from(r)).toList();
          allRecords.addAll(mapped);

          // Si se especificó un 'top', solo hacemos una página. Si no, paginamos hasta el final.
          if (records.length < pageSize || top != null) {
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
  } catch (e) {}
  return allRecords;
}

/// Obtiene UNA página de solicitudes y opcionalmente el total de registros
Future<Map<String, dynamic>> fetchRequestPaginated({
  String? model = 'R_Request',
  String? filter,
  required int skip,
  required int top,
  String? select,
  String? orderBy,
  String? expand,
  bool fetchCount = false,
}) async {
  List<Map<String, dynamic>> recordsList = [];
  int totalRecords = -1;

  try {
    final queryParams = {
      '\$skip': skip.toString(),
      '\$top': top.toString(),
      '\$limit': top.toString(),
      '\$orderBy': orderBy ?? 'Created desc'
    };

    if (filter != null && filter.isNotEmpty) {
      queryParams['\$filter'] = filter;
    }
    if (select != null && select.isNotEmpty) {
      queryParams['\$select'] = select;
    }
    if (expand != null && expand.isNotEmpty) {
      queryParams['\$expand'] = expand;
    }
    
    if (fetchCount) {
      queryParams['\$inlinecount'] = 'allpages'; // OData common way to get count
    }

    final endpoint = '${Endpoint.baseUrl}/api/v1/models/$model';
    final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);
    
    var response = await http.get(uri, headers: {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': Token.token
    });

    if (response.statusCode == 401) {
      final refreshed = await handleTokenRefresh();
      if (refreshed) {
        response = await http.get(uri, headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': Token.token
        });
      } else {
        return {'records': [], 'totalCount': 0};
      }
    }

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      List? records;
      if (jsonResponse is Map) {
        records = (jsonResponse['records'] ?? jsonResponse['value']) as List?;
      } else if (jsonResponse is List) {
        records = jsonResponse;
      }
      
      if (records != null) {
        recordsList = records.map((r) => Map<String, dynamic>.from(r)).toList();
      }
      
      // Intentar extraer el conteo total de varias formas comunes en OData
      if (jsonResponse is Map) {
        if (jsonResponse.containsKey('@odata.count')) {
          totalRecords = int.tryParse(jsonResponse['@odata.count'].toString()) ?? -1;
        } else if (jsonResponse.containsKey('inlinecount')) {
          totalRecords = int.tryParse(jsonResponse['inlinecount'].toString()) ?? -1;
        } else if (jsonResponse.containsKey('totalCount')) {
          totalRecords = int.tryParse(jsonResponse['totalCount'].toString()) ?? -1;
        } else if (jsonResponse.containsKey('count')) {
          totalRecords = int.tryParse(jsonResponse['count'].toString()) ?? -1;
        }
      }
    }
  } catch (e) {
    debugPrint("Error in fetchRequestPaginated: $e");
  }

  // Si fetchCount es true pero la API no lo retornó en la respuesta principal,
  // hacemos una petición manual muy rápida sin expand para contar.
  if (fetchCount && totalRecords == -1) {
    totalRecords = await fetchRequestCount(model: model, filter: filter);
  }

  return {
    'records': recordsList,
    'totalCount': totalRecords == -1 ? recordsList.length : totalRecords
  };
}

/// Función auxiliar para obtener el conteo de registros para un filtro dado.
Future<int> fetchRequestCount({String? model = 'R_Request', String? filter}) async {
  try {
    final queryParams = {
      '\$top': '1',
      '\$limit': '1',
      '\$select': 'id',
      '\$inlinecount': 'allpages',
    };
    if (filter != null && filter.isNotEmpty) {
      queryParams['\$filter'] = filter;
    }
    
    final endpoint = '${Endpoint.baseUrl}/api/v1/models/$model';
    final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);
    
    final response = await http.get(uri, headers: {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': Token.token
    });

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      
      if (jsonResponse is Map) {
        if (jsonResponse.containsKey('@odata.count')) {
          return int.tryParse(jsonResponse['@odata.count'].toString()) ?? 0;
        }
        if (jsonResponse.containsKey('inlinecount')) {
          return int.tryParse(jsonResponse['inlinecount'].toString()) ?? 0;
        }
        if (jsonResponse.containsKey('totalCount')) {
          return int.tryParse(jsonResponse['totalCount'].toString()) ?? 0;
        }
        if (jsonResponse.containsKey('count')) {
          return int.tryParse(jsonResponse['count'].toString()) ?? 0;
        }
        
        final records = jsonResponse['records'] as List?;
        if (records != null) return records.length;
        
        final value = jsonResponse['value'] as List?;
        if (value != null) return value.length;
      } else if (jsonResponse is List) {
        return jsonResponse.length;
      }
    }
  } catch (e) {
    debugPrint("Error counting records: $e");
  }
  return 0;
}

Future<List<Map<String, dynamic>>> fetchProjectAndTaskRequests(int projectId, {List<String>? taskUUIDs, String? additionalFilter, String? select, String? expand}) async {
  List<Map<String, dynamic>> allReqs = [];

  if (taskUUIDs == null) {
    taskUUIDs = await ProjectsLogic().fetchProjectTaskUUIDs(projectId);
  }

  String baseFilter = "C_Project_ID eq $projectId";
  if (additionalFilter != null && additionalFilter.isNotEmpty) {
    baseFilter = "($baseFilter) and $additionalFilter";
  }

  // 1. Solicitudes vinculadas a nivel de proyecto (Cabecera)
  final pReqs = await fetchRequest(filter: baseFilter, select: select, expand: expand);
  allReqs.addAll(pReqs);

  // 2. Solicitudes vinculadas a nivel de Tareas (Record_UU) particionadas de a 10
  if (taskUUIDs.isNotEmpty) {
    for (var i = 0; i < taskUUIDs.length; i += 10) {
      final chunk = taskUUIDs.sublist(i, i + 10 > taskUUIDs.length ? taskUUIDs.length : i + 10);
      String chunkFilter = chunk.map((u) => "Record_UU eq '$u'").join(' or ');
      chunkFilter = "($chunkFilter)";
      if (additionalFilter != null && additionalFilter.isNotEmpty) {
        chunkFilter = "$chunkFilter and $additionalFilter";
      }
      final tReqs = await fetchRequest(filter: chunkFilter, select: select, expand: expand);
      allReqs.addAll(tReqs);
    }
  }

  // 3. Deduplicación por si hay un ticket que tiene tanto C_Project_ID como Record_UU
  final uniqueReqsMap = <int, Map<String, dynamic>>{};
  for (var r in allReqs) {
    if (r['id'] != null) uniqueReqsMap[r['id']] = r;
  }
  return uniqueReqsMap.values.toList();
}

Future<Map<String, dynamic>> fetchStatusesWithMetadata() async {
  try {
    final response = await http.get(
      Uri.parse('${Endpoint.baseUrl}/api/v1/models/R_Status?\$limit=100'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': Token.token,
      },
    );
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      final records = jsonResponse['records'] as List;
      final Map<String, int> nameToId = {};
      final Map<int, bool> idToIsClosed = {};
      for (var r in records) {
        final name = r['Name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        final id = (r['id'] as num).toInt();
        final rawIsClosed = r['IsClosed'] ?? r['isClosed'];
        final isClosedStr = rawIsClosed?.toString().trim().toLowerCase();
        bool isClosed = isClosedStr == 'true' || isClosedStr == 'y' || rawIsClosed == true;
        
        nameToId[name] = id;
        idToIsClosed[id] = isClosed;
      }
      return {'nameToId': nameToId, 'idToIsClosed': idToIsClosed};
    }
  } catch (e) {
    debugPrint("Error fetching statuses: $e");
  }
  return {'nameToId': <String, int>{}, 'idToIsClosed': <int, bool>{}};
}

Future<Map<String, int>> fetchStatuses() async {
  final data = await fetchStatusesWithMetadata();
  return data['nameToId'] as Map<String, int>;
}

Future<Map<String, int>> fetchRequestTypes() async {
  try {
    final response = await http.get(
      Uri.parse('${Endpoint.baseUrl}/api/v1/models/R_RequestType'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': Token.token,
      },
    );
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      final records = jsonResponse['records'] as List;
      return {for (var r in records) r['Name'].toString().trim(): r['id'] as int};
    }
  } catch (e) {
    debugPrint("Error fetching request types: $e");
  }
  return {};
}

Future<Map<String, int>> fetchCategories() async {
  try {
    final response = await http.get(
      Uri.parse('${Endpoint.baseUrl}/api/v1/models/R_Category'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': Token.token,
      },
    );
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      final records = jsonResponse['records'] as List;
      return {for (var r in records) r['Name'].toString().trim(): r['id'] as int};
    }
  } catch (e) {
    debugPrint("Error fetching categories: $e");
  }
  return {};
}

Future<Map<String, int>> fetchGroups() async {
  try {
    final response = await http.get(
      Uri.parse('${Endpoint.baseUrl}/api/v1/models/R_Group'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': Token.token,
      },
    );
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      final records = jsonResponse['records'] as List;
      return {for (var r in records) r['Name'].toString().trim(): r['id'] as int};
    }
  } catch (e) {
    debugPrint("Error fetching groups: $e");
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
  double inProgress = 0.0;

  // El filtrado de soporte (Record_UU) se realiza en la UI o Controller respectivo antes de llamar a processRequests.
  final visibleRequests = requests;

  List<Map<String, dynamic>> processedRequests = [];

  for (var req in visibleRequests) {
    final statusIdFromReq = req['R_Status_ID'] is Map ? req['R_Status_ID']['id'] : req['R_Status_ID'];
    final statusName = req['R_Status_ID'] is Map ? (req['R_Status_ID']['identifier'] ?? req['R_Status_ID']['Name'] ?? req['R_Status_Name'] ?? '') : (req['R_Status_Name'] ?? '');
    
    // Extraer QtyPlan y QtySpent buscando múltiples variantes de nombres de campo
    final double qtyPlan = tryGetDouble(req, ['QtyPlan', 'qtyPlan', 'qty_plan']) ?? 0.0;
    final double qtySpent = tryGetDouble(req, ['QtySpent', 'qtySpent', 'qty_spent', 'UsedQty', 'used_qty']) ?? 0.0;

    // Lógica de horas basada en metadatos de estado (IsClosed)
    bool isClosedStatus = false;
    if (statusIdFromReq != null && GlobalCache.statusIsClosedMap.containsKey(statusIdFromReq)) {
      isClosedStatus = GlobalCache.statusIsClosedMap[statusIdFromReq]!;
    } else {
      // Fallback robusto por nombre y IDs conocidos
    isClosedStatus = statusIdFromReq == 1000019 || // Archivada
                     statusIdFromReq == 1000015 || // Anulada
                     statusIdFromReq == 1000018 || // Implementada en produccion
                     statusName.toLowerCase().contains('archivada') || 
                     statusName.toLowerCase().contains('anulada') ||
                     statusName.toLowerCase().contains('implementada en produccion') ||
                     statusName.toLowerCase().contains('implementada en producción') ||
                     statusIdFromReq == 103 || 
                     statusName.toLowerCase().contains('final close') ||
                     statusName.toLowerCase().contains('cerrada');
    }

    if (isClosedStatus) {
      consumed += qtySpent; // Horas ya cerradas/finalizadas
    } else {
      // Horas en solicitudes activas: se consideran "Estimadas" (inProgress)
      // Según requerimiento: usar QtySpent para que coincida con lo que el usuario revisa.
      inProgress += qtySpent;
    }

    // Formateo de UI
    String level = req['Priority'] is Map ? (req['Priority']['identifier'] ?? req['Priority']['Name'] ?? 'Baja') : 'Baja';
    String status = statusName;
    int? statusId = statusIdFromReq;

    if (statusId != null) {
      if (SUPPORT_STATUS_MAPPING.containsKey(statusId)) {
        status = SUPPORT_STATUS_MAPPING[statusId]!;
      } else if (statusIdMap.isNotEmpty) {
        for (var entry in statusIdMap.entries) {
          if (entry.value == statusId) {
            status = entry.key;
            break;
          }
        }
      }
    }

    Color baseColor = Colors.green;
    if (level == 'Urgente') {
      baseColor = Colors.purple;
    } else if (level == 'Alta') {
      baseColor = Colors.red;
    } else if (level == 'Media') {
      baseColor = Colors.amber.shade800;
    } else if (level == 'Menor') {
      baseColor = Colors.grey;
    }
    String formattedTime = req['Created'] ?? '';
    try {
      if (formattedTime.isNotEmpty) {
        final DateTime date = DateTime.parse(formattedTime).toLocal();
        formattedTime = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}

    final bpId = req['C_BPartner_ID'] is Map ? (req['C_BPartner_ID']['id'] as num?)?.toInt() : (req['C_BPartner_ID'] as num?)?.toInt();
    final userId = req['AD_User_ID'] is Map ? (req['AD_User_ID']['id'] as num?)?.toInt() : (req['AD_User_ID'] as num?)?.toInt();
    final salesRepId = req['SalesRep_ID'] is Map ? (req['SalesRep_ID']['id'] as num?)?.toInt() : (req['SalesRep_ID'] as num?)?.toInt();

    String bpName = req['C_BPartner_ID'] is Map ? (req['C_BPartner_ID']['identifier'] ?? req['C_BPartner_ID']['Name'] ?? '').toString().trim() : '';
    if (bpName.isEmpty && bpId != null) {
      final found = GlobalCache.allBPartners.firstWhere((bp) => (bp['id'] as num?)?.toInt() == bpId, orElse: () => {});
      if (found.isNotEmpty) bpName = (found['Name'] ?? '').toString().trim();
    }

    String userName = req['AD_User_ID'] is Map ? (req['AD_User_ID']['identifier'] ?? req['AD_User_ID']['Name'] ?? '').toString().trim() : '';
    if (userName.isEmpty && userId != null) {
      final found = GlobalCache.users.firstWhere((u) => ((u['AD_User_ID'] ?? u['id']) as num?)?.toInt() == userId, orElse: () => {});
      if (found.isNotEmpty) userName = (found['Name'] ?? '').toString().trim();
    }

    String salesRepName = req['SalesRep_ID'] is Map ? (req['SalesRep_ID']['identifier'] ?? req['SalesRep_ID']['Name'] ?? '').toString().trim() : '';
    if (salesRepName.isEmpty && salesRepId != null) {
      final found = GlobalCache.salesReps.firstWhere((r) => ((r['AD_User_ID'] ?? r['id']) as num?)?.toInt() == salesRepId, orElse: () => {});
      if (found.isNotEmpty) salesRepName = (found['Name'] ?? '').toString().trim();
    }

    processedRequests.add({
      'descriptionClean': stripHtmlTags(req['Summary'] ?? ''),
      'id': req['DocumentNo'] ?? req['id'].toString(),
      'realId': req['id'],
      'situation': req['R_RequestType_ID'] is Map ? (req['R_RequestType_ID']['identifier'] ?? req['R_RequestType_ID']['Name'] ?? 'Solicitud') : 'Solicitud',
      'description': req['Summary'] ?? '',
      'level': level,
      'status': status.trim(),
      'statusId': statusId,
      'time': formattedTime,
      'levelColor': baseColor,
      'levelBgColor': baseColor.withOpacity(0.2),
      'statusColor': Colors.grey,
      'dateStartPlan': req['DateStartPlan'] ?? '',
      'dateCompletePlan': req['DateCompletePlan'] ?? '',
      'startTime': extractTime(req['StartTime']),
      'endTime': extractTime(req['EndTime']),
      'qtySpent': qtySpent,
      'startDate': req['StartDate'],
      'closeDate': req['CloseDate'],
      'userName': userName,
      'bpName': bpName,
      'result': req['Result'] ?? '',
      'type': getDropdownValue(req['R_RequestType_ID']),
      'category': getDropdownValue(req['R_Category_ID']),
      'group': getDropdownValue(req['R_Group_ID']),
      'bpId': bpId,
      'userId': userId,
      'salesRepId': salesRepId,
      'salesRepName': salesRepName,
      'emailSubject': req['CDS_EmailSubject'] ?? '',
      'salesOrderId': req['C_Order_ID'] is Map ? req['C_Order_ID']['id'] : null,
      'salesOrderNo': req['C_Order_ID'] is Map ? req['C_Order_ID']['DocumentNo'] : null,
      'recordUU': req['Record_UU'],
      'productChipId': extractProductChipId(req),
      'productChipName': extractProductChipName(req),
      'isClosed': isClosedStatus,
      'original': req,
    });
  }

  return {'rawRequests': rawRequests, 'requests': processedRequests, 'consumedHours': consumed, 'inProgressHours': inProgress};
}

Future<List<Map<String, dynamic>>> fetchRequestUpdates(int requestId) async {
  // Usa la función genérica fetchRequest para obtener las actualizaciones
  return await fetchRequest(model: 'R_RequestUpdate', filter: "R_Request_ID eq $requestId", orderBy: 'Created desc', select: 'Created,Result,ConfidentialTypeEntry,AD_Image_ID,AD_Image1_ID,AD_Image2_ID,AD_Image3_ID,IsPrinted');
}

Future<Map<String, dynamic>> updateRemoteRequest({
  required dynamic id,
  String? priority,
  int? statusId,
  String? statusIdentifier,
  String? summary,
  String? dateStartPlan,
  String? dateCompletePlan,
  String? startTime,
  String? endTime,  
  double? qtySpent,
  String? startDate,
  String? closeDate,
  String? result,
  int? requestTypeId,
  int? categoryId,
  int? groupId,
  int? salesRepId,
  int? bPartnerId,
  int? userId,
  String? emailSubject,
  int? orderId,
  int? productChipId,
}) async {
  try {
    final url = Uri.parse('${Endpoint.request}/$id');
    final Map<String, dynamic> data = {};

    if (priority != null) data['Priority'] = priorityMap[priority];
    if (summary != null) data['Summary'] = summary;

    if (emailSubject != null) data['CDS_EmailSubject'] = emailSubject;

    if (result != null) data['Result'] = result;
    if (statusId != null) {
      data['R_Status_ID'] = {'id': statusId};
    } else if (statusIdentifier != null) {
      data['R_Status_ID'] = {'identifier': statusIdentifier};
    }

    if (dateStartPlan != null && dateStartPlan.isNotEmpty) data['DateStartPlan'] = ensureIsoDate(dateStartPlan);
    if (dateCompletePlan != null && dateCompletePlan.isNotEmpty) data['DateCompletePlan'] = ensureIsoDate(dateCompletePlan);
    if (startTime != null && startTime.isNotEmpty) data['StartTime'] = ensureIsoTime(dateStartPlan, startTime);
    if (endTime != null && endTime.isNotEmpty) data['EndTime'] = endTime; // El caller ya lo manda como DateTime completo
    if (qtySpent != null) data['QtySpent'] = qtySpent;
    
    if (startDate != null) data['StartDate'] = startDate;
    if (closeDate != null) data['CloseDate'] = closeDate;

    if (requestTypeId != null) data['R_RequestType_ID'] = {'id': requestTypeId};
    if (categoryId != null) data['R_Category_ID'] = {'id': categoryId};
    if (groupId != null) data['R_Group_ID'] = {'id': groupId};
    if (salesRepId != null) data['SalesRep_ID'] = salesRepId;
    if (bPartnerId != null) data['C_BPartner_ID'] = {'id': bPartnerId};
    if (userId != null) data['AD_User_ID'] = {'id': userId};
    if (orderId != null) data['C_Order_ID'] = {'id': orderId};
    if (productChipId != null) data['C_BPartner_Product_Chip_ID'] = {'id': productChipId};

    var response = await http.put(url, headers: {'Content-Type': 'application/json', 'Authorization': Token.token}, body: jsonEncode(data));

    if (response.statusCode == 401) {
      final refreshed = await handleTokenRefresh();
      if (refreshed) {
        response = await http.put(url, headers: {'Content-Type': 'application/json', 'Authorization': Token.token}, body: jsonEncode(data));
      } else {
        return {'success': false, 'error': 'Sesión expirada'};
      }
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      return {'success': false, 'error': 'Error ${response.statusCode}'};
    }
    return {'success': true};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

Future<Map<String, dynamic>> createRequestUpdate({required int requestId, required String resultText, required String confidentialType, required bool isPrinted, required List<PlatformFile?> evidences}) async {
  try {
    final url = Uri.parse('${Endpoint.baseUrl}/api/v1/models/R_RequestUpdate');
    final Map<String, dynamic> body = {"R_Request_ID": requestId, "Result": resultText, "ConfidentialTypeEntry": confidentialType, "IsPrinted": isPrinted};

    // Anidamos las evidencias usando el formato exacto {"data": "base64..."}
    final List<String> imageKeys = ["AD_Image_ID", "AD_Image1_ID", "AD_Image2_ID", "AD_Image3_ID"];
    for (int i = 0; i < evidences.length && i < 4; i++) {
      if (evidences[i] != null && evidences[i]!.bytes != null) {
        body[imageKeys[i]] = {"data": base64Encode(evidences[i]!.bytes!)};
      }
    }

    var response = await http.post(url, headers: {'Content-Type': 'application/json', 'Authorization': Token.token}, body: jsonEncode(body));

    if (response.statusCode == 401) {
      final refreshed = await handleTokenRefresh();
      if (refreshed) {
        response = await http.post(url, headers: {'Content-Type': 'application/json', 'Authorization': Token.token}, body: jsonEncode(body));
      } else {
        return {'success': false, 'message': 'Sesión expirada'};
      }
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      return {'success': false, 'message': 'Error creando actualización: ${response.body}'};
    }

    return {'success': true, 'message': 'Actualización creada'};
  } catch (e) {
    return {'success': false, 'message': e.toString()};
  }
}

Future<bool> deleteRequestApi(dynamic id) async {
  try {
    var response = await http.delete(Uri.parse('${Endpoint.request}/$id'), headers: {'Authorization': Token.token});

    if (response.statusCode == 401) {
      final refreshed = await handleTokenRefresh();
      if (refreshed) {
        response = await http.delete(Uri.parse('${Endpoint.request}/$id'), headers: {'Authorization': Token.token});
      } else {
        return false;
      }
    }

    if (response.statusCode == 200 || response.statusCode == 204) {
      int parsedId = id is int ? id : int.tryParse(id.toString()) ?? 0;
      GlobalCache.removeRequest(parsedId);
      return true;
    }
    return false;
  } catch (e) {
    return false;
  }
}
