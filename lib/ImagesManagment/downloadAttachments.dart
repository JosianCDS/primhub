import 'dart:typed_data';
import 'package:http/http.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/ui/shared/customToast.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/material.dart';

Future<void> downloadAttachment({
  required BuildContext context,
  required int recordID,
  required String tableName,
  required String fileName,
}) async {
  final String token = Token.token;

  try {
    final Uri url = Uri.parse(
      '$tableName/$recordID/attachments/${Uri.encodeComponent(fileName)}',
    );

    final Response response = await get(
      url,
      headers: {'Authorization': token, 'Accept': '*/*'},
    );

    // 🔎 DEBUG CRUDO
    debugPrint('================ ATTACHMENT DEBUG ================');
    debugPrint('URL: $url');
    debugPrint('STATUS: ${response.statusCode}');
    debugPrint('HEADERS: ${response.headers}');
    debugPrint('BYTES LENGTH: ${response.bodyBytes.length}');

    // Si el body parece texto, lo mostramos (limitado)
    try {
      final String rawBody = String.fromCharCodes(response.bodyBytes);
      debugPrint(
        'RAW BODY (first 500 chars):\n'
        '${rawBody.substring(0, rawBody.length > 500 ? 500 : rawBody.length)}',
      );
    } catch (_) {
      debugPrint('RAW BODY: <binary>');
    }

    debugPrint('=================================================');

    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      _triggerWebDownloadFromBytes(response.bodyBytes, fileName);

      if (context.mounted) {
        ToastMessage.show(
          context: context,
          message: "Descarga iniciada: $fileName",
          type: ToastType.success,
        );
      }
    } else {
      throw Exception(
        'HTTP ${response.statusCode} | '
        'Content-Type: ${response.headers['content-type']} | '
        'Bytes: ${response.bodyBytes.length}',
      );
    }
  } catch (e, stack) {
    debugPrint('❌ DOWNLOAD ERROR: $e');
    debugPrint('📌 STACKTRACE:\n$stack');

    if (context.mounted) {
      ToastMessage.show(
        context: context,
        message:
            "Error descargando archivo\n"
            "${e.toString().substring(0, e.toString().length > 120 ? 120 : e.toString().length)}",
        type: ToastType.failure,
      );
    }
  }
}

void _triggerWebDownloadFromBytes(Uint8List bytes, String fileName) {
  try {
    final html.Blob blob = html.Blob([bytes]);
    final String url = html.Url.createObjectUrlFromBlob(blob);

    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();

    html.Url.revokeObjectUrl(url);
  } catch (e) {
    debugPrint("Error creando descarga: $e");
  }
}
