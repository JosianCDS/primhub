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
  Map<int, Map<String, int>> projectStats = {};

  // Requests
  List<Map<String, dynamic>> recentRequests = [];
  List<dynamic> allRequests = [];
  int openRequestsCount = 0;
  int inProgressRequestsCount = 0;
  int closedRequestsCount = 0;

  // Hours
  double? contractedHours;
  double consumedHours = 0.0;

  // Static persistence (from original file)
  static List<int> savedSelectedProjectIds = [];

  HomeController() {
    selectedProjectIds = List.from(savedSelectedProjectIds);
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
    await loadValidationData();
    await loadContractedHours();
    await loadRecentRequests();
    await loadDocumentStats();
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

        final projResponse = await http.get(Uri.parse(Endpoint.project), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});
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

    hasSupport = prefs.getBool('has_support') ?? false;
    hasProject = projects.isNotEmpty;
    cBPartnerID = partnerID;
    partnerName = pName;
    projectPartnerName = projPName;
    validationLoading = false;
    notifyListeners();
  }

  Future<void> loadRecentRequests() async {
    final requests = await fetchRequest();

    int open = 0;
    int others = 0;
    int closed = 0;
    double totalConsumed = 0.0;

    for (var req in requests) {
      if (req['R_Status_Name'] != '9_Final Close' && req['R_Status_ID'] != 103) {
        // Not closed
      } else {
        double hours = (req['QtyPlan'] as num?)?.toDouble() ?? 0.0;
        totalConsumed += hours;
      }

      if (req['R_Status_Name'] == '9_Final Close' || req['R_Status_ID'] == 103) {
        closed++;
      } else {
        others++;
      }
    }

    requests.sort((a, b) {
      final dateA = DateTime.tryParse(a['Created'] ?? '') ?? DateTime(0);
      final dateB = DateTime.tryParse(b['Created'] ?? '') ?? DateTime(0);
      return dateB.compareTo(dateA);
    });

    openRequestsCount = open;
    inProgressRequestsCount = others;
    closedRequestsCount = closed;
    consumedHours = totalConsumed;
    allRequests = requests.where((r) => r['R_Status_Name'] != '9_Final Close' && r['R_Status_ID'] != 103).toList();

    _applyFilters();
    isLoading = false;
    notifyListeners();
  }

  void _applyFilters() {
    var filtered = List<dynamic>.from(allRequests);
    filtered = filtered.where((r) {
      final recordUU = r['Record_UU'];
      return recordUU == null || recordUU.toString().isEmpty;
    }).toList();

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

  Future<void> loadContractedHours() async {
    final total = await ContractApi.getContractedHours();
    if (total != null) {
      contractedHours = total;
      notifyListeners();
    }
  }

  Future<void> loadDocumentStats() async {
    if (projects.isEmpty) return;

    Map<int, Map<String, int>> stats = {};
    List<Future<void>> futures = [];

    for (var project in projects) {
      futures.add(() async {
        try {
          final projectId = project['id'];
          int pEt = 0;
          int pSg = 0;
          int pGn = 0;

          final response = await http.get(Uri.parse('${Endpoint.primDocuments}?\$filter=C_Project_ID eq ${projectId}&\$expand=PRIM_Documents_Related'), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});

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
            stats[projectId] = {'et': pEt, 'sg': pSg, 'gn': pGn};
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

  // Helper to update a request locally after edit
  void updateRequestLocally(Map<String, dynamic> updatedReq) {
    // Logic to update local list if needed, though usually we reload.
    // For now, just notify to refresh UI if we changed something in memory.
    notifyListeners();
  }
}
