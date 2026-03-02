import 'dart:convert';
import 'dart:typed_data';

Future<Map<String, String>> convertFileToBase64({required Uint8List fileBytes, required String fileName}) async {
  return {'title': fileName, 'base64': base64Encode(fileBytes)};
}
