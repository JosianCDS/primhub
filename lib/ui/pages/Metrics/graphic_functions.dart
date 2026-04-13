import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/api/global_cache.dart';

class GraphicsFunctions {
  /// Obtiene solicitudes filtrando por ID del Proyecto
  static Future<List<Map<String, dynamic>>> fetchMetricsData({required int projectId, bool forceRefresh = false}) async {
    // 1. Usar Caché Global si los datos ya fueron sincronizados en el Splash
    if (!forceRefresh && GlobalCache.isDataLoaded) {
      print("DEBUG API: Obteniendo métricas del proyecto $projectId desde GlobalCache...");
      return GlobalCache.requests.where((req) {
        bool isActive = req['IsActive'] == true || req['IsActive'] == 'Y';
        int? reqProjectId = req['C_Project_ID'] is Map ? req['C_Project_ID']['id'] : req['C_Project_ID'];
        int? reqGroupId = req['R_Group_ID'] is Map ? req['R_Group_ID']['id'] : req['R_Group_ID'];

        return isActive && reqProjectId == projectId && reqGroupId == 1000006;
      }).toList();
    }

    // 2. Fallback: Llamada a la API si la caché no está disponible
    List<Map<String, dynamic>> allRecords = [];
    int skip = 0;
    const int pageSize = 100;
    bool hasMore = true;

    // FILTRO iDempiere: Activos, del Proyecto por ID numérico y que sean Requerimientos de cliente (R_Group_ID = 1000006)
    String filter = "C_Project_ID eq $projectId and IsActive eq true and R_Group_ID eq 1000006";

    // Expand optimizado (Quitamos el límite de $select para que la tabla pueda recibir el Asunto, Usuario, etc.)
    String expand = "R_Status_ID(\$select=Name,IsOpen),R_Group_ID(\$select=Name),R_RequestType_ID(\$select=Name),R_Category_ID(\$select=Name)";

    try {
      while (hasMore) {
        final queryParams = {'\$skip': skip.toString(), '\$top': pageSize.toString(), '\$filter': filter, '\$expand': expand};

        final uri = Uri.parse('${Endpoint.baseUrl}/api/v1/models/R_Request').replace(queryParameters: queryParams);

        print("DEBUG API: Consultando página con skip $skip...");

        final response = await http.get(uri, headers: {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': Token.token});

        if (response.statusCode == 200) {
          final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
          final records = jsonResponse['records'] as List?;

          if (records == null || records.isEmpty) {
            hasMore = false;
          } else {
            allRecords.addAll(records.map((r) => Map<String, dynamic>.from(r)));
            if (records.length < pageSize) {
              hasMore = false;
            } else {
              skip += pageSize;
            }
          }
        } else {
          hasMore = false;
          print("DEBUG API ERROR: Status ${response.statusCode} - ${response.body}");
        }
      }
    } catch (e) {
      print("DEBUG API EXCEPTION: $e");
    }
    return allRecords;
  }
}
