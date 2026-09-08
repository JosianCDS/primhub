import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:primhub/endpoint/endpoint.dart';

Future<Map<String, dynamic>> loginStep1(
  String username,
  String password,
) async {
  try {
    final response = await http.post(
      Uri.parse(Endpoint.authTokens),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'userName': username, 'password': password}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    if (response.body.toLowerCase().contains('<html')) {
      return {
        'error':
            'Error ${response.statusCode}: Servicio no disponible o ruta incorrecta.',
      };
    }
    return {'error': 'Error ${response.statusCode}: ${response.body}'};
  } catch (error) {
    return {'error': error.toString()};
  }
}

Future<List<dynamic>> getRoles(int clientId, String token) => _getOptions(
  Uri.parse('${Endpoint.authRoles}?client=$clientId'),
  token,
  'roles',
);

Future<List<dynamic>> getOrgs(int clientId, int roleId, String token) =>
    _getOptions(
      Uri.parse('${Endpoint.authOrgs}?client=$clientId&role=$roleId'),
      token,
      'organizations',
    );

Future<List<dynamic>> getWarehouses(
  int clientId,
  int roleId,
  int orgId,
  String token,
) => _getOptions(
  Uri.parse(
    '${Endpoint.authWarehouses}?client=$clientId&role=$roleId&organization=$orgId',
  ),
  token,
  'warehouses',
);

Future<List<dynamic>> _getOptions(Uri uri, String token, String key) async {
  try {
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data[key] as List<dynamic>? ?? const [];
    }
  } catch (_) {}
  return const [];
}
