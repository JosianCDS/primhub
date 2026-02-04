import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';

Future<bool> postAttachments({
  required int recordID,
  required String tableName,
  required Map<String, String> convertedFile,
}) async {
  try {
    String token = Token.auth!;
    final Map<String, dynamic> data = {
      "name": convertedFile['title'],
      "data": convertedFile['base64'],
    };

    final response = await post(
      Uri.parse(PostMedia(recordID: recordID, tableName: tableName).endPoint),
      headers: {'Content-Type': 'application/json', 'Authorization': token},
      body: jsonEncode(data),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return true;
    } else {
      debugPrint(
        'Error al subir el archivo ${convertedFile['title']}: ${response.statusCode}, ${response.body}',
      );
      return false;
    }
  } catch (e) {
    debugPrint('Error al subir el archivo: $e');

    return false;
  }
}
