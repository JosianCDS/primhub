import 'package:primhub/api/token.dart';
import 'package:primhub/api/admin_view_mode.dart';

class AccessControl {
  // Referenciamos a la clase User definida en token.dart
  static String? get userName => User.name;
  static int? get cBPartnerID => User.cBPartnerID;
  static int? get userID => User.userID;

  // Roles basados en la configuración del Token
  // Usamos toLowerCase() por seguridad si el backend envía 'AD'
  static bool get isAdmin => Token.primConfig?.toLowerCase() == 'ad'; // Rol real

  // Roles EFECTIVOS para la UI. Un admin puede simular ser de soporte o proyecto.
  static bool get isSupport {
    if (Token.primConfig?.toLowerCase() == 'sp') return true; // Un usuario de soporte real siempre lo es.
    if (isAdmin) {
      // Si es admin, depende del modo de vista seleccionado.
      return AdminViewModeManager().currentMode == AdminViewMode.support || AdminViewModeManager().currentMode == AdminViewMode.mixed;
    }
    return false;
  }

  static bool get isProject {
    if (Token.primConfig?.toLowerCase() == 'py') return true; // Un usuario de proyecto real siempre lo es.
    if (isAdmin) {
      // Si es admin, depende del modo de vista seleccionado.
      return AdminViewModeManager().currentMode == AdminViewMode.project || AdminViewModeManager().currentMode == AdminViewMode.mixed;
    }
    return false;
  }

  // Capacidades de Proyecto
  static bool get canEditProject => isAdmin;
  static bool get canManageFiles => isAdmin; // Solo Admin puede subir/borrar/editar archivos
  static bool get canDownloadFiles => isAdmin || isProject;
  static bool get canCreateProjectItems => isAdmin;

  // Capacidades de Solicitudes (Soporte)
  static bool get canManageRequests => isAdmin; // Admin puede editar/borrar/completar
  static bool get canCreateRequests => isSupport;
  static bool get canViewRequestDetails => isSupport;

  // Capacidades de Métricas
  static bool get canViewProjectCharts => isProject; // Admin ve gráficos de Proyecto
  static bool get canViewSupportCharts => isSupport; // Admin ve gráficos de Soporte

  // EL FILTRO: Ahora garantizamos que si es admin o soporte, devuelva true
  static bool get canFilterMetrics => isSupport || isProject;

  // Restricciones de Datos
  static bool get limitToCurrentYear => isProject || isSupport;
}
