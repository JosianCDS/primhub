import 'package:primhub/api/token.dart';

class AccessControl {
  // Referenciamos a la clase User definida en token.dart
  static String? get userName => User.name;
  static int? get cBPartnerID => User.cBPartnerID;
  static int? get userID => User.userID;

  // Roles basados en la configuración del Token
  // Usamos toLowerCase() por seguridad si el backend envía 'AD'
  static bool get isAdmin => Token.primConfig?.toLowerCase() == 'ad';
  static bool get isSupport => Token.primConfig?.toLowerCase() == 'sp';
  static bool get isProject => Token.primConfig?.toLowerCase() == 'py';

  // Capacidades de Proyecto
  static bool get canEditProject => isAdmin;
  static bool get canManageFiles => isAdmin; // Solo Admin puede subir/borrar/editar archivos
  static bool get canDownloadFiles => isAdmin || isProject;
  static bool get canCreateProjectItems => isAdmin;

  // Capacidades de Solicitudes (Soporte)
  static bool get canManageRequests => isAdmin; // Admin puede editar/borrar/completar
  static bool get canCreateRequests => isAdmin || isSupport;
  static bool get canViewRequestDetails => isAdmin || isSupport;

  // Capacidades de Métricas
  static bool get canViewProjectCharts => isAdmin || isProject; // Admin ve gráficos de Proyecto
  static bool get canViewSupportCharts => isAdmin || isSupport; // Admin ve gráficos de Soporte

  // EL FILTRO: Ahora garantizamos que si es admin o soporte, devuelva true
  static bool get canFilterMetrics => isAdmin || isSupport;

  // Restricciones de Datos
  static bool get limitToCurrentYear => isProject || isSupport;
}
