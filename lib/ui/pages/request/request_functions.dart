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
        'R_Status_ID': {
          'identifier': newStatusIdentifier
        }
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

Future<List<Map<String, dynamic>>> fetchRequest(

) async {
  try {
    
    
    final response = await get(
      Uri.parse(
        Endpoint.request,
      ),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': Token.token,
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      final records = jsonResponse['records'] as List;
      return records.map((record) {
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
          
          'Created':record['Created'],

          'identifier1': record['r status']
        };
      }).toList();


    } else {
      throw Exception('Error al cargar los terceros: ${response.statusCode}');
    }
  } catch (e) {
    print(e.toString());
    return [];
  }
}