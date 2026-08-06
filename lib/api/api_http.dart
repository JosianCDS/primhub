import 'dart:convert';
import 'package:http/http.dart' as http_client;
import 'package:primhub/api/api_utils.dart';
import 'package:primhub/api/token.dart';

// Exportamos MultipartRequest y dependencias comúnmente usadas para que el reemplazo de import 'package:http/http.dart' as http no rompa.
export 'package:http/http.dart' show MultipartRequest, MultipartFile, Response, StreamedResponse, Client;

/// Un wrapper alrededor de package:http/http.dart que intercepta automáticamente
/// las respuestas 401 (Unauthorized) e intenta refrescar el token de sesión.
bool _shouldSkipPreemptiveCheck(Uri url) {
  return url.path.contains('/auth/tokens');
}

Future<http_client.Response> get(Uri url, {Map<String, String>? headers}) async {
  final skipCheck = _shouldSkipPreemptiveCheck(url);
  if (!skipCheck) {
    await preemptiveTokenCheck();
  }
  final initialHeaders = skipCheck ? headers : (_updateAuthHeader(headers) ?? headers);
  
  var response = await http_client.get(url, headers: initialHeaders);
  if (response.statusCode == 401 && !skipCheck) {
    final refreshed = await handleTokenRefresh();
    if (refreshed) {
      // Reintentar con el nuevo token, actualizando el header Authorization si estaba presente
      final newHeaders = _updateAuthHeader(headers);
      response = await http_client.get(url, headers: newHeaders);
    }
  }
  return response;
}

Future<http_client.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
  final skipCheck = _shouldSkipPreemptiveCheck(url);
  if (!skipCheck) {
    await preemptiveTokenCheck();
  }
  final initialHeaders = skipCheck ? headers : (_updateAuthHeader(headers) ?? headers);

  var response = await http_client.post(url, headers: initialHeaders, body: body, encoding: encoding);
  if (response.statusCode == 401 && !skipCheck) {
    final refreshed = await handleTokenRefresh();
    if (refreshed) {
      final newHeaders = _updateAuthHeader(headers);
      response = await http_client.post(url, headers: newHeaders, body: body, encoding: encoding);
    }
  }
  return response;
}

Future<http_client.Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
  final skipCheck = _shouldSkipPreemptiveCheck(url);
  if (!skipCheck) {
    await preemptiveTokenCheck();
  }
  final initialHeaders = skipCheck ? headers : (_updateAuthHeader(headers) ?? headers);

  var response = await http_client.put(url, headers: initialHeaders, body: body, encoding: encoding);
  if (response.statusCode == 401 && !skipCheck) {
    final refreshed = await handleTokenRefresh();
    if (refreshed) {
      final newHeaders = _updateAuthHeader(headers);
      response = await http_client.put(url, headers: newHeaders, body: body, encoding: encoding);
    }
  }
  return response;
}

Future<http_client.Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
  final skipCheck = _shouldSkipPreemptiveCheck(url);
  if (!skipCheck) {
    await preemptiveTokenCheck();
  }
  final initialHeaders = skipCheck ? headers : (_updateAuthHeader(headers) ?? headers);

  var response = await http_client.delete(url, headers: initialHeaders, body: body, encoding: encoding);
  if (response.statusCode == 401 && !skipCheck) {
    final refreshed = await handleTokenRefresh();
    if (refreshed) {
      final newHeaders = _updateAuthHeader(headers);
      response = await http_client.delete(url, headers: newHeaders, body: body, encoding: encoding);
    }
  }
  return response;
}

Future<http_client.StreamedResponse> send(http_client.BaseRequest request) async {
  final skipCheck = _shouldSkipPreemptiveCheck(request.url);
  if (!skipCheck) {
    await preemptiveTokenCheck();
    if (Token.auth != null && Token.auth!.isNotEmpty) {
      if (request.headers.containsKey('Authorization') || request.headers.containsKey('authorization')) {
        final key = request.headers.containsKey('Authorization') ? 'Authorization' : 'authorization';
        request.headers[key] = Token.token;
      }
    }
  }

  // send consume el request, por lo que no es trivial reintentarlo si falla con 401
  // Esto es un wrapper básico, si se usa send (por ejemplo en MultipartRequest), 
  // es responsabilidad del llamante recrear el request si da 401, o se puede lanzar error.
  var response = await request.send();
  if (response.statusCode == 401 && !skipCheck) {
    final refreshed = await handleTokenRefresh();
    if (refreshed) {
      // Como el request original está "finalizado", no podemos simplemente hacer send(request) de nuevo.
      // Retornamos el 401 original y que el código que llama a send() lo maneje o recree.
      // Opcional: Podríamos intentar recrear Requests básicos, pero para Multipart es complejo.
    }
  }
  return response;
}

Map<String, String>? _updateAuthHeader(Map<String, String>? headers) {
  if (headers == null) return null;
  final newHeaders = Map<String, String>.from(headers);
  // Si el header original tenía Authorization, la reemplazamos con el token actualizado
  if (newHeaders.containsKey('Authorization') || newHeaders.containsKey('authorization')) {
    final key = newHeaders.containsKey('Authorization') ? 'Authorization' : 'authorization';
    if (Token.auth != null && Token.auth!.isNotEmpty) {
      newHeaders[key] = Token.token; 
    }
  }
  return newHeaders;
}
