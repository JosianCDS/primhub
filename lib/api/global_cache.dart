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
  static List<Map<String, dynamic>> productChips = [];
  static List<dynamic> users = [];
  static Map<String, int> statuses = {};
  static Map<int, bool> statusIsClosedMap = {};
  static List<Map<String, dynamic>> salesReps = [];
  static Map<String, int> requestTypes = {};
  static Map<String, int> categories = {};
  static Map<String, int> groups = {};
  
  // Caché de solicitudes por proyecto para carga "mixta"
  static Map<int, List<Map<String, dynamic>>> projectRequestsCache = {};
  static Map<int, bool> projectLoadingStatus = {};

  static bool isDataLoaded = false;
  static bool isFullyLoaded = false;

  static final ValueNotifier<bool> backgroundSyncNotifier = ValueNotifier(
    false,
  );
  static final Set<int> _archivedYearsLoaded = {};
  static Completer<void>? _phase2Completer;
  static Future<void>? get phase2SyncFuture => _phase2Completer?.future;

  // --- FASE 1: Carga de datos esenciales (Bloqueante para el Home) ---
  static Future<void> _loadPhase1_EssentialData() async {
    debugPrint("CACHE: Iniciando Fase 1 - Datos esenciales para el Home.");

    final List<dynamic> futures;
    try {
      futures = await Future.wait([
        fetchStatusesWithMetadata(),
        ProjectsLogic().fetchBPartners(),
        ProjectsLogic().fetchUsers(),
        ProjectsLogic().fetchProjects(isViewingMine: false, showInactive: true),
        ContractApi.getSupportProductChips(),
        fetchRequestTypes(),
        fetchCategories(),
        fetchGroups(),
      ]);
    } catch (e, stack) {
      debugPrint("DEBUG CACHE ERROR: Error en Future.wait de Fase 1: $e");
      debugPrint(stack.toString());
      rethrow;
    }

    final statusData = futures[0] as Map<String, dynamic>;
    debugPrint("DEBUG CACHE: Future.wait terminó. Iniciando procesamiento de ${futures.length} respuestas.");
    statuses = statusData['nameToId'] as Map<String, int>;
    statusIsClosedMap = statusData['idToIsClosed'] as Map<int, bool>;

    _rawBPartners = (futures[1] as List<dynamic>)
        .map((e) {
          if (e is! Map) return <String, dynamic>{};
          return Map<String, dynamic>.from(e);
        })
        .where((e) => e.isNotEmpty)
        .toList();
    
    debugPrint("DEBUG CACHE: Recibidos ${_rawBPartners.length} Terceros raw.");

    // Filtrar Terceros: Nos enfocamos en IsCustomer == 'true' o 'Y'
    bPartners = _rawBPartners.where((bp) {
      final name = (bp['Name']?.toString() ?? '').trim();
      if (name.startsWith('~')) return false;

      final rawVendor = bp['IsVendor'] ?? bp['isVendor'];
      final isVendorStr = rawVendor?.toString().trim().toLowerCase();
      bool isVendor = isVendorStr == 'true' || isVendorStr == 'y';

      final rawCustomer = bp['IsCustomer'] ?? bp['isCustomer'];
      final isCustomerStr = rawCustomer?.toString().trim().toLowerCase();
      bool isCustomer = isCustomerStr == 'true' || isCustomerStr == 'y';
      if (rawCustomer == null) isCustomer = true; 

      // Filtro IDÉNTICO al diálogo de creación
      return isCustomer && !isVendor;
    }).toList();
    
    debugPrint("CACHE: Phase 1 BPartners Filtered: ${bPartners.length}");

    final rawUsers = futures[2] as List<dynamic>;
    debugPrint("CACHE: Recibidos ${rawUsers.length} Usuarios raw.");
    
    final allProcessedUsers = rawUsers.map((u) {
      if (u is! Map) return <String, dynamic>{};
      final user = Map<String, dynamic>.from(u);
      user['Name'] = (user['Name']?.toString() ?? '').trim();
      return user;
    }).where((u) => u.isNotEmpty).toList();

    final customerBpIds = bPartners.map((bp) => bp['id'] as int).toSet();
    users = allProcessedUsers.where((u) {
      final uBpData = u['C_BPartner_ID'];
      final uBpId = (uBpData is Map)
          ? (uBpData['id'] as num?)?.toInt()
          : (uBpData is num ? uBpData.toInt() : null);
      return uBpId != null && customerBpIds.contains(uBpId);
    }).toList();
    
    debugPrint("CACHE: Phase 1 Users Filtered (Customers Only): ${users.length}");

    // Mapeo de Representantes Comerciales
    // 1. Encontrar los IDs de los terceros que son representantes de ventas.
    final repBPartnerIds = _rawBPartners
        .where((bp) {
          final rawIsRep = bp['IsSalesRep'] ?? bp['isSalesRep'];
          final isRepStr = rawIsRep?.toString().trim().toLowerCase();
          return isRepStr == 'true' || isRepStr == 'y';
        })
        .map((bp) => bp['id'] as int?)
        .where((id) => id != null)
        .toSet();

    // 2. Filtrar la lista de todos los usuarios para encontrar representantes
    salesReps = allProcessedUsers
        .where((user) {
          final userBpData = user['C_BPartner_ID'];
          final userBpId = (userBpData is Map)
              ? (userBpData['id'] as num?)?.toInt()
              : (userBpData is num ? userBpData.toInt() : null);
          
          final rawIsRep = user['IsSalesRep'] ?? user['isSalesRep'];
          final isRepStr = rawIsRep?.toString().trim().toLowerCase();
          bool userIsRep = isRepStr == 'true' || isRepStr == 'y';
          return (userBpId != null && repBPartnerIds.contains(userBpId)) || userIsRep;
        })
        .map((user) => user as Map<String, dynamic>)
        .toList();

    // Si aún así la lista de representantes está vacía por falta de datos, usamos todos los usuarios como fallback temporal
    if (salesReps.isEmpty && users.isNotEmpty) {
      salesReps = List.from(users);
    }

    projects = futures[3] as List<dynamic>;
    productChips = futures[4] as List<Map<String, dynamic>>;
    requestTypes = futures[5] as Map<String, int>;
    categories = futures[6] as Map<String, int>;
    groups = futures[7] as Map<String, int>;

    // 5 Solicitudes más recientes para el Home
    String? initialFilter;
    if (!AccessControl.isAdmin && User.cBPartnerID != null) {
      initialFilter = "C_BPartner_ID eq ${User.cBPartnerID}";
    }

    final initialRequests = await fetchRequest(
      filter: initialFilter,
      top: 5,
      orderBy: 'Updated desc',
      expand: 'C_Order_ID(\$select=DocumentNo)',
    );

    requests = List<Map<String, dynamic>>.from(initialRequests);
    debugPrint(
      "CACHE: Fase 1 completada. ${requests.length} solicitudes iniciales.",
    );
  }

  static bool _isSyncing = false;
  static Completer<void>? _syncCompleter;

  /// Sincroniza los datos de la caché con el servidor.
  static Future<void> syncData({bool force = false}) async {
    if (isDataLoaded && !force) return;

    // Si ya hay una sincronización en curso, esperamos a que termine
    if (_isSyncing) {
      debugPrint("CACHE: Ya hay una sincronización en curso. Esperando...");
      await _syncCompleter?.future;
      return;
    }

    _isSyncing = true;
    _syncCompleter = Completer<void>();
    _phase2Completer = Completer<void>();
    
    try {
      // Limpiar datos si es forzado para asegurar frescura total
      if (force) clear();

      await _loadPhase1_EssentialData();
      
      // Lanzar Fase 2 (datos pesados/históricos) sin bloquear el flujo principal
      _loadPhase2_HistoricalData();
      
      isDataLoaded = true;
      if (!(_syncCompleter?.isCompleted ?? true)) _syncCompleter?.complete();
    } catch (e) {
      debugPrint("ERROR en GlobalCache.syncData: $e");
      if (!(_syncCompleter?.isCompleted ?? true)) _syncCompleter?.completeError(e);
      // Marcamos como cargado para no reintentar infinitamente si el error es persistente
      isDataLoaded = true;
    } finally {
      _isSyncing = false;
      _syncCompleter = null;
    }
  }

  static Future<void> _loadPhase2_HistoricalData() async {
    try {
      final currentYear = DateTime.now().year;
      // Cargar desde el año actual hasta 2 años atrás
      for (var year = currentYear; year >= currentYear - 2; year--) {
        // Para el año actual, siempre intentamos cargar (podría haber nuevas)
        // aunque para evitar duplicados exactos, fetchRequest debería ser inteligente o nosotros filtrar
        
        String filter = "Created ge '$year-01-01T00:00:00Z' and Created le '$year-12-31T23:59:59Z'";
        
        final yearReqs = await fetchRequest(
          filter: filter,
          expand: 'C_Order_ID(\$select=DocumentNo)',
        );
        
        if (yearReqs.isNotEmpty) {
          // Evitar duplicados con los 5 cargados en Fase 1
          final existingIds = requests.map((r) => r['id']).toSet();
          for (var r in yearReqs) {
            if (!existingIds.contains(r['id'])) {
              requests.add(Map<String, dynamic>.from(r));
            }
          }
          _archivedYearsLoaded.add(year);
          debugPrint("CACHE: Fase 2 - Procesadas ${yearReqs.length} solicitudes del año $year.");
        }
      }
      isFullyLoaded = true;
      if (!(_phase2Completer?.isCompleted ?? true)) _phase2Completer?.complete();
    } catch (e) {
      debugPrint("CACHE ERROR Fase 2: $e");
      if (!(_phase2Completer?.isCompleted ?? true)) _phase2Completer?.completeError(e);
    }
  }

  // --- Utilidades de Gestión ---

  static void clear() {
    projects.clear();
    requests.clear();
    _rawBPartners.clear();
    bPartners.clear();
    productChips.clear();
    users.clear();
    salesReps.clear();
    statuses.clear();
    requestTypes.clear();
    categories.clear();
    groups.clear();
    isDataLoaded = false;
    isFullyLoaded = false;
    _archivedYearsLoaded.clear();
  }

  static Future<void> syncSingleRequest(int requestId) async {
    try {
      const expand =
          "R_Status_ID(\$select=Name,IsOpen),R_Group_ID(\$select=Name),R_RequestType_ID(\$select=Name),R_Category_ID(\$select=Name),C_Order_ID(\$select=DocumentNo)";
      final freshData = await fetchRequest(
        filter: "R_Request_ID eq $requestId",
        expand: expand,
      );
      if (freshData.isNotEmpty) {
        final newReq = freshData.first;
        final index = requests.indexWhere(
          (r) => r['id'].toString() == requestId.toString(),
        );
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
      final reqUri = Uri.parse(
        '${Endpoint.request}?\$top=1&\$orderby=Updated desc${reqFilter != null ? '&\$filter=$reqFilter' : ''}',
      );
      final resReq = await http.get(
        reqUri,
        headers: {
          'Authorization': Token.token,
          'Content-Type': 'application/json',
        },
      );

      if (resReq.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resReq.bodyBytes));
        final records = data['records'] as List?;
        if (records != null && records.isNotEmpty) {
          final remoteUpdate = records[0]['Updated'];
          String? localUpdate;
          for (var r in requests) {
            if (r['Updated'] != null) {
              if (localUpdate == null ||
                  r['Updated'].compareTo(localUpdate) > 0) {
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

  static Future<void> performSmartSync(
    BuildContext context,
    Future<void> Function() onSyncAction,
  ) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verificando información nueva...'),
        duration: Duration(milliseconds: 1500),
      ),
    );
    if (await checkIfSyncNeeded()) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Sincronizando...'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      await onSyncAction();
    } else {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sincronizado'),
            backgroundColor: Colors.green,
          ),
        );
    }
  }
  /// Carga todas las solicitudes de un proyecto en segundo plano.
  static Future<void> loadProjectRequestsInBackground(
    int projectId, {
    List<String>? taskUUIDs,
    Function(List<Map<String, dynamic>>)? onUpdate,
  }) async {
    if (projectLoadingStatus[projectId] == true) return; // Ya cargando
    projectLoadingStatus[projectId] = true;

    try {
      debugPrint("CACHE: Iniciando carga en segundo plano para Proyecto $projectId");
      
      // Si no tenemos los UUIDs, los obtenemos primero
      final uuids = taskUUIDs ?? await ProjectsLogic().fetchProjectTaskUUIDs(projectId);
      
      // 1. Carga inicial rápida (Cabecera del proyecto)
      String baseFilter = "C_Project_ID eq $projectId";
      final headerReqs = await fetchRequest(
        filter: baseFilter, 
        expand: 'C_Order_ID(\$select=DocumentNo),R_Status_ID,R_RequestType_ID,R_Category_ID,Priority,C_ProjectPhase_ID,C_ProjectTask_ID'
      );
      
      _updateProjectCache(projectId, headerReqs);
      if (onUpdate != null) onUpdate(projectRequestsCache[projectId]!);

      // 2. Carga incremental por tareas (de a 10)
      if (uuids.isNotEmpty) {
        for (var i = 0; i < uuids.length; i += 10) {
          final chunk = uuids.sublist(i, i + 10 > uuids.length ? uuids.length : i + 10);
          String chunkFilter = chunk.map((u) => "Record_UU eq '$u'").join(' or ');
          
          final taskReqs = await fetchRequest(
            filter: "($chunkFilter)", 
            expand: 'C_Order_ID(\$select=DocumentNo),R_Status_ID,R_RequestType_ID,R_Category_ID,Priority,C_ProjectPhase_ID,C_ProjectTask_ID'
          );
          
          if (taskReqs.isNotEmpty) {
            _updateProjectCache(projectId, taskReqs);
            if (onUpdate != null) onUpdate(projectRequestsCache[projectId]!);
          }
          
          // Eliminada la pausa de 100ms para acelerar la carga en ráfaga.
        }
      }
      debugPrint("CACHE: Carga completada para Proyecto $projectId. Total: ${projectRequestsCache[projectId]?.length}");
    } catch (e) {
      debugPrint("CACHE: Error cargando proyecto $projectId: $e");
    } finally {
      projectLoadingStatus[projectId] = false;
    }
  }

  static void _updateProjectCache(int projectId, List<Map<String, dynamic>> newReqs) {
    final current = projectRequestsCache[projectId] ?? [];
    final Map<int, Map<String, dynamic>> map = {
      for (var r in current) r['id']: r
    };
    
    for (var r in newReqs) {
      if (r['id'] != null) map[r['id']] = r;
    }
    
    projectRequestsCache[projectId] = map.values.toList();
  }
}
