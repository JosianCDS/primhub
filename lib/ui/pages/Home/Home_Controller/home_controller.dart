import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/contract_api.dart';
import 'package:primhub/api/api_utils.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/api/admin_view_mode.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:primhub/api/global_cache.dart';

class HomeController extends ChangeNotifier {
  bool isLoading = true;
  bool validationLoading = true;

  String username = '';
  int? cBPartnerID;
  String? partnerName;
  String? projectPartnerName;

  bool hasSupport = false;
  bool hasProject = false;

  List<dynamic> projects = [];
  List<int> selectedProjectIds = [];
  Map<int, Map<String, dynamic>> projectStats = {};

  List<Map<String, dynamic>> recentRequests = [];
  List<dynamic> allRequests = [];
  Map<int, Map<String, num>> requestsStatsByBp = {};

  List<Map<String, dynamic>> supportContracts = [];

  List<Map<String, dynamic>> supportBPartners = [];
  List<int> selectedSupportBpIds = [];

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

  Future<void> initData({bool forceRefresh = false}) async {
    validationLoading = true;
    isLoading = true;
    notifyListeners();

    await GlobalCache.syncData(force: forceRefresh);

    await loadValidationData();
    if (AccessControl.isAdmin) {
      await loadSupportBPartners();
    }

    validationLoading = false;
    notifyListeners(); // First render to show page structure

    await loadRecentRequests();
    await loadDocumentStats();
    await loadSupportContracts();
  }

  Future<void> loadSupportBPartners() async {
    supportBPartners = GlobalCache.bPartners;
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
          final found = GlobalCache.bPartners.firstWhere((bp) => bp['id'] == partnerID, orElse: () => <String, dynamic>{});
          if (found.isNotEmpty) pName = found['Name'];
        }

        List<dynamic> allProjects = GlobalCache.projects;

        if (AccessControl.isRealProject && partnerID != null) {
          projects = allProjects.where((p) => p['C_BPartner_ID'] is Map ? p['C_BPartner_ID']['id'] == partnerID : p['C_BPartner_ID'] == partnerID).toList();
        } else {
          if (AdminViewModeManager().isViewingMine) {
            projects = allProjects.where((p) {
              final bpId = p['C_BPartner_ID'] is Map ? p['C_BPartner_ID']['id'] : p['C_BPartner_ID'];
              final repId = p['SalesRep_ID'] is Map ? p['SalesRep_ID']['id'] : p['SalesRep_ID'];
              return (partnerID != null && bpId == partnerID) || (User.userID != null && repId == User.userID);
            }).toList();
          } else {
            projects = allProjects;
          }
        }

