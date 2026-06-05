import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart'; 
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/ui/pages/Support/Requests/create_request_dialog.dart';
import 'package:primhub/ui/pages/Support/Requests/edit_request_dialog.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/pages/Metrics/graphic_functions.dart';
import 'package:primhub/ui/Shared_Custom/requests_data_table_core.dart'; 
import 'package:primhub/api/global_cache.dart';
import 'package:primhub/ui/Shared_Custom/custom_skeleton.dart';

class ProjectRequestsPage extends StatefulWidget {
  final String? filterType;
  final String? filterStatus;
  final String? filterCompliance;
  final int? projectId;
  final List<String>? taskUUIDs;

  const ProjectRequestsPage({super.key, this.filterType, this.filterStatus, this.filterCompliance, this.projectId, this.taskUUIDs});

  @override
  State<ProjectRequestsPage> createState() => _ProjectRequestsPageState();
}

class _ProjectRequestsPageState extends State<ProjectRequestsPage> {
  List<Map<String, dynamic>> _allRequests = []; 
  List<Map<String, dynamic>> _paginatedRequests = []; 
  bool _isLoading = true;
  Map<int, String> _statusNameMap = {};
  Map<String, int> _statusIdMap = {};

  String? _filterType;
  String? _filterStatus;
  String? _filterCompliance;
  int? _projectId;
  List<String>? _taskUUIDs;
  bool _isInit = true;

