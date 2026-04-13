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

  static Future<void> syncData({bool force = false, void Function(String message, double progress)? onProgress}) async {
    if (isDataLoaded && !force) return;

    try {
      String? requestFilter;
      if (!AccessControl.isAdmin && User.cBPartnerID != null) {
        requestFilter = "C_BPartner_ID eq ${User.cBPartnerID}";
      }

      int totalTasks = 6;
      int completedTasks = 0;

      void completeTask(String msg) {
        completedTasks++;
        onProgress?.call(msg, completedTasks / totalTasks);
      }

      onProgress?.call("Iniciando sincronización...", 0.05);

      final futures = await Future.wait([
        ProjectsLogic().fetchProjects(isViewingMine: false).then((v) {
          completeTask("Cargando proyectos...");
          return v;
        }),
        fetchRequest(filter: requestFilter, expand: "R_Status_ID(\$select=Name,IsOpen),R_Group_ID(\$select=Name),R_RequestType_ID(\$select=Name),R_Category_ID(\$select=Name)").then((v) {
          completeTask("Preparando solicitudes...");
          return v;
        }),
        fetchStatuses().then((v) {
          completeTask("Sincronizando estados...");
          return v;
        }),
        (AccessControl.isAdmin ? ContractApi.getBPartnersWithSupportContracts() : Future.value(<Map<String, dynamic>>[])).then((v) {
          completeTask("Identificando terceros...");
          return v;
        }),
        ContractApi.getSupportContracts().then((v) {
          completeTask("Ajustando contratos y cards...");
          return v;
        }),
        (AccessControl.isAdmin ? ProjectsLogic().fetchUsers() : Future.value(<dynamic>[])).then((v) {
          completeTask("Generando entorno de trabajo...");
          return v;
        }),
      ]);

      projects = futures[0] as List<dynamic>;
      requests = futures[1] as List<Map<String, dynamic>>;
      statuses = futures[2] as Map<String, int>;
      bPartners = futures[3] as List<Map<String, dynamic>>;
      contracts = futures[4] as List<Map<String, dynamic>>;
      users = futures[5] as List<dynamic>;

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
