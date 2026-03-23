import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/contract_api.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeController extends ChangeNotifier {
  // State variables
  bool isLoading = true;
  bool validationLoading = true;

  // User info
  String username = '';
  int? cBPartnerID;
  String? partnerName;
  String? projectPartnerName;

  // Permissions/Flags
  bool hasSupport = false;
  bool hasProject = false;

  // Projects
  List<dynamic> projects = [];
  List<int> selectedProjectIds = [];
  Map<int, Map<String, dynamic>> projectStats = {};

  // Requests
  List<Map<String, dynamic>> recentRequests = [];
  List<dynamic> allRequests = [];
  Map<int, Map<String, int>> requestsStatsByBp = {};

  // Hours
  double consumedHours = 0.0;
  List<Map<String, dynamic>> supportContracts = [];

  // Project Filter
  int? filterSalesRepId = User.userID; // Por defecto "Mis Proyectos"

  // Admin Support Filter
  List<dynamic> supportBPartners = [];
  List<int> selectedSupportBpIds = [];
  // Static persistence (from original file)
  static List<int> savedSelectedProjectIds = [];
  static List<int> savedSelectedSupportBpIds = [];

  HomeController() {
    selectedProjectIds = List.from(savedSelectedProjectIds);
    selectedSupportBpIds = List.from(savedSelectedSupportBpIds);
    _loadCurrentUser();
  }

  void _loadCurrentUser() {
    try {
      final payload = Token.decodePayload(Token.token);
      username = payload['sub'] ?? '';
      notifyListeners();
    } catch (_) {}
  }

  Future<void> initData() async {
    validationLoading = true;
    notifyListeners();

    await loadValidationData();
    if (AccessControl.isAdmin) {
      await loadSupportBPartners();
    }
    await loadRecentRequests();
    await loadDocumentStats();
    await loadSupportContracts();

    validationLoading = false;
    notifyListeners();
  }

  Future<void> loadSupportBPartners() async {
    supportBPartners = await ContractApi.getBPartnersWithSupportContracts();
    if (selectedSupportBpIds.isEmpty && supportBPartners.isNotEmpty) {
      selectedSupportBpIds = supportBPartners.map<int>((bp) => bp['id'] as int).toList();
      savedSelectedSupportBpIds = List.from(selectedSupportBpIds);
    }
    notifyListeners();
  }

  Future<void> loadValidationData() async {
    validationLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final bool isAdmin = AccessControl.isAdmin;

    int? partnerID = User.cBPartnerID;
    String? pName;
    String? projPName;

    if (partnerID != null || isAdmin) {
      try {
        if (partnerID != null) {
          final pResponse = await http.get(Uri.parse('${Endpoint.cBPartner}?\$filter=C_BPartner_ID eq $partnerID'), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});
          if (pResponse.statusCode == 200) {
            final data = json.decode(utf8.decode(pResponse.bodyBytes));
            if (data['records'] != null && (data['records'] as List).isNotEmpty) {
              pName = data['records'][0]['Name'];
            }
          }
        }

        String projectUrl = Endpoint.project;
        List<String> filters = [];

        // Regla: Si es un usuario de proyecto real (no un admin en modo proyecto), filtra por su BPartner
        if (Token.primConfig?.toLowerCase() == 'py' && partnerID != null) {
          filters.add('C_BPartner_ID eq $partnerID');
        } else {
          // Para usuarios internos (Admin/Soporte), el filtro depende del botón "Mis Proyectos" / "Todos"
          if (filterSalesRepId != null) {
            filters.add('SalesRep_ID eq $filterSalesRepId');
          }
        }

        if (filters.isNotEmpty) {
          projectUrl += '?\$filter=${filters.join(' and ')}';
        }

        final projResponse = await http.get(Uri.parse(projectUrl), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});
        if (projResponse.statusCode == 200) {
          final data = json.decode(utf8.decode(projResponse.bodyBytes));
          if (data['records'] != null && (data['records'] as List).isNotEmpty) {
            projPName = data['records'][0]['C_BPartner_ID']?['identifier'];
            projects = data['records'];

            if (selectedProjectIds.isEmpty) {
              selectedProjectIds = projects.map<int>((p) => p['id'] as int).toList();
              savedSelectedProjectIds = List.from(selectedProjectIds);
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching validation names: ');
      }
    }

    // hasSupport es ahora determinado dinámicamente por loadContractedHours
    hasProject = projects.isNotEmpty;
    cBPartnerID = partnerID;
    partnerName = pName;
    projectPartnerName = projPName;
    validationLoading = false;
    notifyListeners();
  }

  Future<void> loadRecentRequests() async {
    List<Map<String, dynamic>> allBPartnerRequests = [];
    List<int>? bpIdsForQuery;

    if (AccessControl.isAdmin) {
      bpIdsForQuery = selectedSupportBpIds;
    } else {
      if (User.cBPartnerID != null) {
        bpIdsForQuery = [User.cBPartnerID!];
      }
    }

    if (bpIdsForQuery != null && bpIdsForQuery.isNotEmpty) {
      // Hacemos una consulta por cada tercero seleccionado para asegurar que el filtro se aplique correctamente
      // y luego combinamos los resultados.
      for (final bpId in bpIdsForQuery) {
        final requestsForBp = await fetchRequest(filter: "C_BPartner_ID eq $bpId");
        allBPartnerRequests.addAll(requestsForBp);
      }
    } else if (AccessControl.isAdmin && (bpIdsForQuery == null || bpIdsForQuery.isEmpty)) {
      // Si el admin no ha seleccionado a nadie, la lista de solicitudes estará vacía.
      allBPartnerRequests = [];
    }

    int open = 0; // Unused for now
    int inProgress = 0;
    int closed = 0;
    double totalConsumed = 0.0;

    for (var req in allBPartnerRequests) {
      // Condición del usuario: Solo contar para soporte si NO está asociada a un proyecto.
      final recordUU = req['Record_UU'];
      if (recordUU != null && recordUU.toString().isNotEmpty) {
        continue; // Saltar esta solicitud, es de proyecto.
      }

      final statusId = req['R_Status_ID'] is Map ? req['R_Status_ID']['id'] : req['R_Status_ID'];
      if (statusId == 103 || req['R_Status_Name'] == '9_Final Close') {
        double hours = (req['QtyPlan'] as num?)?.toDouble() ?? 0.0;
        totalConsumed += hours;
        closed++;
      } else {
        inProgress++;
      }
    }

    // Filter for the "Recent Requests" table (non-closed, non-project-linked)
    final nonClosedRequests = allBPartnerRequests.where((r) {
      final statusId = r['R_Status_ID'] is Map ? r['R_Status_ID']['id'] : r['R_Status_ID'];
      final recordUU = r['Record_UU'];
      return (statusId != 103 && r['R_Status_Name'] != '9_Final Close') && (recordUU == null || recordUU.toString().isEmpty);
    }).toList();

    nonClosedRequests.sort((a, b) {
      final dateA = DateTime.tryParse(a['Created'] ?? '') ?? DateTime(0);
      final dateB = DateTime.tryParse(b['Created'] ?? '') ?? DateTime(0);
      return dateB.compareTo(dateA);
    });

    consumedHours = totalConsumed;
    allRequests = nonClosedRequests;

    _applyFilters();
    isLoading = false;
    notifyListeners();
  }

  void _applyFilters() {
    var filtered = List<dynamic>.from(allRequests);
    recentRequests = filtered.take(5).map((r) {
      String level = r['Priority_Name'] ?? 'Baja';
      Color baseColor = Colors.green;
      if (level == 'Urgente')
        baseColor = Colors.purple;
      else if (level == 'Alta')
        baseColor = Colors.red;
      else if (level == 'Media')
        baseColor = Colors.amber.shade800;
      else if (level == 'Menor')
        baseColor = Colors.grey;

      String formattedTime = r['Created'] ?? '';
      try {
        if (formattedTime.isNotEmpty) {
          final DateTime date = DateTime.parse(formattedTime).toLocal();
          formattedTime = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
        }
      } catch (_) {}

      return {
        'code': r['DocumentNo'] ?? r['id'].toString(),
        'situation': r['R_RequestType_Name'] ?? 'Solicitud',
        'description': r['Summary'] ?? '',
        'time': formattedTime,
        'level': level,
        'levelColor': baseColor,
        'levelBgColor': baseColor.withOpacity(0.2),
        'status': r['R_Status_Name'] ?? '1_Open',
        'bpName': r['C_BPartner_Name'] ?? '',
        'userName': r['AD_User_Name'] ?? '',
        'original': r, // Keep original for editing
      };
    }).toList();
  }

  Future<void> loadSupportContracts() async {
    List<int>? bpIdsForQuery;

    if (AccessControl.isAdmin) {
      bpIdsForQuery = selectedSupportBpIds;
      if (bpIdsForQuery.isEmpty) {
        supportContracts = [];
        hasSupport = false;
        notifyListeners();
        return;
      }
    } else {
      if (User.cBPartnerID != null) {
        bpIdsForQuery = [User.cBPartnerID!];
      }
    }

    final allContracts = await ContractApi.getSupportContracts(bPartnerIds: bpIdsForQuery);

    // Distribuir el consumo total (calculado en loadRecentRequests) entre los contratos
    double remainingConsumed = consumedHours;

    for (var contract in allContracts) {
      double contracted = contract['contractedHours'] ?? 0.0;
      if (remainingConsumed > 0) {
        if (remainingConsumed >= contracted) {
          contract['consumedHours'] = contracted;
          remainingConsumed -= contracted;
        } else {
          contract['consumedHours'] = remainingConsumed;
          remainingConsumed = 0;
        }
      } else {
        contract['consumedHours'] = 0.0;
      }
    }

    supportContracts = allContracts;
    hasSupport = allContracts.isNotEmpty;

    notifyListeners();
  }

  Future<void> loadDocumentStats() async {
    if (projects.isEmpty) return;

    Map<int, Map<String, dynamic>> stats = {};
    List<Future<void>> futures = [];

    for (var project in projects) {
      futures.add(() async {
        try {
          final projectId = project['id'];
          int pEt = 0;
          int pSg = 0;
          int pGn = 0;
          // bool hasPendingEt = false;
          // bool hasPendingSg = false;
          // bool hasPendingGn = false;

          final response = await http.get(Uri.parse('${Endpoint.primDocuments}?\$filter=C_Project_ID eq ${projectId}&\$expand=PRIM_Documents_Related'), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});

          if (response.statusCode == 200) {
            final data = json.decode(utf8.decode(response.bodyBytes));
            final records = data['records'] as List;

            // Retorna true si encontró algún pendiente en esta rama
            void countRecursive(List<dynamic> docs, String? inheritedType) {
              // bool branchHasPending = false;
              for (var doc in docs) {
                dynamic typeVal = doc['Type'];
                String typeCode = '';

                if (typeVal is Map) {
                  typeCode = typeVal['id']?.toString() ?? '';
                } else if (typeVal != null) {
                  typeCode = typeVal.toString();
                }

                if (typeCode.isEmpty && inheritedType != null) {
                  typeCode = inheritedType;
                }

                final isFolder = doc['IsSummary'] == true;
                // final status = doc['Status'];
                // // Pendiente si NO es 'DL' (Entregado) ni 'Entregado' (por si viene el nombre)
                // final isPending = status != 'DL' && status != 'Entregado';
                //
                // if (isPending) branchHasPending = true;

                if (!isFolder) {
                  if (typeCode == 'ET') {
                    pEt++;
                    // if (isPending) hasPendingEt = true;
                  }
                  if (typeCode == 'SG') {
                    pSg++;
                    // if (isPending) hasPendingSg = true;
                  }
                  if (typeCode == 'GN') {
                    pGn++;
                    // if (isPending) hasPendingGn = true;
                  }
                }

                final children = doc['PRIM_Documents_Related'] as List? ?? [];
                if (children.isNotEmpty) {
                  countRecursive(children, typeCode.isNotEmpty ? typeCode : inheritedType);
                  // if (countRecursive(children, typeCode.isNotEmpty ? typeCode : inheritedType)) {
                  //   branchHasPending = true;
                  // }
                }
              }
              // return branchHasPending;
            }

            countRecursive(records, null);
            stats[projectId] = {
              'et': pEt,
              'sg': pSg,
              'gn': pGn,
              // 'pendingEt': hasPendingEt,
              // 'pendingSg': hasPendingSg,
              // 'pendingGn': hasPendingGn
            };
          }
        } catch (e) {
          debugPrint('Error loading document stats for project: ');
        }
      }());
    }

    await Future.wait(futures);
    projectStats = stats;
    notifyListeners();
  }

  void updateSelectedProjects(List<int> ids) {
    selectedProjectIds = ids;
    savedSelectedProjectIds = List.from(ids);
    notifyListeners();
  }

  void updateSelectedSupportBps(List<int> ids) {
    selectedSupportBpIds = ids;
    savedSelectedSupportBpIds = List.from(ids);
    loadSupportContracts();
    loadRecentRequests();
    notifyListeners();
  }

  void setStateForEmptyRequests() {
    requestsStatsByBp.clear();
    consumedHours = 0.0;
    allRequests = [];
    recentRequests = [];
    isLoading = false;
    notifyListeners();
  }

  // Helper to update a request locally after edit
  void updateRequestLocally(Map<String, dynamic> updatedReq) {
    // Logic to update local list if needed, though usually we reload.
    // For now, just notify to refresh UI if we changed something in memory.
    notifyListeners();
  }
}
