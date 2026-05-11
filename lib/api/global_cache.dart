import 'dart:convert';
import 'dart:async';
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
  // --- Estado de la Caché ---
  static List<dynamic> projects = [];
  static List<Map<String, dynamic>> requests = [];
  static List<Map<String, dynamic>> _rawBPartners = [];
  static List<Map<String, dynamic>> get allBPartners => _rawBPartners;
  static List<Map<String, dynamic>> bPartners = [];
  static List<Map<String, dynamic>> contracts = [];
  static List<dynamic> users = [];
  static Map<String, int> statuses = {};
  static List<Map<String, dynamic>> salesReps = [];

  static bool isDataLoaded = false;
  static bool isFullyLoaded = false;

  static final ValueNotifier<bool> backgroundSyncNotifier = ValueNotifier(false);
  static final Set<int> _archivedYearsLoaded = {};
  static Completer<void>? _phase2Completer;
  static Future<void>? get phase2SyncFuture => _phase2Completer?.future;

  // --- FASE 1: Carga de datos esenciales (Bloqueante para el Home) ---
  static Future<void> _loadPhase1_EssentialData() async {
    debugPrint("CACHE: Iniciando Fase 1 - Datos esenciales para el Home.");

    final futures = await Future.wait([fetchStatuses(), ProjectsLogic().fetchBPartners(), ProjectsLogic().fetchUsers(), ProjectsLogic().fetchProjects(isViewingMine: false, showInactive: true), ContractApi.getSupportContracts()]);

    statuses = futures[0] as Map<String, int>;
    _rawBPartners = (futures[1] as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    // Filtrar Terceros
    bPartners = _rawBPartners.where((bp) => !(bp['Name']?.toString().startsWith('~') ?? false)).toList();
    users = futures[2] as List<dynamic>;

    // Mapeo de Representantes Comerciales
    salesReps = _rawBPartners.where((bp) => (bp['IsSalesRep'] == true || bp['IsSalesRep'] == 'Y')).toList();

    projects = futures[3] as List<dynamic>;
    contracts = futures[4] as List<Map<String, dynamic>>;

    // 5 Solicitudes más recientes para el Home
    String? initialFilter;
    if (!AccessControl.isAdmin && User.cBPartnerID != null) {
      initialFilter = "C_BPartner_ID eq ${User.cBPartnerID}";
    }

    final initialRequests = await fetchRequest(filter: initialFilter, top: 5, orderBy: 'Updated desc', expand: 'C_Order_ID(\$select=DocumentNo)');

    requests = List<Map<String, dynamic>>.from(initialRequests);
    debugPrint("CACHE: Fase 1 completada. ${requests.length} solicitudes iniciales.");
  }

  // --- FASES 2 y 3: Carga en segundo plano ---
  static Future<void> _loadPhases2and3_RequestHistory() async {
    try {
      // Retraso de cortesía para no saturar el login
      await Future.delayed(const Duration(seconds: 5));
      backgroundSyncNotifier.value = true;

      final currentYear = DateTime.now().year;
      String? userFilter;
      if (!AccessControl.isAdmin && User.cBPartnerID != null) {
        userFilter = "C_BPartner_ID eq ${User.cBPartnerID}";
      }

      // --- FASE 2a: Carga Agresiva de Proyectos ---
      debugPrint("CACHE: Iniciando Fase 2 - Buscando solicitudes de proyectos activos.");
      List<Map<String, dynamic>> projectRequests = await _loadProjectRequests(userFilter);
      debugPrint("CACHE: Se encontraron ${projectRequests.length} solicitudes vinculadas a proyectos.");

      // --- FASE 2b: Soporte Año Actual ---
      String supportFilter = "(Created ge '$currentYear-01-01 00:00:00' and Created lt '${currentYear + 1}-01-01 00:00:00')";
      if (userFilter != null) supportFilter = "($userFilter) and $supportFilter";

      final currentYearSupport = await fetchRequest(filter: supportFilter, expand: 'C_Order_ID(\$select=DocumentNo)');

      // Unificar eliminando duplicados mediante un Mapa (ID -> Data)
      final Map<String, Map<String, dynamic>> masterMap = {};

      // 1. Meter las de proyecto (tienen prioridad de data)
      for (var r in projectRequests) {
        masterMap[r['id'].toString()] = r;
      }
      // 2. Meter las actuales de soporte e iniciales
      for (var r in requests) {
        masterMap[r['id'].toString()] = r;
      }
      for (var r in currentYearSupport) {
        masterMap[r['id'].toString()] = r;
      }

      requests = masterMap.values.toList();
      debugPrint("CACHE: Fase 2 completada. Total en Cache: ${requests.length}");

      if (!(_phase2Completer?.isCompleted ?? true)) _phase2Completer?.complete();
      backgroundSyncNotifier.value = false; // Notificar actualización a la UI

      // --- FASE 3: Historial años anteriores (No archivadas) ---
      await _loadPhase3_History(userFilter, currentYear);
    } catch (e) {
      debugPrint("❌ Error en segundo plano (Fase 2/3): $e");
      if (!(_phase2Completer?.isCompleted ?? true)) _phase2Completer?.completeError(e);
    } finally {
      backgroundSyncNotifier.value = false;
    }
  }

  /// Fase 3: Historial de soporte (Años anteriores)
  static Future<void> _loadPhase3_History(String? userFilter, int currentYear) async {
    debugPrint("CACHE: Iniciando Fase 3 - Historial Soporte.");
    final archivedId = statuses.entries.firstWhere((e) => e.key.toLowerCase().contains('archivada'), orElse: () => const MapEntry('', 0)).value;

    String filter = "Created lt '$currentYear-01-01 00:00:00'";
    if (archivedId > 0) filter += " and R_Status_ID ne $archivedId";
    if (userFilter != null) filter = "($userFilter) and $filter";

    final historyRequests = await fetchRequest(filter: filter, expand: 'C_Order_ID(\$select=DocumentNo)');

    final Map<String, Map<String, dynamic>> masterMap = {for (var r in requests) r['id'].toString(): r};
    for (var r in historyRequests) {
      masterMap[r['id'].toString()] = r;
    }

    requests = masterMap.values.toList();
    isFullyLoaded = true;
    debugPrint("CACHE: Fase 3 finalizada. Total final: ${requests.length}");
  }

  /// Función especializada para traer solicitudes de proyectos
  static Future<List<Map<String, dynamic>>> _loadProjectRequests(String? userFilter) async {
    List<Future<List<Map<String, dynamic>>>> futures = [];

    // Iteramos sobre los proyectos ya cacheados en la Fase 1
    for (var project in projects) {
      final projectId = project['id'];
      if (projectId != null) {
        // No aplicamos el userFilter aquí, ya que el acceso a proyectos se maneja de otra forma.
        // La función fetchProjectAndTaskRequests ya es suficientemente específica.
        futures.add(fetchProjectAndTaskRequests(projectId, expand: 'C_Order_ID(\$select=DocumentNo)'));
      }
    }

    if (futures.isEmpty) return [];

    final List<Map<String, dynamic>> allResults = [];
    final results = await Future.wait(futures);
    for (var res in results) {
      allResults.addAll(res);
    }

    // Deduplicación final por si acaso
    final uniqueMap = <int, Map<String, dynamic>>{};
    for (var req in allResults) {
      if (req['id'] != null) uniqueMap[req['id']] = req;
    }
    return uniqueMap.values.toList();
  }

  // --- FASE 4: Carga bajo demanda de Archivadas (Dashboard / Bitácora) ---
  static Future<void> loadArchivedRequests() async {
    final currentYear = DateTime.now().year;
    if (!isDataLoaded || _archivedYearsLoaded.contains(currentYear)) return;

    backgroundSyncNotifier.value = true;
    try {
      final archivedId = statuses.entries.firstWhere((e) => e.key.toLowerCase().contains('archivada'), orElse: () => const MapEntry('', 0)).value;

      if (archivedId == 0) return;

      String filter = "R_Status_ID eq $archivedId and Created ge '$currentYear-01-01 00:00:00'";
      if (!AccessControl.isAdmin && User.cBPartnerID != null) {
        filter = "(C_BPartner_ID eq ${User.cBPartnerID}) and $filter";
      }

      final archived = await fetchRequest(filter: filter, expand: 'C_Order_ID(\$select=DocumentNo)');

      final Map<String, Map<String, dynamic>> masterMap = {for (var r in requests) r['id'].toString(): r};
      for (var r in archived) {
        masterMap[r['id'].toString()] = r;
      }
      requests = masterMap.values.toList();
      _archivedYearsLoaded.add(currentYear);
    } finally {
      backgroundSyncNotifier.value = false;
    }
  }

  // --- FASE 5: Carga por años específicos (Modal) ---
  static Future<void> fetchRequestsForYears(List<int> years) async {
    if (years.isEmpty) return;
    backgroundSyncNotifier.value = true;
    try {
      final yearFilterStr = years.map((y) => "(Created ge '$y-01-01 00:00:00' and Created lt '${y + 1}-01-01 00:00:00')").join(' or ');
      String finalFilter = "($yearFilterStr)";

      if (!AccessControl.isAdmin && User.cBPartnerID != null) {
        finalFilter = "(C_BPartner_ID eq ${User.cBPartnerID}) and $finalFilter";
      }

      final newReqs = await fetchRequest(filter: finalFilter, expand: 'C_Order_ID(\$select=DocumentNo)');

      final Map<String, Map<String, dynamic>> masterMap = {for (var r in requests) r['id'].toString(): r};
      for (var r in newReqs) {
        masterMap[r['id'].toString()] = r;
      }
      requests = masterMap.values.toList();
    } finally {
      backgroundSyncNotifier.value = false;
    }
  }

  // --- Orquestador Principal ---
  static Future<void> syncData({bool force = false}) async {
    if (isDataLoaded && !force) return;
    isDataLoaded = false;
    isFullyLoaded = false;
    _phase2Completer = Completer<void>();
    try {
      await _loadPhase1_EssentialData();
      isDataLoaded = true;
      _loadPhases2and3_RequestHistory(); // Corre en paralelo
    } catch (e) {
      if (!(_phase2Completer?.isCompleted ?? true)) _phase2Completer?.completeError(e);
      isDataLoaded = true;
    }
  }

  // --- Utilidades de Gestión ---

  static void clear() {
    projects.clear();
    requests.clear();
    _rawBPartners.clear();
    bPartners.clear();
    contracts.clear();
    users.clear();
    salesReps.clear();
    statuses.clear();
    isDataLoaded = false;
    isFullyLoaded = false;
    _archivedYearsLoaded.clear();
  }

  static Future<void> syncSingleRequest(int requestId) async {
    try {
      const expand = "R_Status_ID(\$select=Name,IsOpen),R_Group_ID(\$select=Name),R_RequestType_ID(\$select=Name),R_Category_ID(\$select=Name),C_Order_ID(\$select=DocumentNo)";
      final freshData = await fetchRequest(filter: "R_Request_ID eq $requestId", expand: expand);
      if (freshData.isNotEmpty) {
        final newReq = freshData.first;
        final index = requests.indexWhere((r) => r['id'].toString() == requestId.toString());
        if (index != -1) {
          requests[index] = newReq;
        } else {
          requests.insert(0, newReq);
        }
      }
    } catch (e) {
      debugPrint("Error sync single: $e");
    }
  }

  static void removeRequest(int requestId) {
    requests.removeWhere((r) => r['id'].toString() == requestId.toString());
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
          final remoteUpdate = records[0]['Updated'];
          String? localUpdate;
          for (var r in requests) {
            if (r['Updated'] != null) {
              if (localUpdate == null || r['Updated'].compareTo(localUpdate) > 0) {
                localUpdate = r['Updated'];
              }
            }
          }
          if (localUpdate != null && remoteUpdate != null) {
            return remoteUpdate.compareTo(localUpdate) > 0;
          }
          return true;
        }
      }
      return false;
    } catch (e) {
      return true;
    }
  }

  static Future<void> performSmartSync(BuildContext context, Future<void> Function() onSyncAction) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verificando información nueva...'), duration: Duration(milliseconds: 1500)));
    if (await checkIfSyncNeeded()) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Sincronizando...'), backgroundColor: Theme.of(context).colorScheme.primary));
      await onSyncAction();
    } else {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sincronizado'), backgroundColor: Colors.green));
    }
  }
}
