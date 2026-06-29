import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/api/global_cache.dart';

class SessionManager {
  // Singleton pattern
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  // IMPORTANTE: Esta clave debe ser asignada a la propiedad `navigatorKey`
  // de tu `MaterialApp.router` en `main.dart`.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool _isDialogShowing = false;

  /// Muestra un diálogo no descartable que indica que la sesión ha expirado,
  /// forzando al usuario a cerrar la sesión.
  void showSessionExpiredDialog() {
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
