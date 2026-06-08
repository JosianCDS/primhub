import 'package:primhub/api/token.dart';
import 'package:primhub/api/admin_view_mode.dart';

class AccessControl {
  // Referenciamos a la clase User definida en token.dart
  static String? get userName => User.name;
  static int? get cBPartnerID => User.cBPartnerID;
  static int? get userID => User.userID;

  // Listas de UUIDs oficiales para cada rol
  static const List<String> adminUUIDs = [
    '7540bc88-7f9c-4a42-b755-28a6129f00b3',
    'cb3e6b57-0114-4e35-a147-71c51140823b'
  ];
  static const List<String> projectUUIDs = [
    '03d91fb2-5427-4788-b2ca-1beeb16f7b09',
    '1ccc4784-8228-40f4-80ba-0dd6f0e65bc9'
  ];
  static const List<String> supportUUIDs = [
    '2d24dcaf-d652-4acf-8e61-87e4294b266f',
    '068df55c-f80b-4d88-88c8-ad9a80af19c8'
  ];

  // Verifica si el rol tiene configuración válida (usado en Login)
  static bool hasHardcodedRole(int? roleId) {
    // Verificación estricta por UUID
    if (Token.roleUU != null) {
      if (adminUUIDs.contains(Token.roleUU)) return true;
      if (supportUUIDs.contains(Token.roleUU)) return true;
      if (projectUUIDs.contains(Token.roleUU)) return true;
    }
    return false;
  }

  static bool get hasAnyConfig => Token.primConfig != null;

  static bool get _hasAdminConfig => Token.primConfig?.toLowerCase() == 'ad';
  static bool get _hasSupportConfig => Token.primConfig?.toLowerCase() == 'sp';
  static bool get _hasProjectConfig => Token.primConfig?.toLowerCase() == 'py';

  // Roles reales basados PRINCIPALMENTE en UUID y nivel de configuración
  static bool get isRealAdmin => 
    (Token.roleUU != null && adminUUIDs.contains(Token.roleUU)) ||
    _hasAdminConfig;

  static bool get isRealSupport => !isRealAdmin && (
    (Token.roleUU != null && supportUUIDs.contains(Token.roleUU)) ||
    _hasSupportConfig
  );

  static bool get isRealProject => !isRealAdmin && (
    (Token.roleUU != null && projectUUIDs.contains(Token.roleUU)) ||
    _hasProjectConfig
  );

  static bool get isAdmin => isRealAdmin;

  // Roles EFECTIVOS para la UI. Un admin puede simular ser de soporte o proyecto.
  static bool get isSupport {
    if (isRealSupport) return true;
    if (isAdmin) {
      return AdminViewModeManager().currentMode == AdminViewMode.support || AdminViewModeManager().currentMode == AdminViewMode.mixed;
    }
    return false;
  }

  static bool get isProject {
    if (isRealProject) return true;
    if (isAdmin) {
      return AdminViewModeManager().currentMode == AdminViewMode.project || AdminViewModeManager().currentMode == AdminViewMode.mixed;
    }
    return false;
  }

  // Capacidades de Proyecto
  static bool get canEditProject => isAdmin;
  static bool get canManageFiles => isAdmin; // Soporte y Proyecto no pueden subir ni borrar archivos
  static bool get canDownloadFiles => true; // Todos pueden descargar y previsualizar
  static bool get canCreateProjectItems => isAdmin;

  // Capacidades de Solicitudes (Soporte)
  static bool get canManageRequests => isAdmin; // Solo admin edita/elimina a fondo
  static bool get canCreateRequests => isAdmin || isRealSupport; // Proyecto real es Solo Lectura
  static bool get canAddUpdates => isAdmin; // Soporte solo puede ver las actualizaciones, no responder
  static bool get canViewRequestDetails => true;

  // Capacidades de Métricas
  static bool get canViewProjectCharts => isProject; // Admin ve gráficos de Proyecto
  static bool get canViewSupportCharts => isSupport; // Admin ve gráficos de Soporte

  static bool get canFilterMetrics => isSupport || isProject;

  // Restricciones de Datos
  static bool get limitToCurrentYear => isProject || isSupport;
}
