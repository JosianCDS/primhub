import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:primhub/api/token.dart';

Future<List<Map<String, dynamic>>> fetchAttachments({required int recordID, required String tableName}) async {
  List<Map<String, dynamic>> allRecords = [];

  String token = Token.auth!;

  try {
    final response = await get(Uri.parse('$tableName/$recordID/attachments'), headers: {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': token});

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      final records = jsonResponse['attachments'] as List;

      final mapped = records.map((record) {
        return {'id': record['id'], 'name': record['name']};
      }).toList();

      allRecords.addAll(mapped);
    } else {
      throw Exception('Error al cargar los adjuntos (status ${response.statusCode})');
    }

    return allRecords;
  } catch (e) {
    debugPrint('Excepción al obtener los adjuntos: $e');
    return [];
  }
}
