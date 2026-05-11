import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';
import 'package:primhub/ui/Shared_Custom/custom_table.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/ui/pages/Support/Requests/create_request_dialog.dart';
import 'package:primhub/ui/pages/Support/Requests/edit_request_dialog.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/pages/Metrics/graphic_functions.dart';
import 'package:primhub/api/global_cache.dart';
import 'package:primhub/ui/Shared_Custom/custom_skeleton.dart';

class ProjectRequestsPage extends StatefulWidget {
  final String? filterType;
  final String? filterStatus;
  final String? filterCompliance;
  final int? projectId;
  final List<String>? taskUUIDs; // UUIDs de tareas para filtro avanzado

  const ProjectRequestsPage({super.key, this.filterType, this.filterStatus, this.filterCompliance, this.projectId, this.taskUUIDs});

  @override
  State<ProjectRequestsPage> createState() => _ProjectRequestsPageState();
}

class _ProjectRequestsPageState extends State<ProjectRequestsPage> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  Map<int, String> _statusNameMap = {};
  Map<String, int> _statusIdMap = {};

  String? _filterType;
  String? _filterStatus;
  String? _filterCompliance;
  int? _projectId;
  List<String>? _taskUUIDs;
  bool _isInit = true;

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
    if (showLoading && _requests.isEmpty) setState(() => _isLoading = true);
    await _fetchStatusesMap();
    await _loadRequests();
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

    // Identificar si la navegación proviene de los gráficos de métricas
    bool isFromMetricsChart = _projectId != null && (_filterType != null || _filterStatus != null || _filterCompliance != null) && _taskUUIDs == null;

    if (isFromMetricsChart) {
      // 1. Obtener exactamente la misma data base que el gráfico para garantizar consistencia total
      rawRequests = await GraphicsFunctions.fetchMetricsData(projectId: _projectId!);
    } else if (GlobalCache.isDataLoaded) {
      // 2. Extraer desde la caché global sin hacer peticiones a la API
      List<String> uuidsToMatch = _taskUUIDs != null ? List.from(_taskUUIDs!) : [];

      if (_projectId != null && uuidsToMatch.isEmpty) {
        try {
          // Si no tenemos los UUIDs de las tareas del proyecto, los extraemos del proyecto cacheado
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
      // 3. Fallback: Lógica para otras vistas haciendo petición API
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
      // REPLICAR EXACTAMENTE LA LÓGICA DE METRICS.DART
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
      String lowerStatus = rawStatusName.toLowerCase();

      // 1. FILTRO DE TIPO / MÓDULO
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

      // 2. FILTRO DE ESTADO
      bool matchesStatus = true;
      if (_filterStatus != null) {
        matchesStatus = cleanStatusName == _filterStatus;
      }

      // 3. FILTRO DE CUMPLIMIENTO (Pie chart / Módulo Series)
      bool matchesCompliance = true;
      if (_filterCompliance != null) {
        // Usar la lógica centralizada para garantizar consistencia con los gráficos.
        final category = ProjectMetricsCalculator.getComplianceCategory(req);
        matchesCompliance = category == _filterCompliance;
      }

      return matchesType && matchesStatus && matchesCompliance;
    }).toList();

    // Procesar para tabla
    final processed = await processRequests(filtered, _statusIdMap);

    if (mounted) {
      setState(() {
        _requests = processed['requests'];
        _isLoading = false;
      });
    }
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Solicitudes: ${_filterType ?? _filterStatus ?? _filterCompliance ?? "Detalle"}'),
        actions: [
          if (GlobalCache.backgroundSyncNotifier.value)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary)),
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
      floatingActionButton: AccessControl.canCreateRequests
          ? FloatingActionButton(
              onPressed: () async {
                if (await showDialog(
                      context: context,
                      builder: (context) => CreateRequestDialog(linkedProjectId: _projectId),
                    ) ==
                    true) {
                  _initData(showLoading: false);
                }
              },
              tooltip: 'Crear Solicitud',
              child: const Icon(Icons.add),
            )
          : null,
      body: _isLoading
          ? const SkeletonTable()
          : _requests.isEmpty
          ? const Center(child: Text('No se encontraron solicitudes para este tipo.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: CustomTable(
                columns: [
                  const DataColumn(label: Text('#')),
                  const DataColumn(label: Text('Ticket')),
                  const DataColumn(label: Text('Resumen')),
                  if (!AccessControl.isProject) const DataColumn(label: Text('Usuario')),
                  if (!AccessControl.isProject) const DataColumn(label: Text('Representante Comercial')),
                  const DataColumn(label: Text('Estado')),
                  const DataColumn(label: Text('Prioridad')),
                  const DataColumn(label: Text('Fecha')),
                  const DataColumn(label: Text('Acciones')),
                ],
                rows: _requests.asMap().entries.map((entry) {
                  final int index = entry.key + 1; // Numeración iniciando en 1
                  final Map<String, dynamic> req = entry.value;
                  return DataRow(
                    cells: [
                      DataCell(Text(index.toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(req['id'].toString()),
                            const SizedBox(width: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: req['id'].toString()));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código copiado al portapapeles')));
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(Icons.copy, size: 16, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Tooltip(
                          message: stripHtmlTags(req['description'] ?? ''),
                          child: SizedBox(width: 300, child: Text(stripHtmlTags(req['description'] ?? '').length > 40 ? '${stripHtmlTags(req['description'] ?? '').substring(0, 40)}...' : stripHtmlTags(req['description'] ?? ''))),
                        ),
                      ),
                      if (!AccessControl.isProject) DataCell(Text(req['userName'] ?? '')),
                      if (!AccessControl.isProject) DataCell(Text(req['salesRepName'] ?? '')),
                      DataCell(Text(req['status'] ?? '')),
                      DataCell(Text(req['level'] ?? '')),
                      DataCell(Text(req['time'] ?? '')),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.reply),
                              tooltip: 'Responder Solicitud',
                              onPressed: () {
                                final id = Uri.encodeComponent(req['realId'].toString());
                                GoRouter.of(context).push('/request-updates/$id', extra: {'docNo': req['id']});
                              },
                            ),
                            if (AccessControl.canManageRequests) IconButton(icon: const Icon(Icons.edit), tooltip: 'Editar Solicitud', onPressed: () => _editRequest(req)),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }
}
