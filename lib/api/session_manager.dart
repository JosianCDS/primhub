import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/api/auth_api.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/api/global_cache.dart';
import 'package:primhub/api/api_http.dart' as http;
import 'package:primhub/api/api_utils.dart';
import 'package:primhub/endpoint/endpoint.dart';

class SessionManager {
  // Singleton pattern
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  // IMPORTANTE: Esta clave debe ser asignada a la propiedad `navigatorKey`
  // de tu `MaterialApp.router` en `main.dart`.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool _isDialogShowing = false;
  Timer? _keepAliveTimer;

  /// Inicia el temporizador para refrescar la sesión automáticamente cada 30 minutos.
  void startKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(minutes: 57), (timer) async {
      if (Token.auth != null && Token.auth!.isNotEmpty) {
        try {
          // 1. Verificación local (si el token JWT tiene 'exp')
          final payload = Token.decodePayload(Token.auth!);
          if (payload.containsKey('exp')) {
            final exp = payload['exp'] as int;
            final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            if (now >= exp) {
              await handleTokenRefresh();
              return;
            }
          }

          // 2. Verificación remota (Ping)
          final response = await http.get(
            Uri.parse(Endpoint.authRoles),
            headers: {'Content-Type': 'application/json', 'Authorization': Token.token}
          );
          
          if (response.statusCode == 200) {
          } else if (response.statusCode == 401) {
            showSessionExpiredDialog();
          }
        } catch (e) {
          // Si es un error de CORS debido a un 401 en Web, intentamos refrescar la sesión
          if (e.toString().contains('Failed to fetch') || e.toString().contains('XMLHttpRequest error')) {
            await handleTokenRefresh();
          }
        }
      }
    });
  }

  /// Detiene el temporizador de refresco de sesión.
  void stopKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  /// Muestra un diálogo no descartable que indica que la sesión ha expirado,
  /// forzando al usuario a cerrar la sesión.
  void showSessionExpiredDialog() {
    stopKeepAliveTimer(); // Detener el temporizador si la sesión expiró
    // Usa la clave global del navegador para obtener un contexto que siempre está disponible.
    final context = navigatorKey.currentContext;

    // Previene que se muestren múltiples diálogos.
    if (context == null || _isDialogShowing) {
      return;
    }

    _isDialogShowing = true;

    // 1. Limpiar credenciales y caché inmediatamente para invalidar accesos
    Token.clear(); // Se ejecuta de forma asíncrona pero las variables en RAM se limpian síncronamente
    GlobalCache.clear();

    // 2. Redirigir de inmediato al login para bloquear la vista de datos
    GoRouter.of(context).go('/login');

    // 3. Mostrar el diálogo no-descartable sobre la pantalla de login
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final loginContext = navigatorKey.currentContext;
      if (loginContext == null) return;

      showDialog(
        context: loginContext,
        barrierDismissible: false, // El usuario no puede descartarlo tocando fuera.
        builder: (BuildContext dialogContext) {
          // Previene que se cierre con el botón de retroceso del dispositivo.
          return PopScope(
            canPop: false,
            child: CustomModal(
              title: 'Sesión expirada',
              width: 400,
              content: const Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Text('Por favor, inicie sesión nuevamente para continuar.'),
              ),
              actions: [
                CustomButton(
                  text: 'Aceptar',
                  onPressed: () {
                    _isDialogShowing = false;
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            ),
          );
        },
      ).then((_) => _isDialogShowing = false);
    });
  }
}
