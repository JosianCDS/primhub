import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/Shared_Custom/customToast.dart';
import 'package:flutter/material.dart';
import 'package:primhub/api/global_cache.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';

Future<List<Map<String, dynamic>>> fetchContactsForBPartner(int bPartnerId) async {
  try {
    final uri = Uri.parse('${Endpoint.adUser}?\$filter=C_BPartner_ID eq $bPartnerId and IsActive eq true');
    final response = await http.get(uri, headers: {
      'Authorization': Token.token,
      'Content-Type': 'application/json',
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return List<Map<String, dynamic>>.from(data['records'] ?? []);
    }
  } catch (e) {
    CurrentLogMessage.add('Error fetchContactsForBPartner: $e', level: 'ERROR', tag: 'product_chip');
  }
  return [];
}

Future<List<Map<String, dynamic>>> fetchSupportProducts() async {
  try {
    final uri = Uri.parse('${Endpoint.mProduct}?\$filter=IsActive eq true and showinprimhub eq true&\$top=100');
    final response = await http.get(uri, headers: {
      'Authorization': Token.token,
      'Content-Type': 'application/json',
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return List<Map<String, dynamic>>.from(data['records'] ?? []);
    }
  } catch (e) {
    CurrentLogMessage.add('Error fetchSupportProducts: $e', level: 'ERROR', tag: 'product_chip');
  }
  return [];
}

Future<List<Map<String, dynamic>>> fetchPriceLists() async {
  try {
    final uri = Uri.parse('${Endpoint.priceList}?\$filter=IsActive eq true');
    final response = await http.get(uri, headers: {
      'Authorization': Token.token,
      'Content-Type': 'application/json',
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return List<Map<String, dynamic>>.from(data['records'] ?? []);
    }
  } catch (e) {
    CurrentLogMessage.add('Error fetchPriceLists: $e', level: 'ERROR', tag: 'product_chip');
  }
  return [];
}

Future<List<Map<String, dynamic>>> fetchFrequencyTypes() async {
  try {
    // Retornar lista exacta de iDempiere según los códigos reales
    return [
      {'Value': '1Y', 'Name': 'Anual'},
      {'Value': '2Y', 'Name': 'Bienal'},
      {'Value': '2M', 'Name': 'Bimensual'}, // Agregado de la captura
      {'Value': '4M', 'Name': 'Cuatrimestral'},
      {'Value': '1M', 'Name': 'Mensual'},
      {'Value': '5Y', 'Name': 'Quinquenal'},
      {'Value': '6M', 'Name': 'Semestralmente'},
      {'Value': '3Y', 'Name': 'Trienial'},
      {'Value': '3M', 'Name': 'Trimestralmente'},
    ];
  } catch (e) {
    CurrentLogMessage.add('Error fetchFrequencyTypes: $e', level: 'ERROR', tag: 'product_chip');
  }
  return [];
}

Future<Map<String, dynamic>> saveProductChip({
  required BuildContext context,
  required int bPartnerId,
  required int adUserId,
  required int productId,
  required double qty,
  required String description,
  required String frequencyType,
  required String contractNo,
  required String serviceStartDate,
  required String serviceFinishDate,
  required int priceListId,
}) async {
  try {
    final Map<String, dynamic> payload = {
      'C_BPartner_ID': {'id': bPartnerId},
      'AD_User_ID': {'id': adUserId},
      'M_Product_ID': {'id': productId},
      'Qty': qty,
      'Description': description,
      'FrequencyType': frequencyType,
      'contract_no': contractNo,
      'service_start_date': serviceStartDate,
      'service_finish_date': serviceFinishDate,
      'M_PriceList_ID': {'id': priceListId},
    };

    final response = await http.post(
      Uri.parse(Endpoint.productChip),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': Token.token,
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      return {'success': true, 'record': responseData};
    } else {
      CurrentLogMessage.add('saveProductChip Error: ${response.statusCode} - ${response.body}', level: 'ERROR', tag: 'product_chip');
      return {'success': false, 'message': 'Error al guardar la ficha (${response.statusCode})'};
    }
  } catch (e) {
    CurrentLogMessage.add('Exception en saveProductChip: $e', level: 'ERROR', tag: 'product_chip');
    return {'success': false, 'message': 'Error inesperado al guardar la ficha'};
  }
}
