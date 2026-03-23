import 'package:primhub/api/token.dart';
import 'package:primhub/api/admin_view_mode.dart';

class AccessControl {
  // Referenciamos a la clase User definida en token.dart
  static String? get userName => User.name;
  static int? get cBPartnerID => User.cBPartnerID;
  static int? get userID => User.userID;

  // Roles reales basados en la configuración del Token
  static bool get isRealAdmin => Token.primConfig?.toLowerCase() == 'ad';
  static bool get isRealSupport => Token.primConfig?.toLowerCase() == 'sp';
  static bool get isRealProject => Token.primConfig?.toLowerCase() == 'py';

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
