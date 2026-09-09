import 'package:flutter/widgets.dart';
import 'package:primhub/navigation/deferred_route_page.dart';
import 'package:primhub/navigation/modules/home_module.dart' deferred as home;
import 'package:primhub/navigation/modules/metrics_module.dart'
    deferred as metrics;
import 'package:primhub/navigation/modules/projects_module.dart'
    deferred as projects;
import 'package:primhub/navigation/modules/reset_password_module.dart'
    deferred as reset_password;
import 'package:primhub/navigation/modules/secondary_module.dart'
    deferred as secondary;
import 'package:primhub/navigation/modules/support_module.dart'
    deferred as support;

abstract final class DeferredRegistry {
  static Future<void>? _home;
  static Future<void>? _support;
  static Future<void>? _projects;
  static Future<void>? _metrics;
  static Future<void>? _secondary;
  static Future<void>? _resetPassword;

  static Future<void> _memoized(
    Future<void>? current,
    void Function(Future<void>?) assign,
    Future<void> Function() loader,
  ) {
    if (current != null) return current;
    final future = loader();
    assign(future);
    future.catchError((Object _) => assign(null));
    return future;
  }

  static Future<void> loadHome() =>
      _memoized(_home, (value) => _home = value, home.loadLibrary);
  static Future<void> loadSupport() =>
      _memoized(_support, (value) => _support = value, support.loadLibrary);
  static Future<void> loadProjects() =>
      _memoized(_projects, (value) => _projects = value, projects.loadLibrary);
  static Future<void> loadMetrics() =>
      _memoized(_metrics, (value) => _metrics = value, metrics.loadLibrary);
  static Future<void> loadSecondary() => _memoized(
    _secondary,
    (value) => _secondary = value,
    secondary.loadLibrary,
  );
  static Future<void> loadResetPassword() => _memoized(
    _resetPassword,
    (value) => _resetPassword = value,
    reset_password.loadLibrary,
  );

  static void preloadHome() => loadHome().ignore();
  static void preloadForConfiguration(String? configuration) {
    preloadHome();
    switch (configuration?.toLowerCase()) {
      case 'sp':
      case 'extsp':
        loadSupport().ignore();
      case 'py':
      case 'extpy':
        loadProjects().ignore();
    }
  }

  static Widget homePage() =>
      DeferredRoutePage(loadLibrary: loadHome, builder: () => home.buildHomePage());
  static Widget splashPage() =>
      DeferredRoutePage(loadLibrary: loadHome, builder: () => home.buildSplashPage());
  static Widget supportPage() => DeferredRoutePage(
    loadLibrary: loadSupport,
    builder: () => support.buildSupportPage(),
  );
  static Widget myRequestsPage() => DeferredRoutePage(
    loadLibrary: loadSupport,
    builder: () => support.buildMyRequestsPage(),
  );
  static Widget requestUpdatesPage(int id, String docNo) => DeferredRoutePage(
    loadLibrary: loadSupport,
    builder: () => support.buildRequestUpdatesPage(id, docNo),
  );
  static Widget deliverablesPage() => DeferredRoutePage(
    loadLibrary: loadProjects,
    builder: () => projects.buildDeliverablesPage(),
  );
  static Widget projectRequestsPage(
    int? projectId,
    String? filterStatus,
    String? filterType,
    String? filterCompliance,
    bool showAllGroups,
  ) => DeferredRoutePage(
    loadLibrary: loadProjects,
    builder: () => projects.buildProjectRequestsPage(
      projectId,
      filterStatus,
      filterType,
      filterCompliance,
      showAllGroups,
    ),
  );
  static Widget projectCalendarPage(Map<String, dynamic> project) =>
      DeferredRoutePage(
        loadLibrary: loadProjects,
        builder: () => projects.buildProjectCalendarPage(project),
      );
  static Widget metricsPage() => DeferredRoutePage(
    loadLibrary: loadMetrics,
    builder: () => metrics.buildMetricsPage(),
  );
  static Widget repWorkloadPage() => DeferredRoutePage(
    loadLibrary: loadMetrics,
    builder: () => metrics.buildRepWorkloadPage(),
  );
  static Widget clientWorkloadPage() => DeferredRoutePage(
    loadLibrary: loadMetrics,
    builder: () => metrics.buildClientWorkloadPage(),
  );
  static Widget metricRequestsPage(
    int? projectId,
    String? filterStatus,
    String? filterType,
  ) => DeferredRoutePage(
    loadLibrary: loadMetrics,
    builder: () =>
        metrics.buildMetricRequestsPage(projectId, filterStatus, filterType),
  );
  static Widget knowledgeBasePage() => DeferredRoutePage(
    loadLibrary: loadSecondary,
    builder: () => secondary.buildKnowledgeBasePage(),
  );
  static Widget marketplacePage() => DeferredRoutePage(
    loadLibrary: loadSecondary,
    builder: () => secondary.buildMarketplacePage(),
  );
  static Widget profilePage() => DeferredRoutePage(
    loadLibrary: loadSecondary,
    builder: () => secondary.buildProfilePage(),
  );
  static Widget bPartnerDocumentsPage(String viewType) => DeferredRoutePage(
    loadLibrary: loadSecondary,
    builder: () => secondary.buildBPartnerDocumentsPage(viewType),
  );
  static Widget resetPasswordPage() => DeferredRoutePage(
    loadLibrary: loadResetPassword,
    builder: () => reset_password.buildResetPasswordPage(),
  );
}
