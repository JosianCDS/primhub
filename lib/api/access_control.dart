import 'package:primhub/api/token.dart';
import 'package:primhub/api/admin_view_mode.dart';

class AccessControl {
  // Referenciamos a la clase User definida en token.dart
  static String? get userName => User.name;
  static int? get cBPartnerID => User.cBPartnerID;
  static int? get userID => User.userID;

  static const List<int> supportRoles = [1000046];
  static const List<int> projectRoles = [1000047];
  static const List<int> adminRoles = [1000034, 1000032, 1000044, 1000033, 1000045, 1000048];

  static const List<int> adminConfigIds = [1000004, 1000011];
  static const List<int> supportConfigIds = [1000003, 1000013];
  static const List<int> projectConfigIds = [1000005, 1000012];

  // Verifica si el rol está configurado en el código fuente (útil para el login)
  static bool hasHardcodedRole(int? roleId) {
    if (roleId == null) return false;
    return adminRoles.contains(roleId) || supportRoles.contains(roleId) || projectRoles.contains(roleId);
  }

  static bool get hasAnyConfig => Token.primConfig != null || Token.primConfigId != null;

  static bool get _hasAdminConfig => Token.primConfig?.toLowerCase() == 'ad' || (Token.primConfigId != null && adminConfigIds.contains(Token.primConfigId));
  static bool get _hasSupportConfig => Token.primConfig?.toLowerCase() == 'sp' || (Token.primConfigId != null && supportConfigIds.contains(Token.primConfigId));
  static bool get _hasProjectConfig => Token.primConfig?.toLowerCase() == 'py' || (Token.primConfigId != null && projectConfigIds.contains(Token.primConfigId));

  // Roles reales basados en la configuración del Token
  static bool get isRealAdmin => _hasAdminConfig || (Token.rol != null && adminRoles.contains(Token.rol));
  static bool get isRealSupport => (!isRealAdmin && _hasSupportConfig) || (Token.rol != null && supportRoles.contains(Token.rol));
  static bool get isRealProject => (!isRealAdmin && _hasProjectConfig) || (Token.rol != null && projectRoles.contains(Token.rol));

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
  static bool get canAddUpdates => isAdmin || isRealSupport;
  static bool get canViewRequestDetails => true;

  // Capacidades de Métricas
  static bool get canViewProjectCharts => isProject; // Admin ve gráficos de Proyecto
  static bool get canViewSupportCharts => isSupport; // Admin ve gráficos de Soporte

  static bool get canFilterMetrics => isSupport || isProject;

  // Restricciones de Datos
  static bool get limitToCurrentYear => isProject || isSupport;
}
