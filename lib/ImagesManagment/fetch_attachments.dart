import 'dart:convert';
import 'package:primhub/api/api_http.dart';
import 'package:primhub/api/api_utils.dart';
import 'package:primhub/api/token.dart';

Future<List<Map<String, dynamic>>> fetchAttachments({required int recordID, required String tableName}) async {
  List<Map<String, dynamic>> allRecords = [];

  try {
    var response = await get(Uri.parse('$tableName/$recordID/attachments'), headers: {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': Token.token});

    if (response.statusCode == 401) {
      final refreshed = await handleTokenRefresh();
      if (refreshed) {
        response = await get(Uri.parse('$tableName/$recordID/attachments'), headers: {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': Token.token});
      } else {
        return [];
      }
    }

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
    return [];
  }
}
