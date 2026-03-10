import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';

class ContractApi {
  static Future<List<Map<String, dynamic>>> getSupportContracts({int? bPartnerId}) async {
    // Si no hay un producto definido en la ficha, no podemos buscar horas.
    if (ProductChip.mProductID == null) {
      debugPrint('No se encontró ID de producto en la ficha. No se pueden obtener las horas contratadas.');
      return [];
    }

    String filter = "IsSOTrx eq true and (DocStatus eq 'CO' or DocStatus eq 'CL' or DocStatus eq 'DR')";

    if (bPartnerId != null) {
      filter += " and C_BPartner_ID eq $bPartnerId";
    } else if (Token.primConfig?.toLowerCase() != 'ad' && Token.primConfig?.toLowerCase() != 'sp') {
      if (User.cBPartnerID != null) {
        filter += " and C_BPartner_ID eq ${User.cBPartnerID}";
      } else {
        return [];
      }
    }

    // Se añade el filtro 'any' para asegurar que solo traemos órdenes con el producto de soporte.
    filter += " and C_OrderLine/any(l: l/M_Product_ID eq ${ProductChip.mProductID})";
    // Se expanden las líneas para poder sumar las cantidades en el cliente.
    final String queryUrl = "${Endpoint.order}?\$filter=$filter&\$expand=C_OrderLine(\$select=M_Product_ID,QtyEntered)&\$select=DocumentNo,DateOrdered,Created";

    try {
      final response = await http.get(Uri.parse(queryUrl), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final records = jsonResponse['records'] as List;
        List<Map<String, dynamic>> contracts = [];

        for (var record in records) {
          final lines = record['C_OrderLine'] as List?;
          double totalHoursForThisOrder = 0.0;
          if (lines != null) {
            // Como el filtro en expand puede no funcionar, filtramos las líneas en el cliente.
            for (var line in lines) {
              if (line['M_Product_ID'] != null && line['M_Product_ID']['id'] == ProductChip.mProductID) {
                totalHoursForThisOrder += (line['QtyEntered'] as num?)?.toDouble() ?? 0.0;
              }
            }
          }
          // Solo añadir contratos que realmente tienen horas de soporte
          if (totalHoursForThisOrder > 0) {
            contracts.add({'id': record['id'], 'DocumentNo': record['DocumentNo'], 'DateOrdered': record['DateOrdered'], 'contractedHours': totalHoursForThisOrder});
          }
        }
        // Ordenar por fecha para aplicar consumo FIFO
        contracts.sort((a, b) => (a['DateOrdered'] as String).compareTo(b['DateOrdered'] as String));
        return contracts;
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
