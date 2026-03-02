import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/ImagesManagment/postAttachments.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';

class DocumentsLogic {
  static String getTypeCode(String viewType) {
    if (viewType == 'Entregables') return 'ET';
    if (viewType == 'Seguimiento') return 'SG';
    return 'GN';
  }

  static Future<List<dynamic>> fetchDocuments({required int projectId, required String viewType, required List<String> currentPath}) async {
    final typeCode = getTypeCode(viewType);
    try {
      var response = await http.get(Uri.parse('${Endpoint.primDocuments}?\$filter=C_Project_ID eq $projectId and Type eq \'$typeCode\'&\$expand=PRIM_Documents_Related'), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        List<dynamic> records = data['records'];

        // Lógica recursiva original para carpetas
        if (currentPath.length > 3) {
          final folderName = currentPath.last;
          final folderIndex = records.indexWhere((doc) => doc['Name'] == folderName && (doc['IsSummary'] == true || doc['IsSummary'] == 'Y'));

          if (folderIndex != -1) {
            final folderId = records[folderIndex]['id'];
            try {
              final childrenResponse = await http.get(Uri.parse('${Endpoint.primDocuments}/$folderId/PRIM_Documents_Related'), headers: {'Authorization': Token.token});
              if (childrenResponse.statusCode == 200) {
                final childrenData = json.decode(utf8.decode(childrenResponse.bodyBytes));
                records[folderIndex]['PRIM_Documents_Related'] = childrenData['records'];
              }
            } catch (e) {
              debugPrint('Error fetching folder children: $e');
            }
          }
        }
        return records;
      }
    } catch (e) {
      debugPrint('Error fetching documents: $e');
    }
    return [];
  }

  static Future<bool> createFolder({required String name, required int projectId, required String viewType, required List<String> currentPath, required List<dynamic> documents}) async {
    final typeCode = getTypeCode(viewType);
    final Uri createUrl = Uri.parse(Endpoint.primDocuments);
    final Map<String, dynamic> payload = {
      'Name': name,
      'name': name,
      'C_Project_ID': {'id': projectId},
      'Type': typeCode,
      'IsSummary': true,
    };

    if (currentPath.length > 3) {
      final folderName = currentPath.last;
      final folder = documents.firstWhere((doc) => doc['Name'] == folderName && (doc['IsSummary'] == true || doc['IsSummary'] == 'Y'), orElse: () => null);
      if (folder != null) {
        payload['PRIM_Documents_ID'] = {'id': folder['id']};
        payload.remove('C_Project_ID');
      }
    }

    try {
      final response = await http.post(createUrl, headers: {'Content-Type': 'application/json', 'Authorization': Token.token}, body: jsonEncode(payload));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error creating folder: $e');
      return false;
    }
  }

  static Future<bool> uploadFile({required String fileName, required Uint8List fileBytes, required int projectId, required String viewType, required List<String> currentPath, required List<dynamic> documents}) async {
    final String extension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    final typeCode = getTypeCode(viewType);
    Uri createUrl = Uri.parse(Endpoint.primDocuments);

    final Map<String, dynamic> payload = {
      'Name': fileName,
      'name': fileName,
      'C_Project_ID': {'id': projectId},
      'Type': typeCode,
      'Extension': extension,
      'VersionNo': '1.0',
      'Status': 'PD',
      'IsActive': true,
    };

    if (currentPath.length > 3) {
      final folderName = currentPath.last;
      final folder = documents.firstWhere((doc) => doc['Name'] == folderName && (doc['IsSummary'] == true || doc['IsSummary'] == 'Y'), orElse: () => null);
      if (folder != null) {
        createUrl = Uri.parse(Endpoint.primDocumentsRelated);
        payload['PRIM_Documents_ID'] = {'id': folder['id']};
        payload.remove('C_Project_ID');
      } else {
        return false;
      }
    }

    try {
      final createResponse = await http.post(createUrl, headers: {'Content-Type': 'application/json', 'Authorization': Token.token}, body: jsonEncode(payload));

      if (createResponse.statusCode == 200 || createResponse.statusCode == 201) {
        final newRecord = jsonDecode(createResponse.body);
        final newRecordId = newRecord['id'];
        return await postAttachments(recordID: newRecordId, tableName: createUrl.toString(), convertedFile: {'title': fileName, 'base64': base64Encode(fileBytes)});
      }
    } catch (e) {
      debugPrint('Error uploading file: $e');
    }
    return false;
  }

