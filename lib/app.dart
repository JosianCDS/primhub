import 'package:flutter/material.dart';
import 'package:primhub/theme/theme.dart';
import 'ui/pages/request/my_requests.dart';
import 'ui/pages/knowledge_base.dart';
import 'ui/pages/deliverables.dart';
import 'ui/pages/metrics.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/support.dart';
import 'ui/pages/calendar.dart';
import 'ui/pages/marketplace.dart';
import 'ui/pages/profile_page.dart';
import 'ui/pages/login.dart';
import 'ui/pages/login_selection_page.dart';
import 'ui/pages/api_test_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class ThemeManager {
  static late _MainAppState themeNotifier;
}

class _MainAppState extends State<MainApp> {
  @override
  void initState() {
    super.initState();
    ThemeManager.themeNotifier = this;
    _loadThemePreference();
    AppThemes.themeModeNotifier.addListener(_saveThemePreference);
  }

  @override
  void dispose() {
    AppThemes.themeModeNotifier.removeListener(_saveThemePreference);
    super.dispose();
  }

  Future<void> toggleTheme() async {
    AppThemes.themeModeNotifier.value =
        AppThemes.themeModeNotifier.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool('isDarkMode') ?? false;
    AppThemes.themeModeNotifier.value = isDarkMode
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  Future<void> _saveThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      'isDarkMode',
      AppThemes.themeModeNotifier.value == ThemeMode.dark,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemes.themeModeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          initialRoute: '/',
          theme: AppThemes.lightTheme,
          darkTheme: AppThemes.darkTheme,
          themeMode: themeMode,
          routes: {
            '/': (context) => const HomePage(),
            '/support': (context) => const SupportPage(),
            '/my-requests': (context) => const MyRequestsPage(),
            '/knowledge-base': (context) => const KnowledgeBasePage(),
            '/deliverables': (context) => const DeliverablesPage(),
            '/metrics': (context) => const MetricsPage(),
            '/calendar': (context) => const CalendarPage(),
            '/marketplace': (context) => const MarketplacePage(),
            '/profile': (context) => const ProfilePage(),
            '/login': (context) => const LoginPage(),
            '/login-selection': (context) => const LoginSelectionPage(),
            '/api-test': (context) => const ApiTestPage(),
          },
        );
      },
    );
  }
}
