import 'package:flutter/material.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/pages/Support/Requests/edit_request_dialog.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/api/global_cache.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/ui/Shared_Custom/requests_data_table_core.dart'; // Usar el componente core
import 'package:primhub/api/token.dart'; // Necesario para priorityMap

class ProjectRequestsView extends StatefulWidget {
  final String? filterType;
  final String? filterStatus;
  final String? filterCompliance;
  final int? projectId;
  final List<String>? taskUUIDs;
  final bool showAllGroups;

  const ProjectRequestsView({
    super.key,
    this.filterType,
    this.filterStatus,
    this.filterCompliance,
    this.projectId,
    this.taskUUIDs,
    this.showAllGroups = false,
  });

  @override
  State<ProjectRequestsView> createState() => _ProjectRequestsViewState();
}

class _ProjectRequestsViewState extends State<ProjectRequestsView> {
  List<Map<String, dynamic>> _allProjectRequests = [];
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  Map<String, int> _statusIdMap = {};
  List<dynamic> _users = [];
  final TextEditingController _searchController = TextEditingController();
  String _projectName = '';

  String? _selectedType;
  // ignore: unused_field
  String? _selectedStatus;
  int? _selectedUserId;
  String? _selectedLevel;
  String? _selectedPhase;
  String? _selectedTask;
  String? _selectedCategory;
  int? _selectedSalesRepId;
  // ignore: unused_field
  bool _isAscending = false;

