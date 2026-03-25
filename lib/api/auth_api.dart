import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/contract_api.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/pages/Login/login.dart';

Future<Map<String, dynamic>> loginStep1(String username, String password) async {
  try {
    final response = await post(Uri.parse(Endpoint.authTokens), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'userName': username, 'password': password}));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    // Manejar respuestas HTML (como errores 404/500 del servidor web)
    if (response.body.toLowerCase().contains('<html')) {
      return {'error': 'Error ${response.statusCode}: Servicio no disponible o ruta incorrecta.'};
    }
    return {'error': 'Error ${response.statusCode}: ${response.body}'};
  } catch (e) {
    return {'error': e.toString()};
  }
}

// Obtener Roles disponibles
Future<List<dynamic>> getRoles(int clientId, String token) async {
  try {
    final response = await get(Uri.parse('${Endpoint.authRoles}?client=$clientId'), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['roles'] ?? [];
    }
  } catch (_) {}
  return [];
}

// Obtener Organizaciones disponibles
Future<List<dynamic>> getOrgs(int clientId, int roleId, String token) async {
  try {
    final response = await get(Uri.parse('${Endpoint.authOrgs}?client=$clientId&role=$roleId'), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['organizations'] ?? [];
    }
  } catch (_) {}
  return [];
}

// Obtener Almacenes (Opcional)
Future<List<dynamic>> getWarehouses(int clientId, int roleId, int orgId, String token) async {
  try {
    final response = await get(Uri.parse('${Endpoint.authWarehouses}?client=$clientId&role=$roleId&organization=$orgId'), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['warehouses'] ?? [];
    }
  } catch (_) {}
  return [];
}

//Confirmar login con parámetros de sesión
Future<bool> finalizeLogin(String username, String password, Map<String, dynamic> contextParams, BuildContext context) async {
  try {
    final body = {"userName": username, "password": password, "parameters": contextParams};

    final response = await post(Uri.parse(Endpoint.authTokens), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      Token.auth = responseBody['token'];
      Token.refreshToken = responseBody['refresh_token'];
      User.userID = responseBody['userId'];
      User.cBPartnerID = await getPartnerID(userId: User.userID!);

      bool hasSupport = false;
      bool hasProject = false;

      final bool config = await getPrimConfig(rolId: Token.rol!, context: context);

      if (config == false && !AccessControl.adminRoles.contains(Token.rol)) {
        Token.primConfig = null;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('El Rol no tiene configuración.'), backgroundColor: Colors.red));
        Token.auth = null;
        Token.refreshToken = null;
        User.userID = null;
        User.cBPartnerID = null;

        return false;
      }

      if (AccessControl.isAdmin || AccessControl.isRealSupport) {
        // For Admin or Support users, we assume they can see support features.
        // Set the product ID so subsequent API calls work.
        ProductChip.mProductID = 1000816;
        hasSupport = true; // Let's assume true, the home controller will load the actual data.
        hasProject = true;
      } else if (User.cBPartnerID != null) {
        // For other users (like Project users)
        await getProductChip();
        if (ProductChip.mProductID != null) {
          final contracts = await ContractApi.getSupportContracts(bPartnerId: User.cBPartnerID);
          hasSupport = contracts.isNotEmpty;
        } else {
          hasSupport = false;
        }
        hasProject = await checkProjects();
      } else {
        hasSupport = false;
        hasProject = false;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_support', hasSupport);
      await prefs.setBool('has_project', hasProject);
      // Éxito, el token y datos de usuario ya se guardaron.
      return true;
    }
  } catch (e) {}
  return false;
}

// Refrescar Token
Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
  try {
    final response = await put(Uri.parse(Endpoint.authTokens), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $refreshToken'});
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    if (response.body.toLowerCase().contains('<html')) {
      return {'error': 'Error ${response.statusCode}: Servicio no disponible.'};
    }
    return {'error': 'Error ${response.statusCode}: ${response.body}'};
  } catch (e) {
    return {'error': e.toString()};
  }
}

//Tercero
Future<int?> getPartnerID({required int userId}) async {
  try {
    final response = await get(Uri.parse('${Endpoint.adUser}?\$filter=AD_User_ID eq $userId'), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      final records = jsonResponse['records'] as List;
      final cBpartnerId = records.isNotEmpty ? records[0]['C_BPartner_ID']['id'] : null;
      return cBpartnerId;
    }
  } catch (e) {}
  return null;
}

//PrimConfig
Future<bool> getPrimConfig({required int rolId, required BuildContext context}) async {
  try {
    final response = await get(Uri.parse('${Endpoint.primConfig}?\$filter=AD_Role_ID eq $rolId'), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      final records = jsonResponse['records'] as List;
      Token.primConfig = records.isNotEmpty ? records[0]['ConfigurationLevel']['id'] : null;

      return Token.primConfig != null;
    }
  } catch (e) {}
  return false;
}

//Ficha de Producto
Future<void> getProductChip() async {
  try {
    final response = await get(Uri.parse('${Endpoint.productChip}?\$filter=C_BPartner_ID eq ${User.cBPartnerID} and M_Product_ID eq 1000816&\$orderBy=Created desc'), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      final records = jsonResponse['records'] as List;
      ProductChip.frecuencyID = records.isNotEmpty ? records[0]['FrequencyType']['id'] : null;

      ProductChip.frecuencyName = records.isNotEmpty ? records[0]['FrequencyType']['value'] : null;

      ProductChip.mProductID = records.isNotEmpty ? records[0]['M_Product_ID']['id'] : null;

      ProductChip.iD = records.isNotEmpty ? records[0]['id'] : null;
    }
  } catch (e) {}
}

// Verificar si tiene proyectos
Future<bool> checkProjects() async {
  if (User.cBPartnerID == null) return false;
  try {
    final response = await get(Uri.parse('${Endpoint.project}?\$filter=C_BPartner_ID eq ${User.cBPartnerID}&\$top=1'), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      final records = jsonResponse['records'] as List;
      return records.isNotEmpty;
    }
  } catch (e) {}
  return false;
}