  static Future<bool> deleteFile(int id, String tableName) async {
    try {
      final response = await http.delete(Uri.parse('$tableName/$id'), headers: {'Authorization': Token.token});
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Error deleting file: $e');
      return false;
    }
  }

  static Future<bool> updateDocumentRemote(int id, Map<String, dynamic> body) async {
    final url = Uri.parse('${Endpoint.primDocuments}/$id');
    try {
      final response = await http.put(url, headers: {'Content-Type': 'application/json', 'Authorization': Token.token}, body: jsonEncode(body));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  static Future<Uint8List?> fetchImagePreview(String tableName, int recordId, String fileName) async {
    try {
      final url = '$tableName/$recordId/attachments/${Uri.encodeComponent(fileName)}';
      final response = await http.get(Uri.parse(url), headers: {'Authorization': Token.token});
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('Error fetching image preview: $e');
    }
    return null;
  }

  static Future<bool> deleteRequest(int id) async {
    return deleteFile(id, Endpoint.request);
  }

  static Future<List<dynamic>> fetchStatuses() async {
    return [
      {'id': 'PD', 'identifier': 'Pendiente', 'name': 'Pendiente'},
      {'id': 'ER', 'identifier': 'En revisión', 'name': 'En revisión'},
      {'id': 'ET', 'identifier': 'Entregado', 'name': 'Entregado'},
    ];
  }

  static List<Map<String, dynamic>> performSearch(String query, List<dynamic> documents, List<String> rootPath) {
    final List<Map<String, dynamic>> results = [];
    if (query.isEmpty) return results;

    void searchRecursive(List<dynamic> docs, List<String> path) {
      for (final doc in docs) {
        final docName = (doc['Name'] as String? ?? '').toLowerCase();
        final isFolder = doc['IsSummary'] == true || doc['IsSummary'] == 'Y';

        if (!isFolder && docName.contains(query.toLowerCase())) {
          results.add({'doc': doc, 'path': List<String>.from(path)});
        }

        if (isFolder) {
          final children = doc['PRIM_Documents_Related'] as List? ?? [];
          if (children.isNotEmpty) {
            searchRecursive(children, [...path, doc['Name'] as String]);
          }
        }
      }
    }

    searchRecursive(documents, rootPath);
    return results;
  }

  // --- Helpers Puros ---

  static String extractValue(dynamic val) => extractIdentifier(val);

  static String extractStatus(dynamic val) {
    if (val == null) return 'Pendiente';
    if (val is String) return val;
    if (val is Map) return val['identifier']?.toString() ?? val['name']?.toString() ?? 'Pendiente';
    return 'Pendiente';
  }

  static String extractIdentifier(dynamic val, {String defaultValue = 'N/A'}) {
    if (val == null) return defaultValue;
    if (val is String) return val.isEmpty ? defaultValue : val;
    if (val is Map) return val['identifier']?.toString() ?? val['name']?.toString() ?? defaultValue;
    return val.toString();
  }

  static String formatDate(String? dateStr) {
    if (dateStr == null) return 'No definida';
    try {
      final DateTime date = DateTime.parse(dateStr).toLocal();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  static IconData getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.grid_on;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
        return Icons.image;
      case 'txt':
      case 'json':
      case 'xml':
      case 'md':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  static Color getStatusColor(String status) {
    switch (status) {
      case 'Entregado':
        return Colors.green.shade600;
      case 'En revisión':
        return Colors.amber.shade700;
      case 'Pendiente':
        return Colors.red.shade600;
      default:
        return Colors.grey;
    }
  }
}
