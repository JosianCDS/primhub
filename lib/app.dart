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
bool _isDarkMode = false;

Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = !_isDarkMode;
      prefs.setBool('isDarkMode', _isDarkMode);
    });
  }

    @override
  void initState() {
    super.initState();
    ThemeManager.themeNotifier = this;
    _loadThemePreference();

    
  }

    Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      theme: _isDarkMode ? AppThemes.darkTheme : AppThemes.lightTheme,
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
      },
    );
  }
}