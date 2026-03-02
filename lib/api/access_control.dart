import 'package:primhub/api/token.dart';

class AccessControl {
  static bool get isAdmin => Token.primConfig == 'ad';
  static bool get isSupport => Token.primConfig == 'sp';
  static bool get isProject => Token.primConfig == 'py';

  // Capacidades de Proyecto
  static bool get canEditProject => isAdmin;
  static bool get canManageFiles => isAdmin; // subir, editar, eliminar
  static bool get canDownloadFiles => isAdmin || isProject;
  static bool get canCreateProjectItems => isAdmin;

  // Capacidades de Solicitudes (Soporte)
  static bool get canManageRequests => isAdmin; // completar, editar, borrar. El rol Soporte solo puede crear.
  static bool get canCreateRequests => isAdmin || isSupport;
  static bool get canViewRequestDetails => isAdmin || isSupport || isProject;

  // Capacidades de Métricas
  static bool get canViewProjectCharts => isAdmin || isProject;
  static bool get canViewSupportCharts => isAdmin || isSupport;
  static bool get canFilterMetrics => isAdmin || isSupport;

  // Restricciones de Datos
  static bool get limitToCurrentYear => isProject || isSupport;
}
