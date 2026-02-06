import 'package:flutter/material.dart';
import 'package:primhub/app.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('is_dark_mode') ?? false;
  AppThemes.themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  final savedUrl = prefs.getString('api_base_url');
  if (savedUrl != null) {
    Endpoint.baseUrl = savedUrl;
  }

  runApp(const MainApp());
}
