import 'dart:convert';

import 'package:primhub/endpoint/endpoint.dart';
import 'package:http/http.dart';

import '../../../api/token.dart';

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
      print('Error actualizando estado: ${response.body}');
      return false;
    }
  } catch (e) {
    print('Excepción al actualizar estado: $e');
    return false;
  }
}

Future<List<Map<String, dynamic>>> fetchRequest() async {
  List<Map<String, dynamic>> allRecords = [];
  int skip = 0;
  const int pageSize = 100; // Tamaño de bloque que el servidor parece permitir
  bool hasMore = true;

  try {
    while (hasMore) {
      // Solicitamos por bloques usando $skip para avanzar
      final response = await get(
        Uri.parse(
          '${Endpoint.request}?\$filter=C_BPartner_ID eq ${User.cBPartnerID}&\$skip=$skip&\$top=$pageSize&\$limit=$pageSize',
        ),
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
        print('Error al cargar bloque (skip: $skip): ${response.statusCode}');
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
    print(e.toString());
    return allRecords;
  }
}
