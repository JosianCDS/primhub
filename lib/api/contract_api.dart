import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';

class ContractApi {
  static Future<double?> getContractedHours() async {
    final payload = Token.decodePayload(Token.token);
    final int userId = payload['AD_User_ID'] ?? 101;

    final String queryUrl =
        "${Endpoint.order}?\$filter=IsSOTrx eq true and AD_User_ID eq $userId and (DocStatus eq 'CO' or DocStatus eq 'DR')&\$expand=C_OrderLine(\$select=M_Product_ID,QtyEntered;\$filter=M_Product_ID eq 1000850)&\$select=DocumentNo,DateOrdered,Created";

    try {
      final response = await http.get(
        Uri.parse(queryUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
      );

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
