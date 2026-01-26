import 'dart:convert';

class Token {
  static String? preAuth;
  static String? auth;
  static String? refreshToken;
  static int? client;
  static int? rol;
  static int? organitation;
  static int? warehouseID;

  static String tokenType = 'Bearer';
  static String get token {
    if (auth == null) return "";
    return "$tokenType $auth";
  }

  static Map<String, dynamic> decodePayload(String token) {
    try {
      if (token.startsWith('Bearer ')) {
        token = token.substring(7);
      }
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final payload = _decodeBase64(parts[1]);
      final payloadMap = json.decode(payload);
      if (payloadMap is! Map<String, dynamic>) return {};
      return payloadMap;
    } catch (e) {
      return {};
    }
  }

  static String _decodeBase64(String str) {
    String output = str.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        throw Exception('Illegal base64url string!"');
    }
    return utf8.decode(base64Url.decode(output));
  }
}

class CurrentLogMessage {
  static List<Map<String, dynamic>> log = [];
  static void add(String message, {String level = 'INFO', String? tag}) {
    final entry = {
      'ts': DateTime.now().toIso8601String(),
      'level': level,
      'tag': tag,
      'message': message,
    };
    log.add(entry);
    print('[$level] $message');

    if (log.length > 1000) {
      log.removeAt(0);
    }
  }
}

class AppInfo {
  static String? appVersion;
}
