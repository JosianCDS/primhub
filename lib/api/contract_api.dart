import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:primhub/api/auth_api.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/api_utils.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';

class ContractApi {
  // Ahora usamos la Ficha de Producto del Tercero
  static const String productChipEndpoint = "C_BPartner_Product_Chip";

  static List<int>? _validProductIds;

  static Future<void> _ensureValidProductIds() async {
    if (_validProductIds != null) return;
    
    final endpoint = "${Endpoint.baseUrl}/api/v1/models/M_Product?\$filter=M_Product_UU eq 'ca31c9b7-4109-47c1-8f9d-84d0df7698bb' or M_Product_UU eq '3f5e9172-c6c4-4bc7-81f6-d1e0e5ba403a'&\$select=M_Product_ID";
    try {
      final response = await http.get(Uri.parse(endpoint), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final records = data['records'] as List;
        _validProductIds = records.map((r) => r['id'] as int).toList();
      }
    } catch (e) {
      debugPrint("Error fetching product IDs by UUID: $e");
    }
    // Si la API falla o no devuelve datos, usamos el ID conocido por defecto para no romper el sistema
    if (_validProductIds == null || _validProductIds!.isEmpty) {
      _validProductIds = [1000161];
    }
  }

  static Future<List<dynamic>> _fetchPaginated(String baseUrl) async {
    List<dynamic> allRecords = [];
    int skip = 0;
    int top = 100;
    bool hasMore = true;

    try {
      while (hasMore) {
        String queryUrl = "$baseUrl&\$skip=$skip&\$top=$top";
        var response = await http.get(Uri.parse(queryUrl), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});

        if (response.statusCode == 401) {
          final refreshed = await handleTokenRefresh();
          if (refreshed) {
            response = await http.get(Uri.parse(queryUrl), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});
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
      debugPrint("Error en paginación ProductChipApi: $e");
    }
    return allRecords;
  }

  /// Obtiene las fichas de producto (chips) para soporte.
  static Future<List<Map<String, dynamic>>> getSupportProductChips({int? bPartnerId, List<int>? bPartnerIds}) async {
    final String endpoint = "${Endpoint.baseUrl}/api/v1/models/$productChipEndpoint";
    
    // Filtro inicial: eliminamos IsActive eq 'Y' para ser más inclusivos si el usuario reporta que no se ven


    await _ensureValidProductIds();

    // Filtro por Tercero(s)
    List<int> finalBpIds = [];
    if (bPartnerId != null) finalBpIds.add(bPartnerId);
    if (bPartnerIds != null) finalBpIds.addAll(bPartnerIds);
    
    if (finalBpIds.isEmpty && !AccessControl.isAdmin && !AccessControl.isRealSupport && User.cBPartnerID != null) {
      finalBpIds.add(User.cBPartnerID!);
    }

    // No aplicamos filtro por tercero aquí; recuperamos todas las fichas y luego se filtrarán en la UI según el BPartner seleccionado
    // Construimos el filtro base usando los IDs dinámicos
    String prodFilter = _validProductIds!.map((id) => "M_Product_ID eq $id").join(' or ');
    String filter = "(IsActive eq 'Y' or IsActive eq true) and ($prodFilter)";

    if (finalBpIds.isNotEmpty) {
      // Filtro simple directo sobre el ID del socio
      String bpFilter = finalBpIds
          .map((id) => "C_BPartner_ID eq $id")
          .join(' or ');
      filter = "$filter and ($bpFilter)";
    }

    final String baseUrl = "$endpoint?\$filter=$filter";
    debugPrint("DEBUG ContractApi: Fetching chips from $baseUrl");

    try {
      final records = await _fetchPaginated(baseUrl);
      return records.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      debugPrint("Error obteniendo Product Chips: $e");
    }
    return [];
  }

  /// Obtiene la lista de Terceros que tienen al menos una ficha de producto activa de soporte.
  static Future<List<Map<String, dynamic>>> getBPartnersWithProductChips() async {
    await _ensureValidProductIds();
    final String endpoint = "${Endpoint.baseUrl}/api/v1/models/$productChipEndpoint";
    
    // Filtro de Ficha: Activo y Producto Soporte por UUID
    // También exigimos que el Tercero esté activo (IsActive eq true)
    String prodFilter = _validProductIds!.map((id) => "M_Product_ID eq $id").join(' or ');
    final String baseUrl = "$endpoint?\$filter=(IsActive eq 'Y' or IsActive eq true) and ($prodFilter)&\$expand=C_BPartner_ID(\$select=Name,IsActive;\$filter=IsActive eq true)";

    try {
      final records = await _fetchPaginated(baseUrl);
      final Map<int, Map<String, dynamic>> bPartners = {};
      
      for (var record in records) {
        final bpInfo = record['C_BPartner_ID'];
        if (bpInfo != null && bpInfo['id'] != null) {
          final bpId = bpInfo['id'];
          bPartners[bpId] = {
            'id': bpId, 
            'Name': bpInfo['identifier'] ?? bpInfo['Name'] ?? 'Tercero $bpId'
          };
        }
      }
      return bPartners.values.toList()..sort((a, b) => a['Name'].compareTo(b['Name']));
    } catch (e) {
      debugPrint("Error obteniendo terceros con Product Chips: $e");
    }
    return [];
  }

  /// Actualiza la descripción (nombre) de una ficha de producto.
  static Future<bool> updateProductChipDescription(int chipId, String newDescription) async {
    final String url = "${Endpoint.baseUrl}/api/v1/models/C_BPartner_Product_Chip/$chipId";
    final Map<String, dynamic> data = {
      "C_BPartner_Product_Chip_ID": chipId,
      "Description": newDescription,
    };

    try {
      debugPrint("DEBUG ContractApi: Updating chip $chipId with PUT. URL: $url");
      
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
        debugPrint("Error actualizando ficha (${response.statusCode}): ${response.body}");
      }
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint("Error actualizando descripción de Product Chip: $e");
      return false;
    }
  }
}
