import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/api/auth_api.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';

class ProjectsLogic {
  Future<List<dynamic>> fetchProjects(BuildContext context) async {
    String url =
        '${Endpoint.project}?\$expand=C_ProjectPhase(\$expand=C_ProjectTask)';

    try {
      var response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
      );

      if (response.statusCode == 401) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          response = await http.get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': Token.token,
            },
          );
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Sesión expirada. Por favor inicie sesión nuevamente.',
                ),
                backgroundColor: Colors.red,
              ),
            );
            context.go('/login');
          }
          return [];
        }
      }

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data['records'] ?? [];
      } else {
        throw Exception('Error al cargar proyectos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<bool> _tryRefreshToken() async {
    if (Token.refreshToken == null) return false;
    final response = await refreshToken(Token.refreshToken!);
    if (response.containsKey('token')) {
      Token.auth = response['token'];
      if (response.containsKey('refresh_token')) {
        Token.refreshToken = response['refresh_token'];
      }
      return true;
    }
    return false;
  }

  Future<List<dynamic>> fetchBPartners() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${Endpoint.cBPartner}?\$select=id,Name,Value&\$orderby=Name',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data['records'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  Future<List<dynamic>> fetchProjectTypes() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${Endpoint.baseUrl}/api/v1/models/C_ProjectType?\$select=id,Name&\$orderby=Name',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data['records'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  Future<bool> createProject({
    required String value,
    required String name,
    required String description,
    int? bpId,
    String? dateContract,
    String? dateFinish,
    int? projectTypeId,
  }) async {
    try {
      final createUrl = Uri.parse(Endpoint.project);
      final Map<String, dynamic> payload = {
        'Value': value,
        'Name': name,
        'Description': description,
      };

      if (bpId != null) {
        payload['C_BPartner_ID'] = {'id': bpId};
      }
      if (dateContract != null && dateContract.isNotEmpty) {
        payload['DateContract'] = dateContract.contains('T')
            ? dateContract
            : '${dateContract}T00:00:00Z';
      }
      if (dateFinish != null && dateFinish.isNotEmpty) {
        payload['DateFinish'] = dateFinish.contains('T')
            ? dateFinish
            : '${dateFinish}T00:00:00Z';
      }
      if (projectTypeId != null) {
        payload['C_ProjectType_ID'] = {'id': projectTypeId};
      }

      final response = await http.post(
        createUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
        body: jsonEncode(payload),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error creating project: $e');
      return false;
    }
  }

  Future<bool> createPhase(
    int projectId,
    String name,
    String description,
  ) async {
    try {
      final url = Uri.parse('${Endpoint.baseUrl}/api/v1/models/C_ProjectPhase');
      final body = {
        'C_Project_ID': {'id': projectId},
        'Name': name,
        'Description': description,
        'IsActive': true,
      };
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
        body: jsonEncode(body),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error creating phase: $e');
      return false;
    }
  }

  Future<bool> createTask(int phaseId, String name, String description) async {
    try {
      final url = Uri.parse('${Endpoint.baseUrl}/api/v1/models/C_ProjectTask');
      final body = {
        'C_ProjectPhase_ID': {'id': phaseId},
        'Name': name,
        'Description': description,
        'IsActive': true,
      };
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
        body: jsonEncode(body),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error creating task: $e');
      return false;
    }
  }

  Future<bool> updateItem(
    String type,
    int id,
    String name,
    String description,
  ) async {
    try {
      String endpoint = type == 'project'
          ? Endpoint.project
          : type == 'phase'
          ? '${Endpoint.baseUrl}/api/v1/models/C_ProjectPhase'
          : '${Endpoint.baseUrl}/api/v1/models/C_ProjectTask';
      final response = await http.put(
        Uri.parse('$endpoint/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
        body: jsonEncode({'Name': name, 'Description': description}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error updating item: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchRequestsForTask(
    String? taskUU,
  ) async {
    if (taskUU == null || taskUU.isEmpty) return [];
    try {
      final url = '${Endpoint.request}?\$filter=Record_UU eq \'$taskUU\'';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final records = jsonResponse['records'] as List?;
        if (records != null) {
          return List<Map<String, dynamic>>.from(records);
        }
      }
    } catch (e) {
      debugPrint('Exception fetching requests: $e');
    }
    return [];
  }
}
