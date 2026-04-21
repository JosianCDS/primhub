import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/api_utils.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';

class ContractApi {
  // Filtro unificado con los IDs válidos para productos de soporte (Mensual y Por Horas)
  static const String validSupportProductsFilter = "(M_Product_ID eq 1000816 or M_Product_ID eq 1000161 or M_Product_ID eq 1000814 or M_Product_ID eq 1000693 or M_Product_ID eq 1000695)";

  // Función auxiliar para iterar la API y traer todos los registros sin el límite restrictivo de 100
  static Future<List<dynamic>> _fetchPaginated(String baseUrl) async {
    List<dynamic> allRecords = [];
    int skip = 0;
    int top = 100;
    bool hasMore = true;

    try {
      while (hasMore) {
        String queryUrl = "$baseUrl&\$skip=$skip&\$top=$top";
        var response = await http.get(Uri.parse(queryUrl), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});

        if (response.statusCode == 401) {
          final refreshed = await handleTokenRefresh();
          if (refreshed) {
            response = await http.get(Uri.parse(queryUrl), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});
          } else {
            return allRecords;
          }
        }

        if (response.statusCode == 200) {
          final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
          final records = jsonResponse['records'] as List;
          allRecords.addAll(records);
          if (records.length < top) {
            hasMore = false;
          } else {
            skip += top;
          }
        } else {
          hasMore = false;
        }
      }
    } catch (e) {
      debugPrint("Error en paginación ContractApi: $e");
    }
    return allRecords;
  }

  static Future<List<Map<String, dynamic>>> getSupportContracts({int? bPartnerId, List<int>? bPartnerIds}) async {
    if (ProductChip.mProductID == null) {
      return [];
    }

    final String orderLineEndpoint = "${Endpoint.baseUrl}/api/v1/models/C_OrderLine";
    String filter = validSupportProductsFilter;

    // Construimos el filtro de terceros para la consulta de líneas
    List<int> finalBpIds = [];
    if (bPartnerId != null) finalBpIds.add(bPartnerId);
    if (bPartnerIds != null) finalBpIds.addAll(bPartnerIds);
    if (finalBpIds.isEmpty && !AccessControl.isAdmin && !AccessControl.isRealSupport && User.cBPartnerID != null) {
      finalBpIds.add(User.cBPartnerID!);
    }

    final String baseUrl = "$orderLineEndpoint?\$filter=$filter&\$expand=C_Order_ID(\$select=DocumentNo,DateOrdered,Created,C_BPartner_ID,DocStatus,IsSOTrx)";

    try {
      final lines = await _fetchPaginated(baseUrl);
      Map<int, Map<String, dynamic>> contracts = {};

      for (var line in lines) {
        final orderInfo = line['C_Order_ID'];
        if (orderInfo == null) continue;

        final orderBpId = orderInfo['C_BPartner_ID']?['id'];
        // Si se especificaron terceros, filtramos aquí
        if (finalBpIds.isNotEmpty && !finalBpIds.contains(orderBpId)) {
          continue;
        }

        final isSOTrx = orderInfo['IsSOTrx'] == true;
        final docStatus = orderInfo['DocStatus'] is Map ? orderInfo['DocStatus']['id'] : orderInfo['DocStatus'];
        final isValidStatus = docStatus == 'CO' || docStatus == 'CL' || docStatus == 'DR';

        if (isSOTrx && isValidStatus) {
          final orderId = orderInfo['id'];
          final hoursInLine = (line['QtyEntered'] as num?)?.toDouble() ?? 0.0;

          if (contracts.containsKey(orderId)) {
            contracts[orderId]!['contractedHours'] += hoursInLine;
          } else {
            contracts[orderId] = {'id': orderId, 'DocumentNo': orderInfo['DocumentNo'], 'DateOrdered': orderInfo['DateOrdered'], 'contractedHours': hoursInLine, 'C_BPartner_ID': orderBpId};
          }
        }
      }
      final result = contracts.values.toList();
      result.sort((a, b) => (a['DateOrdered'] as String).compareTo(b['DateOrdered'] as String));
      return result;
    } catch (e) {
      debugPrint("Error obteniendo contratos: $e");
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getBPartnersWithSupportContracts() async {
    if (ProductChip.mProductID == null) {
      return [];
    }

    final String orderLineEndpoint = "${Endpoint.baseUrl}/api/v1/models/C_OrderLine";
    final String baseUrl = "$orderLineEndpoint?\$filter=$validSupportProductsFilter&\$expand=C_Order_ID(\$select=C_BPartner_ID,DocStatus,IsSOTrx)";

    try {
      final records = await _fetchPaginated(baseUrl);
      final Map<int, Map<String, dynamic>> bPartners = {};
      for (var line in records) {
        final orderInfo = line['C_Order_ID'];
        if (orderInfo != null) {
          final isSOTrx = orderInfo['IsSOTrx'] == true;
          final docStatus = orderInfo['DocStatus'] is Map ? orderInfo['DocStatus']['id'] : orderInfo['DocStatus'];
          final isValidStatus = docStatus == 'CO' || docStatus == 'CL' || docStatus == 'DR';

          if (isSOTrx && isValidStatus) {
            final bpInfo = orderInfo['C_BPartner_ID'];
            if (bpInfo != null && bpInfo['id'] != null) {
              final bpId = bpInfo['id'];
              bPartners[bpId] = {'id': bpId, 'Name': bpInfo['identifier'] ?? bpInfo['Name'] ?? 'Tercero ${bpInfo['id']}'};
            }
          }
        }
      }
      final result = bPartners.values.toList()..sort((a, b) => a['Name'].compareTo(b['Name']));
      return result;
    } catch (e) {
      debugPrint("Error obteniendo terceros: $e");
    }
    return [];
  }
}
