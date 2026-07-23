import 'package:flutter/material.dart';
import 'package:primhub/app.dart';
import 'package:primhub/api/admin_view_mode.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/api/session_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('is_dark_mode') ?? false;
  AppThemes.themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  await AdminViewModeManager().loadMode();

  // Restaurar sesión persistida
  final authToken = prefs.getString('auth_token');
  if (authToken != null && authToken.isNotEmpty) {
    Token.auth = authToken;
    Token.refreshToken = prefs.getString('refresh_token');
    Token.rol = prefs.getInt('token_rol');
    Token.client = prefs.getInt('token_client');
    Token.roleUU = prefs.getString('token_role_uu');
    Token.organitation = prefs.getInt('token_organitation');
    Token.warehouseID = prefs.getInt('token_warehouse');
    Token.primConfig = prefs.getString('token_primconfig');
    Token.primConfigId = prefs.getInt('token_primconfig_id');
    
    User.userID = prefs.getInt('user_id');
    User.cBPartnerID = prefs.getInt('cbpartner_id');
    User.name = prefs.getString('user_name');
    
    // Iniciar temporizador de refresco porque ya hay un token cargado
    SessionManager().startKeepAliveTimer();
  }

  final savedUrl = prefs.getString('api_base_url');
  if (savedUrl != null) {
    final currentUrl = Uri.base.toString();
    if (!currentUrl.contains('hubtest.primware.net') && !currentUrl.contains('hub.primware.net')) {
      Endpoint.baseUrl = savedUrl;
    }
  }

  runApp(const MainApp());
}
