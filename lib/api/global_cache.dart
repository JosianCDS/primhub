import 'package:flutter/foundation.dart';
import 'package:primhub/api/contract_api.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';

class GlobalCache {
  static List<dynamic> projects = [];
  static List<Map<String, dynamic>> requests = [];
  static List<Map<String, dynamic>> bPartners = [];
  static List<Map<String, dynamic>> contracts = [];
  static List<dynamic> users = [];
  static Map<String, int> statuses = {};

  static bool isDataLoaded = false;
  static bool isFullyLoaded = false;
  static final ValueNotifier<bool> backgroundSyncNotifier = ValueNotifier(false);

  // Funciones granulares para carga en cascada/paralelo en el Home
  static Future<void> loadBaseData() async {
    final futures = await Future.wait([fetchStatuses(), (AccessControl.isAdmin ? ContractApi.getBPartnersWithSupportContracts() : Future.value(<Map<String, dynamic>>[])), (AccessControl.isAdmin ? ProjectsLogic().fetchUsers() : Future.value(<dynamic>[]))]);
    statuses = futures[0] as Map<String, int>;
    bPartners = futures[1] as List<Map<String, dynamic>>;
    users = futures[2] as List<dynamic>;
  }

  static Future<void> loadProjectsData() async {
    projects = await ProjectsLogic().fetchProjects(isViewingMine: false);
  }

  static Future<void> loadSupportData() async {
    contracts = await ContractApi.getSupportContracts();
  }

  static Future<void> loadRequestsData() async {
    String? requestFilter;
    if (!AccessControl.isAdmin && User.cBPartnerID != null) {
      requestFilter = "C_BPartner_ID eq ${User.cBPartnerID}";
    }
    // Fase 1: Cargar solo las primeras 100 solicitudes (Una sola petición ultra rápida)
    requests = await fetchRequest(filter: requestFilter, top: 100, expand: "R_Status_ID(\$select=Name,IsOpen),R_Group_ID(\$select=Name),R_RequestType_ID(\$select=Name),R_Category_ID(\$select=Name)");

    // Fase 2: Cargar el historial restante en background
    _loadRemainingRequestsInBackground(requestFilter);
  }

  static Future<void> _loadRemainingRequestsInBackground(String? requestFilter) async {
    backgroundSyncNotifier.value = true;
    try {
      final remaining = await fetchRequest(filter: requestFilter, initialSkip: 100, expand: "R_Status_ID(\$select=Name,IsOpen),R_Group_ID(\$select=Name),R_RequestType_ID(\$select=Name),R_Category_ID(\$select=Name)");
      if (remaining.isNotEmpty) {
        requests.addAll(remaining);
      }
      isFullyLoaded = true;
    } catch (e) {
      debugPrint("Error cargando resto de solicitudes: $e");
    } finally {
      backgroundSyncNotifier.value = false;
    }
  }

  static Future<void> syncData({bool force = false, void Function(String message, double progress)? onProgress}) async {
    if (isDataLoaded && !force) return;
    isDataLoaded = false;
    isFullyLoaded = false;

    try {
      onProgress?.call("Iniciando sincronización...", 0.1);

      final futures = await Future.wait([loadBaseData(), loadProjectsData(), loadSupportData(), loadRequestsData()]);

      isDataLoaded = true;
      debugPrint("✅ Caché Global Sincronizada: ${requests.length} solicitudes, ${projects.length} proyectos.");
    } catch (e) {
      debugPrint("❌ Error sincronizando caché global: $e");
    }
  }

  static void clear() {
    projects = [];
    requests = [];
    bPartners = [];
    contracts = [];
    users = [];
    statuses = {};
    isDataLoaded = false;
    isFullyLoaded = false;
  }

  static Future<void> syncSingleRequest(int requestId) async {
    try {
      final expand = "R_Status_ID(\$select=Name,IsOpen),R_Group_ID(\$select=Name),R_RequestType_ID(\$select=Name),R_Category_ID(\$select=Name)";
      final freshData = await fetchRequest(filter: "R_Request_ID eq $requestId", expand: expand);
      if (freshData.isNotEmpty) {
        final newReq = freshData.first;
        final index = requests.indexWhere((r) => r['id'].toString() == requestId.toString());
        if (index != -1) {
          requests[index] = newReq;
        } else {
          requests.insert(0, newReq); // Si es nueva, la insertamos al inicio
        }
      }
    } catch (e) {
      debugPrint("Error sincronizando solicitud individual: $e");
    }
  }

  static void removeRequest(int requestId) {
    requests.removeWhere((r) => r['id'].toString() == requestId.toString());
  }
}
