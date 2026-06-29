import 'package:primhub/api/auth_api.dart';
import 'package:primhub/api/session_manager.dart';
import 'package:primhub/api/token.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/api/global_cache.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';

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

Future<void> showLogoutConfirmation(BuildContext context) async {
  final bool? shouldLogout = await showDialog<bool>(
    context: context,
    builder: (context) => CustomModal(
      title: 'Cerrar Sesión',
      content: const Text('¿Seguro que quieres cerrar sesión?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        CustomButton(text: 'Sí, salir', backgroundColor: Colors.red, onPressed: () => Navigator.pop(context, true)),
      ],
    ),
  );
  if (shouldLogout == true) {
    // 1. Limpiar el token y la caché INMEDIATAMENTE.
    await Token.clear();
    GlobalCache.clear();
    // 2. Navegar al login. Ahora el router verá que no hay sesión y permitirá ir al login.
    // Usamos navigatorKey para obtener un contexto global y asegurar la navegación.
    final navContext = SessionManager.navigatorKey.currentContext;
    if (navContext != null && navContext.mounted) {
      GoRouter.of(navContext).go('/login');
    }
  }
}
