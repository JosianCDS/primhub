import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final token = 'PASTE_TOKEN_HERE'; // I should use the one from the app if possible
  final baseUrl = 'https://primware.primhub.net'; // Assuming from context
  
  final response = await http.get(
    Uri.parse('$baseUrl/api/v1/models/R_Category?\$top=5'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': token,
    },
  );
  
  print('Status: ${response.statusCode}');
  print('Body: ${response.body}');
}
