import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:primhub/api/contract_api.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';

class GlobalCache {
  static List<dynamic> projects = [];
  static List<Map<String, dynamic>> requests = [];
  static List<Map<String, dynamic>> _rawBPartners = [];
  static List<Map<String, dynamic>> get allBPartners => _rawBPartners;
  static List<Map<String, dynamic>> bPartners = [];
  static List<Map<String, dynamic>> contracts = [];
  static List<dynamic> users = [];
  static Map<String, int> statuses = {};

  static bool isDataLoaded = false;
  static bool isFullyLoaded = false;
  static final ValueNotifier<bool> backgroundSyncNotifier = ValueNotifier(false);

  // Funciones granulares para carga en cascada/paralelo en el Home
  static Future<void> loadBaseData() async {
    final futures = await Future.wait([
      fetchStatuses(),
      // ¡CAMBIO CLAVE! Usamos ProjectsLogic() igual que en Create y Edit
      (AccessControl.isAdmin ? ProjectsLogic().fetchBPartners() : Future.value(<dynamic>[])),
      (AccessControl.isAdmin ? ProjectsLogic().fetchUsers() : Future.value(<dynamic>[])),
    ]);

    statuses = futures[0] as Map<String, int>;

    // APLICAMOS EL FILTRO DIRECTAMENTE EN LA CACHÉ GLOBAL
    _rawBPartners = (futures[1] as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    bPartners = _rawBPartners.where((bp) {
      final name = bp['Name']?.toString() ?? '';
      final isCustomer = bp['IsCustomer'] == true || bp['IsCustomer'] == 'Y' || bp['isCustomer'] == true || bp['isCustomer'] == 'Y';
      return !name.startsWith('~') && isCustomer;
    }).toList();

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

    final expand = "R_Status_ID(\$select=Name,IsOpen),R_Group_ID(\$select=Name),R_RequestType_ID(\$select=Name),R_Category_ID(\$select=Name)";

    // Fase 1: Carga RÁPIDA. Filtramos específicamente los estados activos usando el diccionario de estados,
    // evitando el operador 'ne' que falla en el servidor de iDempiere.
    List<int> activeStatusIds = [];
    statuses.forEach((name, id) {
      final n = name.toLowerCase();
      if (id != 1000019 && id != 103 && !n.contains('archivada') && !n.contains('close') && !n.contains('cerrad')) {
        activeStatusIds.add(id);
      }
    });

    String phase1Filter = requestFilter ?? "";
    if (activeStatusIds.isNotEmpty) {
      final statusCondition = "(${activeStatusIds.map((id) => "R_Status_ID eq $id").join(" or ")})";
      phase1Filter = phase1Filter.isNotEmpty ? "($phase1Filter) and $statusCondition" : statusCondition;
    }

    final activeFuture = fetchRequest(filter: phase1Filter.isNotEmpty ? phase1Filter : requestFilter, expand: expand, orderBy: 'Updated desc');

    _loadAllRequestsInBackground(requestFilter, expand, activeFuture);

    // Esperamos únicamente las activas para desbloquear la UI instantáneamente
    requests = await activeFuture;
  }

  static Future<void> _loadAllRequestsInBackground(String? requestFilter, String expand, Future<List<Map<String, dynamic>>> activeFuture) async {
    backgroundSyncNotifier.value = true;
    try {
      // Fase 2: Carga PESADA. Traemos absolutamente todo el historial paginado.
      final allRequests = await fetchRequest(filter: requestFilter, expand: expand, orderBy: 'Updated desc');

      // Aseguramos que la carga activa haya terminado de poblar la caché base antes de añadir las archivadas
      await activeFuture;

      // Reemplazamos con la data completa
      requests = allRequests;

      isFullyLoaded = true;
    } catch (e) {
      debugPrint("Error cargando el historial completo de solicitudes: $e");
    } finally {
      backgroundSyncNotifier.value = false;
    }
  }

  static Future<bool> checkIfSyncNeeded() async {
    if (!isDataLoaded) return true;
    try {
      String? reqFilter;
      if (!AccessControl.isAdmin && User.cBPartnerID != null) {
        reqFilter = "C_BPartner_ID eq ${User.cBPartnerID}";
      }
      final reqUri = Uri.parse('${Endpoint.request}?\$top=1&\$orderby=Updated desc${reqFilter != null ? '&\$filter=$reqFilter' : ''}');
      final resReq = await http.get(reqUri, headers: {'Authorization': Token.token, 'Content-Type': 'application/json'});

      if (resReq.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resReq.bodyBytes));
        final records = data['records'] as List?;
        if (records != null && records.isNotEmpty) {
          final latestRemoteUpdated = records[0]['Updated'];
          String? latestLocalUpdated;
          for (var r in requests) {
            if (r['Updated'] != null) {
              if (latestLocalUpdated == null || r['Updated'].compareTo(latestLocalUpdated) > 0) {
                latestLocalUpdated = r['Updated'];
              }
            }
          }
          if (latestLocalUpdated != null && latestRemoteUpdated != null) {
            if (latestRemoteUpdated.compareTo(latestLocalUpdated) > 0) return true;
          } else if (latestRemoteUpdated != null && latestLocalUpdated == null) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      return true;
    }
  }

  static Future<void> performSmartSync(BuildContext context, Future<void> Function() onSyncAction) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verificando si hay información nueva...'), duration: Duration(milliseconds: 1500)));
    bool needsSync = await checkIfSyncNeeded();
    if (needsSync) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Recargando y Sincronizando'), backgroundColor: Theme.of(context).colorScheme.primary));
      }
      await onSyncAction();
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Todo está Sincronizado Correctamente'), backgroundColor: Colors.green));
      }
    }
  }

  static Future<void> syncData({bool force = false, void Function(String message, double progress)? onProgress}) async {
    if (isDataLoaded && !force) return;
    isDataLoaded = false;
    isFullyLoaded = false;

    try {
      onProgress?.call("Iniciando sincronización...", 0.1);

      // Cargar diccionarios base primero para poder armar filtros inteligentes
      await loadBaseData();

      await Future.wait([loadProjectsData(), loadSupportData(), loadRequestsData()]);

      isDataLoaded = true;
      debugPrint("✅ Caché Global Sincronizada: ${requests.length} solicitudes, ${projects.length} proyectos.");
    } catch (e) {
      debugPrint("❌ Error sincronizando caché global: $e");
    }
  }

  static void clear() {
    projects = [];
    requests = [];
    _rawBPartners = [];
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
