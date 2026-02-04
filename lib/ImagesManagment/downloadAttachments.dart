import 'dart:typed_data';
import 'package:http/http.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/ui/shared/customToast.dart';
import 'package:universal_html/html.dart';
import 'package:flutter/material.dart';

Future<void> downloadAttachment({
  required BuildContext context,
  required int recordID,
  required String tableName,
  required String fileName,
}) async {
  String token = Token.auth!;

  try {
    print('$tableName/$recordID/attachments/$fileName');

    final response = await get(
      Uri.parse('$tableName/$recordID/attachments'),
      headers: {'Content-Type': 'application/json', 'Authorization': token},
    );

    if (response.statusCode == 200) {
      // Expecting plain Base64 response, not JSON

      final Uint8List decodedBytes = response.bodyBytes;
      final blob = Blob([decodedBytes]);
      final url = Url.createObjectUrlFromBlob(blob);

      // ignore: unused_local_variable
      final anchor = AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      Url.revokeObjectUrl(url);
    } else {
      ToastMessage.show(
        context: context,
        message: "Error al obtener el archivo adjunto",
        type: ToastType.failure,
      );
    }
  } catch (e) {
    ToastMessage.show(
      context: context,
      message: "Error al procesar la descarga del archivo",
      type: ToastType.failure,
    );
    debugPrint("Error: $e");
  }
}
