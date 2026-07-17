import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/api/session_manager.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:primhub/theme/theme.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents.dart';
import 'package:primhub/ui/pages/Home/home_page.dart';
import 'package:primhub/ui/pages/OnDevelop/knowledge_base.dart';
import 'package:primhub/ui/pages/Projects/Projects_Widgets/project_requests_view.dart';
import 'package:primhub/ui/pages/Metrics/metrics_requests_page.dart';
import 'package:primhub/ui/pages/Login/login.dart';
import 'package:primhub/ui/pages/Login/reset_password_page.dart';
import 'package:primhub/ui/pages/Login/login_selection_page.dart';
import 'package:primhub/ui/pages/OnDevelop/marketplace.dart';
import 'package:primhub/ui/pages/Metrics/metrics.dart';
import 'package:primhub/ui/pages/OnDevelop/profile_page.dart';
import 'package:primhub/ui/pages/Support/Requests/my_requests.dart';
import 'package:primhub/ui/pages/Support/support_dashboard.dart';
import 'package:primhub/ui/pages/Support/Requests/request_updates_page.dart';
import 'package:primhub/api/splash_loading_page.dart';
import 'package:primhub/ui/pages/Projects/project_calendar_page.dart';
import 'package:primhub/ui/pages/BPartner/bpartner_documents_page.dart';

final _router = GoRouter(
  navigatorKey: SessionManager.navigatorKey,
  initialLocation: '/login',
  redirect: (context, state) {
    final bool isLoggedIn = Token.auth != null;
    final bool isLoggingIn = state.uri.path == '/login' || state.uri.path == '/login-selection' || state.uri.path == '/reset-password';

    if (!isLoggedIn && !isLoggingIn) {
      return '/login';
    }
    if (isLoggedIn && isLoggingIn) {
      return '/splash';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: const HomePage()),
    ),
    GoRoute(
      path: '/splash',
      pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: const SplashLoadingPage()),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: const LoginPage()),
    ),
    GoRoute(
      path: '/reset-password',
      pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: const ResetPasswordPage()),
    ),
    GoRoute(
      path: '/login-selection',
      pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: const LoginSelectionPage(), arguments: state.extra),
    ),
    GoRoute(
      path: '/support',
      pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: const SupportDashboardPage()),
    ),
    GoRoute(
      path: '/my-requests',
      pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: const MyRequestsPage(), arguments: state.extra),
    ),
    GoRoute(
      path: '/request-updates/:id',
      pageBuilder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        final extra = state.extra as Map<String, dynamic>?;
        final docNo = extra?['docNo'] ?? '...';
        if (id == null) return NoTransitionPage(key: state.pageKey, child: const HomePage()); // Fallback
        return NoTransitionPage(
          key: state.pageKey,
          child: RequestUpdatesPage(requestId: id, docNo: docNo),
        );
      },
    ),
    GoRoute(
      path: '/knowledge-base',
      pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: const KnowledgeBasePage()),
    ),
    GoRoute(
      path: '/deliverables',
      pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: const DeliverablesPage(), arguments: state.extra),
    ),
    GoRoute(
      path: '/metrics',
      pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: const MetricsPage()),
    ),
    GoRoute(
      path: '/metric-requests',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final rawId = extra?['projectId'];
        final projId = rawId is int ? rawId : (rawId != null ? int.tryParse(rawId.toString()) : null);
        return NoTransitionPage(
          key: state.pageKey,
          child: ProjectRequestsPage(projectId: projId, filterStatus: extra?['filterStatus'] as String?, filterType: extra?['filterType'] as String?),
        );
      },
    ),
    GoRoute(
      path: '/project-requests',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final rawId = extra?['projectId'];
        final projId = rawId is int ? rawId : (rawId != null ? int.tryParse(rawId.toString()) : null);
        return NoTransitionPage(
          key: state.pageKey,
          child: ProjectRequestsView(projectId: projId, filterStatus: extra?['filterStatus'] as String?, filterType: extra?['filterType'] as String?, filterCompliance: extra?['filterCompliance'] as String?, showAllGroups: extra?['showAllGroups'] as bool? ?? false),
        );
      },
    ),
    GoRoute(
      path: '/marketplace',
      pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: const MarketplacePage()),
    ),
    GoRoute(
      path: '/profile',
      pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: const ProfilePage()),
    ),
    GoRoute(
      path: '/project-calendar',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final project = extra ?? {};
        return NoTransitionPage(key: state.pageKey, child: ProjectCalendarPage(project: project));
      },
    ),
    GoRoute(
      path: '/bpartner-docs/general',
      pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: const BPartnerDocumentsPage(viewType: 'General')),
    ),
    GoRoute(
      path: '/bpartner-docs/seguimiento',
      pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: const BPartnerDocumentsPage(viewType: 'Seguimiento')),
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
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''),
            Locale('es', ''),
          ],
        );
      },
    );
  }
}
