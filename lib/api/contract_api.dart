import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';

class ContractApi {
  static Future<List<Map<String, dynamic>>> getSupportContracts({int? bPartnerId, List<int>? bPartnerIds}) async {
    if (ProductChip.mProductID == null) {
      debugPrint('No se encontró ID de producto en la ficha. No se pueden obtener las horas contratadas.');
      return [];
    }

    // Nuevo enfoque: Consultar C_OrderLine directamente y expandir hacia arriba para obtener la información del Pedido.
    final String orderLineEndpoint = "${Endpoint.baseUrl}/api/v1/models/C_OrderLine";
    String filter = "M_Product_ID eq ${ProductChip.mProductID}";

    // Construimos el filtro de terceros para la consulta de líneas
    List<int> finalBpIds = [];
    if (bPartnerId != null) finalBpIds.add(bPartnerId);
    if (bPartnerIds != null) finalBpIds.addAll(bPartnerIds);
    if (finalBpIds.isEmpty && Token.primConfig?.toLowerCase() != 'ad' && Token.primConfig?.toLowerCase() != 'sp' && User.cBPartnerID != null) {
      finalBpIds.add(User.cBPartnerID!);
    }
    // NOTA: Si finalBpIds está vacío (admin, sin selección), no se filtra por tercero en las líneas, se filtra después.
    final String queryUrl = "$orderLineEndpoint?\$filter=$filter&\$expand=C_Order_ID(\$select=DocumentNo,DateOrdered,Created,C_BPartner_ID,DocStatus,IsSOTrx)";

    try {
      final response = await http.get(Uri.parse(queryUrl), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final lines = jsonResponse['records'] as List;
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
      }
    } catch (e) {
      debugPrint('Error loading contracted hours: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getBPartnersWithSupportContracts() async {
    if (ProductChip.mProductID == null) {
      debugPrint("getBPartnersWithSupportContracts: ProductChip.mProductID is null. Cannot proceed.");
      return [];
    }

    // Nuevo enfoque: Consultar C_OrderLine directamente y expandir hacia arriba para obtener la información del Tercero.
    // Esto es más robusto si el filtro 'any' no funciona como se espera.
    final String orderLineEndpoint = "${Endpoint.baseUrl}/api/v1/models/C_OrderLine";
    // CORRECCIÓN: Se elimina el $expand anidado que causa el error 400. El expand simple en C_Order_ID es suficiente.
    final String queryUrl = "$orderLineEndpoint?\$filter=M_Product_ID eq ${ProductChip.mProductID}&\$expand=C_Order_ID(\$select=C_BPartner_ID,DocStatus,IsSOTrx)";
    debugPrint("Querying for BPs with support contracts: $queryUrl");

    try {
      final response = await http.get(Uri.parse(queryUrl), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final records = jsonResponse['records'] as List;
        final Map<int, Map<String, dynamic>> bPartners = {};

        debugPrint("Found ${records.length} order lines with the support product.");

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
                if (!bPartners.containsKey(bpId)) {
                  debugPrint("Adding BPartner: ID=${bpInfo['id']}, Name=${bpInfo['identifier'] ?? bpInfo['Name']}");
                }
                bPartners[bpId] = {'id': bpId, 'Name': bpInfo['identifier'] ?? bpInfo['Name'] ?? 'Tercero ${bpInfo['id']}'};
              } else {
                debugPrint("Skipping line: BPartner info is missing. OrderInfo: $orderInfo");
              }
            } else {
              debugPrint("Skipping line: Not a valid SO or status. isSOTrx: $isSOTrx, docStatus: $docStatus");
            }
          } else {
            debugPrint("Skipping line: C_Order_ID is null.");
          }
        }
        final result = bPartners.values.toList()..sort((a, b) => a['Name'].compareTo(b['Name']));
        debugPrint("Returning ${result.length} unique BPartners.");
        return result;
      } else {
        debugPrint("Failed to load BPs. Status: ${response.statusCode}, Body: ${response.body}");
      }
    } catch (e) {
      debugPrint('Error loading BPs with support contracts: $e');
    }
    return [];
  }
}
