import 'dart:convert';
import 'package:primhub/api/api_http.dart' as http;
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/api_utils.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';

class ContractApi {
  // Ahora usamos la Ficha de Producto del Tercero
  static const String productChipEndpoint = "C_BPartner_Product_Chip";

  /// Normaliza un string para búsqueda: minúsculas y sin acentos.
  static String _normalizeForSearch(String input) {
    return input
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n');
  }

  static Future<List<dynamic>> _fetchPaginated(String baseUrl) async {
    List<dynamic> allRecords = [];
    int skip = 0;
    int top = 100;
    bool hasMore = true;

    try {
      while (hasMore) {
        String queryUrl = "$baseUrl&\$skip=$skip&\$top=$top";
        var response = await http.get(
          Uri.parse(queryUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': Token.token,
          },
        );

        if (response.statusCode == 401) {
          final refreshed = await handleTokenRefresh();
          if (refreshed) {
            response = await http.get(
              Uri.parse(queryUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': Token.token,
              },
            );
          } else {
            return allRecords;
          }
        }

        if (response.statusCode == 200) {
          final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
          final records = jsonResponse['records'] as List;
          allRecords.addAll(records);
          if (records.length < top) {
            hasMore = false;
          } else {
            skip += top;
          }
        } else {
          hasMore = false;
        }
      }
    } catch (e) {
      // [Mantenimiento] Log removido:       debugPrint("Error in _fetchPaginated: $e");
    }
    return allRecords;
  }

  /// Obtiene los Product Chips (Fichas de Soporte) filtrando localmente.
  static Future<List<Map<String, dynamic>>> getSupportProductChips({
    int? bPartnerId,
    List<int>? bPartnerIds,
  }) async {
    final String endpoint =
        "${Endpoint.baseUrl}/api/v1/models/$productChipEndpoint";

    List<int> finalBpIds = [];
    if (bPartnerId != null) finalBpIds.add(bPartnerId);
    if (bPartnerIds != null) finalBpIds.addAll(bPartnerIds);

    if (finalBpIds.isEmpty &&
        !AccessControl.isAdmin &&
        !AccessControl.isRealSupport &&
        User.cBPartnerID != null) {
      finalBpIds.add(User.cBPartnerID!);
    }

    // Filtramos solo por activo en la API
    String filter = "(IsActive eq 'Y' or IsActive eq true)";

    if (finalBpIds.isNotEmpty) {
      String bpFilter = finalBpIds
          .map((id) => "C_BPartner_ID eq $id")
          .join(' or ');
      filter = "$filter and ($bpFilter)";
    }

    final String baseUrl = "$endpoint?\$filter=$filter";

    try {
      final records = await _fetchPaginated(baseUrl);
      
      // Filtramos localmente: debe contener 'soporte' Y 'tecnico' (sin importar acentos)
      final supportRecords = records.where((r) {
        final mProductId = r['M_Product_ID'];
        if (mProductId is Map) {
          final name = _normalizeForSearch((mProductId['identifier'] ?? '').toString());
          return name.contains('soporte') && name.contains('tecnico');
        }
        return false;
      }).toList();
      
      return supportRecords.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      // [Mantenimiento] Log removido:       debugPrint("Error obteniendo Product Chips: $e");
    }
    return [];
  }

  /// Obtiene la lista de Terceros que tienen al menos una ficha de producto activa de soporte.
  static Future<List<Map<String, dynamic>>>
  getBPartnersWithProductChips() async {
    final String endpoint =
        "${Endpoint.baseUrl}/api/v1/models/$productChipEndpoint";

    // Solo pedimos los activos y expandimos C_BPartner_ID
    final String baseUrl =
        "$endpoint?\$filter=(IsActive eq 'Y' or IsActive eq true)&\$expand=C_BPartner_ID(\$select=Name,IsActive)";

    try {
      final records = await _fetchPaginated(baseUrl);
      final Map<int, Map<String, dynamic>> bPartners = {};

      for (var record in records) {
        // Filtrado local: debe contener 'soporte' Y 'tecnico'
        final mProductId = record['M_Product_ID'];
        if (mProductId is! Map) continue;
        
        final prodName = _normalizeForSearch((mProductId['identifier'] ?? '').toString());
        if (!prodName.contains('soporte') || !prodName.contains('tecnico')) continue;

        final bpInfo = record['C_BPartner_ID'];
        if (bpInfo != null && bpInfo['id'] != null) {
          // Check if IsActive is false directly in Dart to avoid backend errors
          final isActive =
              bpInfo['IsActive'] == true || bpInfo['IsActive'] == 'Y';
          if (!isActive) continue;

          final bpId = bpInfo['id'];
          bPartners[bpId] = {
            'id': bpId,
            'Name': bpInfo['identifier'] ?? bpInfo['Name'] ?? 'Tercero $bpId',
          };
        }
      }
      return bPartners.values.toList()
        ..sort((a, b) => a['Name'].compareTo(b['Name']));
    } catch (e) {
      // [Mantenimiento] Log removido:       debugPrint("Error obteniendo terceros con Product Chips: $e");
    }
    return [];
  }

  /// Actualiza la descripción (nombre) de una ficha de producto.
  static Future<bool> updateProductChipDescription(
    int chipId,
    String newDescription,
  ) async {
    final String url =
        "${Endpoint.baseUrl}/api/v1/models/C_BPartner_Product_Chip/$chipId";
    final Map<String, dynamic> data = {
      "C_BPartner_Product_Chip_ID": chipId,
      "Description": newDescription,
    };

    try {
      // [Mantenimiento] Log removido:       debugPrint("DEBUG ContractApi: Updating chip $chipId with PUT. URL: $url");

      var response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 401) {
        final refreshed = await handleTokenRefresh();
        if (refreshed) {
          response = await http.put(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': Token.token,
            },
            body: jsonEncode(data),
          );
        } else {
          return false;
        }
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        // [Mantenimiento] Log removido:         debugPrint("Error actualizando ficha (${response.statusCode}): ${response.body}");
      }
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      // [Mantenimiento] Log removido:       debugPrint("Error actualizando descripción de Product Chip: $e");
      return false;
    }
  }
}
