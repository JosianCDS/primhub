import 'package:primhub/api/token.dart';

class AccessControl {
  static const String adminUuid = '04e515a8-e060-42dd-b79b-edd3fd3f2e4b';
  static const String supportUserUuid = '2d24dcaf-d652-4acf-8e61-87e4294b266f';
  static const String projectUserUuid = '03d91fb2-5427-4788-b2ca-1beeb16f7b09';

  // Fallback IDs por si acaso
  static const int adminId = 1000013;
  static const int supportUserId = 1000007;
  static const int projectUserId = 1000006;

  static bool get isAdmin => Token.roleUU == adminUuid || Token.rol == adminId;
  static bool get isSupport => Token.roleUU == supportUserUuid || Token.rol == supportUserId;
  static bool get isProject => Token.roleUU == projectUserUuid || Token.rol == projectUserId;

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
