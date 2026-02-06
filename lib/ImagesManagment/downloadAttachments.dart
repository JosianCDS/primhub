import 'dart:convert';
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
    // Usamos la URL directa con el nombre del archivo, codificando caracteres especiales
    final url = Uri.parse(
      '$tableName/$recordID/attachments/${Uri.encodeComponent(fileName)}',
    );

    final response = await get(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': token},
    );

    if (response.statusCode == 200) {
      String base64Data = "";

      // Intentamos parsear como JSON (estándar iDempiere) o usamos el body directo
      try {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map && decoded.containsKey('data')) {
          base64Data = decoded['data'];
        } else if (decoded is String) {
          base64Data = decoded;
        } else {
          base64Data = response.body;
        }
      } catch (_) {
        // Si falla el JSON, asumimos que es raw text/base64
        base64Data = response.body;
      }

      if (base64Data.isNotEmpty) {
        _triggerWebDownload(base64Data, fileName);

        if (context.mounted) {
          ToastMessage.show(
            context: context,
            message: "Descarga iniciada: $fileName",
            type: ToastType.success,
          );
        }
      } else {
        throw Exception("El contenido del archivo está vacío.");
      }
    } else {
      throw Exception('Error al descargar contenido (${response.statusCode})');
    }
  } catch (e) {
    debugPrint("Error en downloadAttachment: $e");
    if (context.mounted) {
      ToastMessage.show(
        context: context,
        message: "Error al descargar el archivo.",
        type: ToastType.failure,
      );
    }
  }
}

void _triggerWebDownload(String base64Data, String fileName) {
  try {
    final Uint8List bytes = base64Decode(
      base64Data.replaceAll(RegExp(r'\s+'), ''),
    );
    final blob = Blob([bytes]);
    final url = Url.createObjectUrlFromBlob(blob);

    // ignore: unused_local_variable
    final anchor = AnchorElement(href: url)
      ..setAttribute("download", fileName)
      ..click();
    Url.revokeObjectUrl(url);
  } catch (e) {
    debugPrint("Error decodificando Base64 para descarga: $e");
  }
}
