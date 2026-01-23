import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:primhub/endpoint/endpoint.dart';

class AuthApi {
  // Paso 1: Login inicial con usuario y contraseña
  static Future<Map<String, dynamic>> loginStep1(
    String username,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(Endpoint.authTokens),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userName': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'error': 'Error ${response.statusCode}: ${response.body}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Obtener Roles disponibles
  static Future<List<dynamic>> getRoles(int clientId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('${Endpoint.authRoles}?client=$clientId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['roles'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  // Obtener Organizaciones disponibles
  static Future<List<dynamic>> getOrgs(
    int clientId,
    int roleId,
    String token,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('${Endpoint.authOrgs}?client=$clientId&role=$roleId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['organizations'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  // Obtener Almacenes (Opcional)
  static Future<List<dynamic>> getWarehouses(
    int clientId,
    int roleId,
    int orgId,
    String token,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${Endpoint.authWarehouses}?client=$clientId&role=$roleId&organization=$orgId',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['warehouses'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  // Paso Final: Confirmar login con parámetros de sesión
  static Future<Map<String, dynamic>> finalizeLogin(
    String username,
    String password,
    Map<String, dynamic> contextParams,
  ) async {
    try {
      final body = {
        "userName": username,
        "password": password,
        "parameters": contextParams,
      };

      // Usamos POST como en el ejemplo de referencia
      final response = await http.post(
        Uri.parse(Endpoint.authTokens),
        headers: {
          'Content-Type': 'application/json',
          // Nota: El ejemplo de referencia NO envía el token Bearer en este paso final,
          // sino que re-envía las credenciales.
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'error': 'Error ${response.statusCode}: ${response.body}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Refrescar Token
  static Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      final response = await http.put(
        Uri.parse(Endpoint.authTokens),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $refreshToken',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'error': 'Error ${response.statusCode}: ${response.body}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