  // Pagination state
  int _currentPageSize = 25;
  int _currentSkip = 0;
  int _totalRecords = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => _applyFilters());
    _initData();
  }

  Future<void> _initData({bool showLoading = true, bool resetPage = true}) async {
    if (!mounted) return;
    if (showLoading) setState(() => _isLoading = true);

    _users =
        GlobalCache.users; // Assuming GlobalCache.users is already populated
    _statusIdMap = GlobalCache.statuses;

    await _loadRequests(resetPage: resetPage);
  }

  Future<void> _loadRequests({bool resetPage = true}) async {
    // --- DEBUG LOGS ---
    print("DEBUG: Cargando solicitudes para Proyecto ID: ${widget.projectId}");
    print("DEBUG: Total solicitudes en Cache: ${GlobalCache.requests.length}");

    List<String> taskUUIDs = [];
    Map<String, String> uuidToTaskName = {};
    Map<String, String> uuidToPhaseName = {};
    Map<String, String> taskIdToTaskName = {};
    Map<String, String> taskIdToPhaseName = {};
    Map<String, String> idToPhaseName = {};

    // 1. Mapear la estructura del proyecto para obtener todos los UUIDs de tareas
    if (widget.projectId != null) {
      final project = GlobalCache.projects.firstWhere(
        (p) => p['id']?.toString() == widget.projectId?.toString(),
        orElse: () => <String, dynamic>{},
      );

      if (project.isNotEmpty) {
        _projectName = project['Name'] ?? '';

        final phases = List<dynamic>.from(
          project['C_ProjectPhase'] as List? ?? [],
        );
        final directTasks = List<dynamic>.from(
          project['C_ProjectTask'] as List? ?? [],
        );

        for (var phase in phases) {
          final phaseName = phase['Name'] ?? 'Fase';
          final phaseIdStr = phase['id']?.toString();
          if (phaseIdStr != null) {
            idToPhaseName[phaseIdStr] = phaseName;
          }
          final tasks = List<dynamic>.from(
            phase['C_ProjectTask'] as List? ?? [],
          );
          for (var task in tasks) {
            final taskName = task['Name'] ?? 'Tarea';
            final taskIdStr = task['id']?.toString();
            if (taskIdStr != null) {
              taskUUIDs.add(taskIdStr.toLowerCase());
              taskIdToTaskName[taskIdStr] = taskName;
              taskIdToPhaseName[taskIdStr] = phaseName;
            }
            final uuidList = [
              task['C_ProjectTask_UU'],
              task['Record_UU'],
              task['UUID'],
              task['uuid'],
              task['uid'],
            ];
            for (var uu in uuidList) {
              if (uu != null && uu.toString().trim().isNotEmpty) {
                final uStr = uu.toString().toLowerCase();
                taskUUIDs.add(uStr);
                uuidToTaskName[uStr] = taskName;
                uuidToPhaseName[uStr] = phaseName;
              }
            }
          }
        }
        for (var task in directTasks) {
          final taskName = task['Name'] ?? 'Tarea';
          final taskIdStr = task['id']?.toString();
          if (taskIdStr != null) {
            taskUUIDs.add(taskIdStr.toLowerCase());
            taskIdToTaskName[taskIdStr] = taskName;
            taskIdToPhaseName[taskIdStr] = '-';
          }
          final uuidList = [
            task['C_ProjectTask_UU'],
            task['Record_UU'],
            task['UUID'],
            task['uuid'],
            task['uid'],
          ];
          for (var uu in uuidList) {
            if (uu != null && uu.toString().trim().isNotEmpty) {
              final uStr = uu.toString().toLowerCase();
              taskUUIDs.add(uStr);
              uuidToTaskName[uStr] = taskName;
              uuidToPhaseName[uStr] = '-';
            }
          }
        }
      }
    }

    // 2. Carga Mixta: Cache + Fondo
    if (widget.projectId != null) {
      final projectId = widget.projectId!;
      final cached = GlobalCache.projectRequestsCache[projectId];
      
      if (cached != null && cached.isNotEmpty) {
        debugPrint("PROJECT_VIEW: Usando datos de caché para Proyecto $projectId");
        _processRawRequests(cached, uuidToTaskName, uuidToPhaseName, taskIdToTaskName, taskIdToPhaseName, idToPhaseName, resetPage: resetPage);
        
        // Refrescar en fondo igual por si hay cambios
        GlobalCache.loadProjectRequestsInBackground(
          projectId,
          taskUUIDs: taskUUIDs,
          onUpdate: (newList) {
            if (mounted) _processRawRequests(newList, uuidToTaskName, uuidToPhaseName, taskIdToTaskName, taskIdToPhaseName, idToPhaseName, resetPage: false);
          }
        );
      } else {
        debugPrint("PROJECT_VIEW: Iniciando carga rápida + fondo para Proyecto $projectId");
        
        // Lanzar carga en fondo inmediatamente
        GlobalCache.loadProjectRequestsInBackground(
          projectId,
          taskUUIDs: taskUUIDs,
          onUpdate: (newList) {
            if (mounted) _processRawRequests(newList, uuidToTaskName, uuidToPhaseName, taskIdToTaskName, taskIdToPhaseName, idToPhaseName, resetPage: false);
          }
        );
        
        // Carga rápida inicial de solo la cabecera para mostrar algo de inmediato
        final quickHeader = await fetchRequest(
          filter: "C_Project_ID eq $projectId", 
          expand: 'C_Order_ID(\$select=DocumentNo),R_Status_ID,R_RequestType_ID,R_Category_ID,Priority'
        );
        
        if (mounted && quickHeader.isNotEmpty && (GlobalCache.projectRequestsCache[projectId]?.length ?? 0) <= quickHeader.length) {
          _processRawRequests(quickHeader, uuidToTaskName, uuidToPhaseName, taskIdToTaskName, taskIdToPhaseName, idToPhaseName, resetPage: resetPage);
        } else if (quickHeader.isEmpty && !GlobalCache.projectLoadingStatus[projectId]!) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _processRawRequests(
    List<Map<String, dynamic>> rawFound,
    Map<String, String> uuidToTaskName,
    Map<String, String> uuidToPhaseName,
    Map<String, String> taskIdToTaskName,
    Map<String, String> taskIdToPhaseName,
    Map<String, String> idToPhaseName, {
    bool resetPage = false,
  }) async {
    final processed = await processRequests(rawFound, _statusIdMap);
    List<Map<String, dynamic>> finalReqs = [];

    for (var req in (processed['requests'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      final reqUU = req['recordUU']?.toString().toLowerCase();
      final rawReq = req['original'] ?? req;
      
      // Priorizar los campos de fase/tarea directos del registro si existen
      final rTaskId = (rawReq['C_ProjectTask_ID'] is Map ? rawReq['C_ProjectTask_ID']['id'] : rawReq['C_ProjectTask_ID'])?.toString();
      final rPhaseId = (rawReq['C_ProjectPhase_ID'] is Map ? rawReq['C_ProjectPhase_ID']['id'] : rawReq['C_ProjectPhase_ID'])?.toString();
      final rProjectId = (rawReq['C_Project_ID'] is Map ? rawReq['C_Project_ID']['id'] : rawReq['C_Project_ID'])?.toString();

      // FILTRO ESTRICTO: Solo mostrar si pertenece a este proyecto o a una de sus tareas/UUIDs
      bool belongsToProject = rProjectId == widget.projectId.toString() || 
                             (reqUU != null && uuidToTaskName.containsKey(reqUU)) ||
                             (rTaskId != null && taskIdToTaskName.containsKey(rTaskId));
                             
      if (!belongsToProject) continue;

      String taskName = 'General / Proyecto';
      String phaseName = '-';

      // 1. Intentar por UUID (Lógica heredada para casos específicos)
      if (reqUU != null && uuidToTaskName.containsKey(reqUU)) {
        taskName = uuidToTaskName[reqUU]!;
        phaseName = uuidToPhaseName[reqUU] ?? '-';
      } 
      // 2. Intentar por ID de Tarea mapeado
      else if (rTaskId != null && taskIdToTaskName.containsKey(rTaskId)) {
        taskName = taskIdToTaskName[rTaskId]!;
        phaseName = taskIdToPhaseName[rTaskId] ?? '-';
      } 
      // 3. Fallback a los datos expandidos del registro
      else {
        if (rPhaseId != null && idToPhaseName.containsKey(rPhaseId)) {
          phaseName = idToPhaseName[rPhaseId]!;
        } else if (rawReq['C_ProjectPhase_ID'] is Map) {
          phaseName = rawReq['C_ProjectPhase_ID']['identifier'] ?? rawReq['C_ProjectPhase_ID']['Name'] ?? '-';
        }
        
        if (rawReq['C_ProjectTask_ID'] is Map) {
          taskName = rawReq['C_ProjectTask_ID']['identifier'] ?? rawReq['C_ProjectTask_ID']['Name'] ?? 'General / Proyecto';
        }
      }

      req['taskName'] = taskName;
      req['phaseName'] = phaseName;
      finalReqs.add(req);
    }

    if (mounted) {
      setState(() {
        _allProjectRequests = finalReqs;
        if (resetPage) _currentSkip = 0;
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  void _applyFilters({bool resetPage = false}) {
    if (resetPage) _currentSkip = 0;
    
    final filtered = _allProjectRequests.where((req) {
      if (_selectedType != null && req['type'] != _selectedType)
        return false; // This filter is applied to _rawRequests
      if (_selectedStatus != null && req['status'] != _selectedStatus)
        return false;
      if (_selectedLevel != null && req['level'] != _selectedLevel)
        return false;
      if (_selectedPhase != null && req['phaseName'] != _selectedPhase)
        return false;
      if (_selectedTask != null && req['taskName'] != _selectedTask)
        return false;
      if (_selectedCategory != null && req['category'] != _selectedCategory)
        return false;
      if (_selectedSalesRepId != null &&
          req['salesRepId'] != _selectedSalesRepId)
        return false;

      if (_searchController.text.isNotEmpty) {
        final search = _searchController.text.toLowerCase();
        return req['id'].toString().toLowerCase().contains(search) ||
            (req['descriptionClean'] ?? '').toString().toLowerCase().contains(
              search,
            );
      }
      return true;
    }).toList();

    _totalRecords = filtered.length;

    // Apply Local Pagination
    final endIndex = (_currentSkip + _currentPageSize < _totalRecords) 
        ? _currentSkip + _currentPageSize 
        : _totalRecords;
        
    final paginated = filtered.sublist(_currentSkip, endIndex);

    setState(() {
      _requests = paginated;
    });
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('Filas:'),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _currentPageSize,
                underline: const SizedBox(),
                items: [10, 25, 50, 100].map((size) {
                  return DropdownMenuItem<int>(
                    value: size,
                    child: Text(size.toString()),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _currentPageSize = val;
                      _currentSkip = 0;
                      _applyFilters();
                    });
                  }
                },
              ),
            ],
          ),
          Text(
            '${_totalRecords == 0 ? 0 : _currentSkip + 1} - ${(_currentSkip + _currentPageSize < _totalRecords) ? _currentSkip + _currentPageSize : _totalRecords} de $_totalRecords',
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentSkip == 0
                    ? null
                    : () {
                        setState(() {
                          _currentSkip -= _currentPageSize;
                          if (_currentSkip < 0) _currentSkip = 0;
                          _applyFilters();
                        });
                      },
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: (_currentSkip + _currentPageSize >= _totalRecords)
                    ? null
                    : () {
                        setState(() {
                          _currentSkip += _currentPageSize;
                          _applyFilters();
                        });
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _projectName.isNotEmpty
              ? 'Solicitudes del Proyecto $_projectName'
              : 'Solicitudes de Proyecto',
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _initData),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _requests.isEmpty
                ? const Center(
                    child: Text('No se encontraron solicitudes vinculadas.'),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: RequestsDataTableCore(
                      requests: _requests,
                      statusIdMap: _statusIdMap,
                      priorityMap: priorityMap,
                      onEdit: (req) => _editRequest(req),
                      onRefresh: () => _initData(showLoading: false),
                      showProjectContext: true,
                      serverSidePagination: true,
                      paginationControls: _buildPaginationControls(),
                      useSimpleStatus: true,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedPhase != null) count++;
    if (_selectedTask != null) count++;
    if (_selectedCategory != null) count++;
    if (_selectedType != null) count++;
    if (_selectedSalesRepId != null) count++;
    if (_selectedStatus != null) count++;
    if (_selectedLevel != null) count++;
    return count;
  }

  Future<void> _showFilterModal() async {
    final phases =
        _allProjectRequests
            .map((e) => e['phaseName'].toString())
            .where((e) => e != '-')
            .toSet()
            .toList()
          ..sort();
    final categories =
        _allProjectRequests
            .map((e) => e['category'].toString())
            .where((e) => e.isNotEmpty && e != 'null')
            .toSet()
            .toList()
          ..sort();
    final types =
        _allProjectRequests
            .map((e) => e['type'].toString())
            .where((e) => e.isNotEmpty && e != 'null')
            .toSet()
            .toList()
          ..sort();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final tasks =
                _allProjectRequests
                    .where(
                      (e) =>
                          _selectedPhase == null ||
                          e['phaseName'] == _selectedPhase,
                    )
                    .map((e) => e['taskName'].toString())
                    .where((e) => e != 'General / Proyecto')
                    .toSet()
                    .toList()
                  ..sort();

            Widget simpleModalDropdown(
              String label,
              String? value,
              List<String> items,
              Function(String?) onChanged,
            ) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: CustomDropdown<String?>(
                  label: label,
                  value: value,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    ...items
                        .where((i) => i != 'null')
                        .map(
                          (i) => DropdownMenuItem(
                            value: i,
                            child: Text(i, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                  ],
                  onChanged: (v) {
                    onChanged(v);
                    setModalState(() {});
                  },
                ),
              );
            }

            return CustomModal(
              title: 'Filtros de Proyecto',
              width: 500,
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    simpleModalDropdown('Fase', _selectedPhase, phases, (v) {
                      _selectedPhase = v;
                      _selectedTask = null; // Reset task if phase changes
                    }),
                    simpleModalDropdown(
                      'Tarea',
                      _selectedTask,
                      tasks,
                      (v) => _selectedTask = v,
                    ),
                    simpleModalDropdown(
                      'Categoría',
                      _selectedCategory,
                      categories,
                      (v) => _selectedCategory = v,
                    ),
                    simpleModalDropdown(
                      'Tipo',
                      _selectedType,
                      types,
                      (v) => _selectedType = v,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: CustomDropdown<int?>(
                        label: 'Rep. Comercial',
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todos'),
                          ),
                          ..._users.map(
                            (u) => DropdownMenuItem<int?>(
                              value: u['AD_User_ID'] ?? u['id'],
                              child: Text(
                                u['Name'] ?? 'Sin Nombre',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        value: _selectedSalesRepId,
                        onChanged: (val) {
                          _selectedSalesRepId = val;
                          setModalState(() {});
                        },
                      ),
                    ),
                    simpleModalDropdown(
                      'Estado',
                      _selectedStatus,
                      _statusIdMap.keys.toList()..sort(),
                      (v) => _selectedStatus = v,
                    ),
                    simpleModalDropdown('Prioridad', _selectedLevel, [
                      'Urgente',
                      'Alta',
                      'Media',
                      'Baja',
                      'Menor',
                    ], (v) => _selectedLevel = v),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _applyFilters(resetPage: true);
                  },
                  child: const Text('Aplicar y Cerrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSearchAndFilters() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: SizedBox(
              width: double.infinity,
              child: CustomTextField(
                controller: _searchController,
                hintText: 'Buscar por ID o resumen...',
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          Wrap(
            spacing: 16.0,
            runSpacing: 8.0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CustomButton(
                text: 'Filtros',
                onPressed: _showFilterModal,
                icon: Icons.filter_list,
                backgroundColor: _activeFilterCount > 0
                    ? theme.colorScheme.primaryContainer
                    : null,
                textColor: _activeFilterCount > 0
                    ? theme.colorScheme.onPrimaryContainer
                    : null,
              ),
              if (_activeFilterCount > 0)
                Chip(
                  label: Text('$_activeFilterCount'),
                  backgroundColor: theme.colorScheme.primary,
                  labelStyle: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  padding: const EdgeInsets.all(4),
                  visualDensity: VisualDensity.compact,
                ),
              IconButton(
                icon: const Icon(Icons.filter_alt_off),
                tooltip: 'Limpiar filtros',
                onPressed: () {
                  setState(() {
                    _selectedType = null;
                    _selectedStatus = null;
                    _selectedLevel = null;
                    _selectedPhase = null;
                    _selectedTask = null;
                    _selectedCategory = null;
                    _selectedSalesRepId = null;
                  });
                  _searchController.clear();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRequest(dynamic id) async {
    if (!AccessControl.canManageRequests) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes permisos para eliminar solicitudes.'),
        ),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => CustomModal(
        title: 'Confirmar Eliminación',
        content: const Text(
          '¿Está seguro de que desea eliminar esta solicitud?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          CustomButton(
            text: 'Eliminar',
            backgroundColor: Colors.red,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await deleteRequestApi(id);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Solicitud eliminada correctamente')),
          );
          _initData(showLoading: false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al eliminar'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _editRequest(Map<String, dynamic> req) {
    // Use _allProjectRequests instead of _rawRequests
    final processedReq = _allProjectRequests.firstWhere(
      (p) => p['realId'] == req['realId'],
      orElse: () => req,
    );

    showDialog(
      context: context,
      builder: (context) => EditRequestDialog(
        request: processedReq,
        statusIdMap: _statusIdMap,
        priorityMap: priorityMap,
        onSave: () => _initData(showLoading: false),
        onDelete: () =>
            _deleteRequest(processedReq['realId'] ?? processedReq['id']),
      ),
    );
  }
}
