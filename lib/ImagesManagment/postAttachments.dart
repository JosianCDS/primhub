import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';

Future<bool> postAttachments({required int recordID, required String tableName, required Map<String, String> convertedFile}) async {
  try {
    String token = Token.token;
    final Map<String, dynamic> data = {"name": convertedFile['title'], "data": convertedFile['base64']};

    final response = await post(
      Uri.parse(PostMedia(recordID: recordID, tableName: tableName).endPoint),
      headers: {'Content-Type': 'application/json', 'Authorization': token},
      body: jsonEncode(data),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      _updateStatus(tableName, recordID, 'Pendiente');
      return true;
    } else {
      debugPrint('Error al subir el archivo ${convertedFile['title']}: ${response.statusCode}, ${response.body}');
      return false;
    }
  } catch (e) {
    debugPrint('Error al subir el archivo: $e');

    return false;
  }
}

Future<void> _updateStatus(String tableName, int recordID, String status) async {
  try {
    final url = Uri.parse('${Endpoint.baseUrl}/api/v1/models/$tableName/$recordID');
    await put(url, headers: {'Content-Type': 'application/json', 'Authorization': Token.token}, body: jsonEncode({'Status': status}));
  } catch (e) {
    debugPrint('Error updating status to $status: $e');
  }
}