  int _currentPage = 0;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    GlobalCache.backgroundSyncNotifier.addListener(_onBackgroundSyncChanged);
  }

  void _onBackgroundSyncChanged() {
    if (!GlobalCache.backgroundSyncNotifier.value && mounted) {
      _initData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      _filterType = widget.filterType;
      _filterStatus = widget.filterStatus;
      _filterCompliance = widget.filterCompliance;
      _projectId = widget.projectId;
      _taskUUIDs = widget.taskUUIDs;

      try {
        final extra = GoRouterState.of(context).extra;
        if (extra is Map) {
          if (extra.containsKey('filterType')) _filterType = extra['filterType'];
          if (extra.containsKey('filterStatus')) _filterStatus = extra['filterStatus'];
          if (extra.containsKey('filterCompliance')) _filterCompliance = extra['filterCompliance'];
          if (extra.containsKey('projectId')) _projectId = extra['projectId'];
          if (extra.containsKey('taskUUIDs')) _taskUUIDs = extra['taskUUIDs'];
        }
      } catch (_) {}

      _isInit = false;
      _initData();
    }
  }

  Future<void> _initData({bool showLoading = true}) async {
    if (showLoading && _allRequests.isEmpty) setState(() => _isLoading = true);
    await _fetchStatusesMap();
    // Corrected method name to match the definition below
    await _loadRequests(); 
    _applyPagination(); 
  }

  Future<void> _fetchStatusesMap() async {
    if (GlobalCache.isDataLoaded && GlobalCache.statuses.isNotEmpty) {
      if (mounted) {
        setState(() {
          _statusIdMap = GlobalCache.statuses;
          _statusNameMap = GlobalCache.statuses.map((key, value) => MapEntry(value, key));
        });
      }
    } else {
      final statuses = await fetchStatuses();
      if (mounted) {
        setState(() {
          _statusIdMap = statuses;
          _statusNameMap = statuses.map((key, value) => MapEntry(value, key));
        });
      }
    }
  }

  Future<void> _loadRequests() async {
    List<Map<String, dynamic>> rawRequests = [];
    bool isFromMetricsChart = _projectId != null && (_filterType != null || _filterStatus != null || _filterCompliance != null) && _taskUUIDs == null;

    if (isFromMetricsChart) {
      rawRequests = await GraphicsFunctions.fetchMetricsData(projectId: _projectId!);
    } else if (GlobalCache.isDataLoaded) {
      List<String> uuidsToMatch = _taskUUIDs != null ? List.from(_taskUUIDs!) : [];

      if (_projectId != null && uuidsToMatch.isEmpty) {
        try {
          final project = GlobalCache.projects.firstWhere((p) => p['id'] == _projectId, orElse: () => null);
          if (project != null) {
            final phases = project['C_ProjectPhase'] as List? ?? [];
            for (var phase in phases) {
              final tasks = phase['C_ProjectTask'] as List? ?? [];
              for (var task in tasks) {
                final uuid = task['Record_UU'] ?? task['UUID'] ?? task['uuid'] ?? task['uid'];
                if (uuid != null) uuidsToMatch.add(uuid.toString());
              }
            }
            final directTasks = project['C_ProjectTask'] as List? ?? [];
            for (var task in directTasks) {
              final uuid = task['Record_UU'] ?? task['UUID'] ?? task['uuid'] ?? task['uid'];
              if (uuid != null) uuidsToMatch.add(uuid.toString());
            }
          }
        } catch (_) {}
      }

      rawRequests = GlobalCache.requests.where((req) {
        bool isActive = req['IsActive'] == true || req['IsActive'] == 'Y';
        int? reqGroupId = req['R_Group_ID'] is Map ? req['R_Group_ID']['id'] : req['R_Group_ID'];
        if (!isActive || reqGroupId != 1000006) return false;

        if (!AccessControl.isAdmin && AccessControl.isProject && User.cBPartnerID != null) {
          int? reqBpId = req['C_BPartner_ID'] is Map ? req['C_BPartner_ID']['id'] : req['C_BPartner_ID'];
          if (reqBpId != User.cBPartnerID) return false;
        }

        if (_projectId != null) {
          int? reqProjectId = req['C_Project_ID'] is Map ? req['C_Project_ID']['id'] : req['C_Project_ID'];
          bool matchesProject = reqProjectId == _projectId;
          bool matchesTask = uuidsToMatch.contains(req['Record_UU']?.toString());
          return matchesProject || matchesTask;
        } else if (_taskUUIDs != null && _taskUUIDs!.isNotEmpty) {
          return _taskUUIDs!.contains(req['Record_UU']?.toString());
        }
        return true;
      }).toList();
    } else {
      List<String> filters = ["IsActive eq true", "R_Group_ID eq 1000006"];
      if (!AccessControl.isAdmin && AccessControl.isProject && User.cBPartnerID != null) {
        filters.add("C_BPartner_ID eq ${User.cBPartnerID}");
      }
      String additionalFilter = filters.join(" and ");
      String expand = "R_Status_ID(\$select=Name,IsOpen),R_Group_ID(\$select=Name),R_RequestType_ID(\$select=Name),R_Category_ID(\$select=Name)";

      if (_projectId != null) {
        rawRequests = await fetchProjectAndTaskRequests(_projectId!, taskUUIDs: _taskUUIDs, additionalFilter: additionalFilter, expand: expand);
      } else if (_taskUUIDs != null && _taskUUIDs!.isNotEmpty) {
        final uuidsCondition = _taskUUIDs!.map((uuid) => "Record_UU eq '$uuid'").join(' or ');
        rawRequests = await fetchRequest(filter: "($uuidsCondition) and $additionalFilter", expand: expand);
      } else {
        rawRequests = await fetchRequest(filter: additionalFilter, expand: expand);
      }
    }

    final filtered = rawRequests.where((req) {
      final statusObj = req['R_Status_ID'];
      final statusData = statusObj is Map ? statusObj : null;
      String rawStatusName = req['R_Status_Name'] ?? '';

      if (statusData != null) {
        rawStatusName = statusData['Name'] ?? statusData['identifier'] ?? rawStatusName;
      }
      if (rawStatusName.isEmpty && statusObj is int) {
        rawStatusName = _statusNameMap[statusObj] ?? '';
      }
      if (rawStatusName.isEmpty) {
        rawStatusName = _statusIdMap.keys.firstWhere((k) => _statusIdMap[k] == req['R_Status_ID'], orElse: () => 'Sin Estado');
      }

      String cleanStatusName = rawStatusName.contains('_') ? rawStatusName.split('_').last.trim() : rawStatusName.trim();

      bool matchesType = true;
      if (_filterType != null) {
        String categoryName = '';
        final categoryObj = req['R_Category_ID'];
        if (categoryObj is Map) {
          categoryName = categoryObj['Name'] ?? categoryObj['identifier'] ?? categoryObj['name'] ?? '';
        }
        if (categoryName.isEmpty) categoryName = 'Sin Módulo';
        String cleanFilter = _filterType!.replaceAll('.', '').trim();
        matchesType = categoryName == _filterType || categoryName.startsWith(cleanFilter);
      }

      bool matchesStatus = true;
      if (_filterStatus != null) {
        matchesStatus = cleanStatusName == _filterStatus;
      }

      bool matchesCompliance = true;
      if (_filterCompliance != null) {
        final category = ProjectMetricsCalculator.getComplianceCategory(req);
        matchesCompliance = category == _filterCompliance;
      }

      return matchesType && matchesStatus && matchesCompliance;
    }).toList();

    final processed = await processRequests(filtered, _statusIdMap);

    if (mounted) {
      setState(() {
        _allRequests = (processed['requests'] as List<dynamic>).cast<Map<String, dynamic>>();
        _isLoading = false;
        _currentPage = 0;
      });
    }
  }

  void _applyPagination() {
    final int totalItems = _allRequests.length;
    final int totalPages = (totalItems / _rowsPerPage).ceil();
    if (_currentPage >= totalPages) _currentPage = totalPages > 0 ? totalPages - 1 : 0;
    final int startIndex = _currentPage * _rowsPerPage;
    final int endIndex = (startIndex + _rowsPerPage < totalItems) ? startIndex + _rowsPerPage : totalItems;
    
    setState(() {
      _paginatedRequests = totalItems > 0 ? _allRequests.sublist(startIndex, endIndex) : <Map<String, dynamic>>[];
    });
  }

  Future<void> _deleteRequest(dynamic id) async {
    if (!AccessControl.canManageRequests) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tienes permisos para eliminar solicitudes.')));
      return;
    }
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => CustomModal(
        title: 'Confirmar Eliminación',
        content: const Text('¿Está seguro de que desea eliminar esta solicitud?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          CustomButton(text: 'Eliminar', backgroundColor: Colors.red, onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirm == true) {
      final success = await deleteRequestApi(id);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud eliminada correctamente')));
          _initData(showLoading: false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al eliminar'), backgroundColor: Colors.red));
        }
      }
    }
  }

  void _editRequest(Map<String, dynamic> req) {
    if (!AccessControl.canManageRequests) return;
    showDialog(
      context: context,
      builder: (context) => EditRequestDialog(
        request: req,
        statusIdMap: _statusIdMap,
        priorityMap: priorityMap,
        onSave: () async {
          _initData(showLoading: false);
        },
        onDelete: () => _deleteRequest(req['realId']),
      ),
    );
  }

  @override
  void dispose() {
    GlobalCache.backgroundSyncNotifier.removeListener(_onBackgroundSyncChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {    
    final int totalItems = _allRequests.length;
    final int totalPages = (totalItems / _rowsPerPage).ceil();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Solicitudes: ${_filterType ?? _filterStatus ?? _filterCompliance ?? "Detalle"}'),
        actions: [
          if (GlobalCache.backgroundSyncNotifier.value)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: () => GlobalCache.performSmartSync(context, () async {
              await _initData();
            }),
          ),
        ],
      ),

      body: SafeArea(
        child: _isLoading
            ? const SkeletonTable()
            : _allRequests.isEmpty
                ? const Center(child: Text('No se encontraron solicitudes para este tipo.'))
                : Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: RequestsDataTableCore(
                            requests: _paginatedRequests,
                            statusIdMap: _statusIdMap,
                            priorityMap: priorityMap,
                            onEdit: _editRequest,
                            onRefresh: () => _initData(showLoading: false),
                            showProjectContext: AccessControl.isProject,
                          ),
                        ),
                      ),
                      if (totalPages > 1) 
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0, bottom: 16.0),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 16.0,
                            children: [
                              DropdownButton<int>(
                                value: _rowsPerPage,
                                items: const [10, 25, 50, 100].map((int value) => DropdownMenuItem<int>(value: value, child: Text('$value filas'))).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _rowsPerPage = val;
                                      _currentPage = 0;
                                    });
                                    _applyPagination();
                                  }
                                },
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: _currentPage > 0 ? () => setState(() { _currentPage--; _applyPagination(); }) : null),
                                  Text('Página ${_currentPage + 1} de $totalPages', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: _currentPage < totalPages - 1 ? () => setState(() { _currentPage++; _applyPagination(); }) : null),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}