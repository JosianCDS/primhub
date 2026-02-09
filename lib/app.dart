import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/theme/theme.dart';
import 'package:primhub/ui/pages/deliverables.dart';
import 'package:primhub/ui/pages/home_page.dart';
import 'package:primhub/ui/pages/knowledge_base.dart';
import 'package:primhub/ui/pages/login.dart';
import 'package:primhub/ui/pages/login_selection_page.dart';
import 'package:primhub/ui/pages/marketplace.dart';
import 'package:primhub/ui/pages/metrics.dart';
import 'package:primhub/ui/pages/my_projects.dart';
import 'package:primhub/ui/pages/profile_page.dart';
import 'package:primhub/ui/pages/request/my_requests.dart';
import 'package:primhub/ui/pages/support.dart';

final _router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final bool isLoggedIn = Token.auth != null;
    final bool isLoggingIn =
        state.uri.path == '/login' || state.uri.path == '/login-selection';

    if (!isLoggedIn && !isLoggingIn) {
      return '/login';
    }
    if (isLoggedIn && isLoggingIn) {
      return '/';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(
      path: '/login-selection',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const LoginSelectionPage(),
        arguments: state.extra,
      ),
    ),
    GoRoute(path: '/support', builder: (context, state) => const SupportPage()),
    GoRoute(
      path: '/my-requests',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const MyRequestsPage(),
        arguments: state.extra,
      ),
    ),
    GoRoute(
      path: '/knowledge-base',
      builder: (context, state) => const KnowledgeBasePage(),
    ),
    GoRoute(
      path: '/deliverables',
      builder: (context, state) => const DeliverablesPage(),
    ),
    GoRoute(path: '/metrics', builder: (context, state) => const MetricsPage()),
    GoRoute(
      path: '/marketplace',
      builder: (context, state) => const MarketplacePage(),
    ),
    GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
    GoRoute(
      path: '/my-projects',
      builder: (context, state) => const MyProjectsPage(),
    ),
  ],
);

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemes.themeModeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp.router(
          routerConfig: _router,
          title: 'PrimHub',
          debugShowCheckedModeBanner: false,
          theme: AppThemes.lightTheme,
          darkTheme: AppThemes.darkTheme,
          themeMode: themeMode,
        );
      },
    );
  }
}
