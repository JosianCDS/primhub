import 'package:flutter/material.dart';
import 'package:primhub/theme/theme.dart';
import 'package:primhub/ui/pages/calendar.dart';
import 'package:primhub/ui/pages/deliverables.dart';
import 'package:primhub/ui/pages/home_page.dart';
import 'ui/pages/login.dart';
import 'package:primhub/ui/pages/knowledge_base.dart';
import 'package:primhub/ui/pages/marketplace.dart';
import 'package:primhub/ui/pages/metrics.dart';
import 'package:primhub/ui/pages/profile_page.dart';
import 'package:primhub/ui/pages/request/my_requests.dart';
import 'package:primhub/ui/pages/support.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('is_dark_mode') ?? false;
  AppThemes.themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemes.themeModeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'PrimHub',
          debugShowCheckedModeBanner: false,
          theme: AppThemes.lightTheme,
          darkTheme: AppThemes.darkTheme,
          themeMode: themeMode,
          initialRoute: '/login',
          routes: {
            '/': (context) => const HomePage(),
            '/login': (context) => const LoginPage(),
            '/support': (context) => const SupportPage(),
            '/my-requests': (context) => const MyRequestsPage(),
            '/knowledge-base': (context) => const KnowledgeBasePage(),
            '/deliverables': (context) => const DeliverablesPage(),
            '/metrics': (context) => const MetricsPage(),
            '/calendar': (context) => const CalendarPage(),
            '/marketplace': (context) => const MarketplacePage(),
            '/profile': (context) => const ProfilePage(),
          },
        );
      },
    );
  }
}
