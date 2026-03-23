import 'package:primhub/api/auth_api.dart';
import 'package:primhub/api/session_manager.dart';
import 'package:primhub/api/token.dart';

/// Maneja los errores 401 intentando refrescar el token.
/// Si el refresco falla, muestra un diálogo de sesión expirada.
///
/// Devuelve `true` si la sesión fue refrescada (y la llamada original puede ser reintentada),
/// `false` en caso contrario.
Future<bool> handleTokenRefresh() async {
  if (Token.refreshToken == null || Token.refreshToken!.isEmpty) {
    return false;
  }

  // Asume que la función refreshToken existe en auth_api.dart
  final response = await refreshToken(Token.refreshToken!);
  if (response.containsKey('token')) {
    Token.auth = response['token'];
    if (response.containsKey('refresh_token')) {
      Token.refreshToken = response['refresh_token'];
    }
    return true; // Refrescado, se puede reintentar la llamada.
  } else {
    SessionManager().showSessionExpiredDialog();
    return false; // El refresco falló.
  }
}
