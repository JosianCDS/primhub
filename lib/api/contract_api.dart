import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';

class ContractApi {
  static Future<double?> getContractedHours() async {
    // Si no hay un producto definido en la ficha, no podemos buscar horas.
    if (ProductChip.mProductID == null) {
      debugPrint('No se encontró ID de producto en la ficha. No se pueden obtener las horas contratadas.');
      return 0.0;
    }

    if (User.cBPartnerID == null) {
      debugPrint('No se encontró el ID del socio de negocio (C_BPartner_ID).');
      return 0.0;
    }

    final String queryUrl = "${Endpoint.order}?\$filter=IsSOTrx eq true and C_BPartner_ID eq ${User.cBPartnerID} and (DocStatus eq 'CO' or DocStatus eq 'CL' or DocStatus eq 'DR')&\$expand=C_OrderLine(\$select=M_Product_ID,QtyEntered;\$filter=M_Product_ID eq ${ProductChip.mProductID})&\$select=DocumentNo,DateOrdered,Created";

    try {
      final response = await http.get(Uri.parse(queryUrl), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final records = jsonResponse['records'] as List;

        double total = 0.0;
        for (var record in records) {
          final lines = record['C_OrderLine'] as List?;
          if (lines != null) {
            for (var line in lines) {
              total += (line['QtyEntered'] as num?)?.toDouble() ?? 0.0;
            }
          }
        }
        return total;
      }
    } catch (e) {
      debugPrint('Error loading contracted hours: $e');
    }
    return null;
  }
}
