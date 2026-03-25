import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:flutter/foundation.dart';

class GraphicsFunctions {
  /// Obtiene solicitudes filtrando por ID del Proyecto
  static Future<List<Map<String, dynamic>>> fetchMetricsData({required int projectId}) async {
    List<Map<String, dynamic>> allRecords = [];
    int skip = 0;
    const int pageSize = 100;
    bool hasMore = true;

    // FILTRO iDempiere: Activos, del Proyecto por ID numérico y que sean Requerimientos de cliente (R_Group_ID = 1000006)
    String filter = "C_Project_ID eq $projectId and IsActive eq true and R_Group_ID eq 1000006";

    // Select y Expand optimizados
    String select = "R_Request_ID,R_Status_ID,R_Group_ID,R_RequestType_ID,Priority,QtyPlan";
    String expand = "R_Status_ID(\$select=Name,IsOpen),R_Group_ID(\$select=Name),R_RequestType_ID(\$select=Name)";

    try {
      while (hasMore) {
        final queryParams = {'\$skip': skip.toString(), '\$top': pageSize.toString(), '\$filter': filter, '\$select': select, '\$expand': expand};

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