        if (projects.isNotEmpty) {
          projPName = projects[0]['C_BPartner_ID'] is Map ? projects[0]['C_BPartner_ID']['identifier'] : null;

          final validProjectIds = projects.map<int>((p) => p['id'] is int ? p['id'] as int : int.tryParse(p['id'].toString()) ?? 0).toSet();
          selectedProjectIds = selectedProjectIds.where((id) => validProjectIds.contains(id)).toList();

          if (selectedProjectIds.isEmpty && projects.isNotEmpty) {
            selectedProjectIds = projects.map<int>((p) => p['id'] is int ? p['id'] as int : int.tryParse(p['id'].toString()) ?? 0).toList();
            savedSelectedProjectIds = List.from(selectedProjectIds);
          }
        }
      } catch (e) {}
    }

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
      allBPartnerRequests = GlobalCache.requests.where((r) {
        final rBpId = r['C_BPartner_ID'] is Map ? r['C_BPartner_ID']['id'] : r['C_BPartner_ID'];
        return bpIdsForQuery!.contains(rBpId);
      }).toList();
    } else if (AccessControl.isAdmin) {
      setStateForEmptyRequests();
      return;
    }

    requestsStatsByBp.clear();
    bpIdsForQuery?.forEach((id) {
      requestsStatsByBp[id] = {'closed': 0, 'inProgress': 0, 'consumedHours': 0.0};
    });

    for (var req in allBPartnerRequests) {
      final recordUU = req['Record_UU'];
      if (recordUU != null && recordUU.toString().isNotEmpty) {
        continue;
      }

      final bpId = req['C_BPartner_ID']?['id'];
      if (bpId == null || !requestsStatsByBp.containsKey(bpId)) continue;

      final statusId = req['R_Status_ID'] is Map ? req['R_Status_ID']['id'] : req['R_Status_ID'];
      if (statusId == 103 || req['R_Status_Name'] == '9_Final Close') {
        double hours = (req['QtyPlan'] as num?)?.toDouble() ?? 0.0;
        requestsStatsByBp[bpId]!['consumedHours'] = (requestsStatsByBp[bpId]!['consumedHours']! as num) + hours;
        requestsStatsByBp[bpId]!['closed'] = (requestsStatsByBp[bpId]!['closed']! as int) + 1;
      } else {
        requestsStatsByBp[bpId]!['inProgress'] = (requestsStatsByBp[bpId]!['inProgress']! as int) + 1;
      }
    }

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

    allRequests = nonClosedRequests;

    _applyFilters();
    isLoading = false;
    notifyListeners();
  }

  void _applyFilters() {
    var filtered = List<dynamic>.from(allRequests);
    recentRequests = filtered.take(5).map((r) {
      // Extracción robusta de datos para evitar campos vacíos o incorrectos
      String level = 'Baja'; // Valor por defecto
      dynamic priorityVal = r['Priority'];
      if (priorityVal is Map) {
        level = priorityVal['identifier'] ?? priorityVal['Name'] ?? 'Baja';
      } else if (priorityVal != null) {
        String pStr = priorityVal.toString();
        if (pStr == '1')
          level = 'Urgente';
        else if (pStr == '3')
          level = 'Alta';
        else if (pStr == '5')
          level = 'Media';
        else if (pStr == '7')
          level = 'Baja';
        else if (pStr == '9')
          level = 'Menor';
      }

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

      String situation = r['R_RequestType_ID'] is Map ? (r['R_RequestType_ID']['identifier'] ?? r['R_RequestType_ID']['Name'] ?? r['R_RequestType_Name'] ?? 'Solicitud') : (r['R_RequestType_Name'] ?? 'Solicitud');
      String status = r['R_Status_ID'] is Map ? (r['R_Status_ID']['identifier'] ?? r['R_Status_ID']['Name'] ?? '1_Open') : (r['R_Status_Name'] ?? '1_Open');
      String bpName = '';
      if (r['C_BPartner_ID'] is Map) {
        bpName = r['C_BPartner_ID']['identifier'] ?? r['C_BPartner_ID']['Name'] ?? '';
      }
      String userName = '';
      if (r['AD_User_ID'] is Map) {
        userName = r['AD_User_ID']['identifier'] ?? r['AD_User_ID']['Name'] ?? '';
      }

      return {
        'code': r['DocumentNo'] ?? r['id'].toString(),
        'situation': situation,
        'emailSubject': r['CDS_EmailSubject'] ?? '',
        'description': r['Summary'] ?? '',
        'descriptionClean': stripHtmlTags(r['Summary'] ?? ''),
        'time': formattedTime,
        'level': level,
        'levelColor': baseColor,
        'levelBgColor': baseColor.withOpacity(0.2),
        'status': status,
        'bpName': bpName,
        'userName': userName,
        'original': r,
      };
    }).toList();
  }

  Future<void> loadSupportContracts() async {
    List<int>? bpIdsForQuery;

    if (AccessControl.isAdmin) {
      if (selectedSupportBpIds.isEmpty) {
        supportContracts = [];
        hasSupport = false;
        notifyListeners();
        return;
      }
      bpIdsForQuery = selectedSupportBpIds;
    } else {
      if (User.cBPartnerID != null) {
        bpIdsForQuery = [User.cBPartnerID!];
      }
    }

    if (bpIdsForQuery == null || bpIdsForQuery.isEmpty) {
      supportContracts = [];
      hasSupport = false;
      notifyListeners();
      return;
    }

    final allFetchedContracts = GlobalCache.contracts.where((c) {
      return bpIdsForQuery!.contains(c['C_BPartner_ID']);
    }).toList();
    final Map<int, List<Map<String, dynamic>>> contractsByBp = {};

    for (var contract in allFetchedContracts) {
      final bpId = contract['C_BPartner_ID'];
      if (bpId != null) {
        (contractsByBp[bpId] ??= []).add(contract);
      }
    }

    List<Map<String, dynamic>> processedContracts = [];
    contractsByBp.forEach((bpId, bpContracts) {
      double remainingConsumed = (requestsStatsByBp[bpId]?['consumedHours'] as num?)?.toDouble() ?? 0.0;

      for (var contract in bpContracts) {
        double contracted = (contract['contractedHours'] as num?)?.toDouble() ?? 0.0;
        if (remainingConsumed > 0) {
          double consumedInContract = (remainingConsumed >= contracted) ? contracted : remainingConsumed;
          contract['consumedHours'] = consumedInContract;
          remainingConsumed -= consumedInContract;
        } else {
          contract['consumedHours'] = 0.0;
        }
        processedContracts.add(contract);
      }
    });

    supportContracts = processedContracts;
    hasSupport = allFetchedContracts.isNotEmpty;

    notifyListeners();
  }

  Future<void> loadDocumentStats() async {
    if (projects.isEmpty) return;

    Map<int, Map<String, dynamic>> stats = {};
    List<Future<void>> futures = [];

    for (var project in projects) {
      futures.add(() async {
        try {
          final projectId = project['id'] is int ? project['id'] as int : int.tryParse(project['id'].toString()) ?? 0;
          int pEt = 0;
          int pSg = 0;
          int pGn = 0;
          bool hasMetrics = false;

          try {
            var response = await http.get(Uri.parse('${Endpoint.primDocuments}?\$filter=C_Project_ID eq ${projectId}&\$expand=PRIM_Documents_Related'), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});
            if (response.statusCode == 401) {
              final refreshed = await handleTokenRefresh();
              if (refreshed) {
                response = await http.get(Uri.parse('${Endpoint.primDocuments}?\$filter=C_Project_ID eq ${projectId}&\$expand=PRIM_Documents_Related'), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});
              }
            }

            if (response.statusCode == 200) {
              final data = json.decode(utf8.decode(response.bodyBytes));
              final records = data['records'] as List;

              void countRecursive(List<dynamic> docs, String? inheritedType) {
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
                  if (!isFolder) {
                    if (typeCode == 'ET') pEt++;
                    if (typeCode == 'SG') pSg++;
                    if (typeCode == 'GN') pGn++;
                  }
                  final children = doc['PRIM_Documents_Related'] as List? ?? [];
                  if (children.isNotEmpty) {
                    countRecursive(children, typeCode.isNotEmpty ? typeCode : inheritedType);
                  }
                }
              }

              countRecursive(records, null);
            }
          } catch (e) {}

          try {
            var metricsRes = await http.get(Uri.parse('${Endpoint.request}?\$filter=C_Project_ID eq $projectId and R_Group_ID eq 1000006&\$top=1&\$select=R_Request_ID'), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});
            if (metricsRes.statusCode == 200) {
              final mData = json.decode(utf8.decode(metricsRes.bodyBytes));
              hasMetrics = (mData['records'] as List).isNotEmpty;
            }
          } catch (_) {}

          stats[projectId] = {'et': pEt, 'sg': pSg, 'gn': pGn, 'hasMetrics': hasMetrics};
        } catch (e) {}
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
    allRequests = [];
    recentRequests = [];
    isLoading = false;
    notifyListeners();
  }

  void updateRequestLocally(Map<String, dynamic> updatedReq) {
    notifyListeners();
  }
}
