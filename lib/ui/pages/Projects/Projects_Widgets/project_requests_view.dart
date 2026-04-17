import 'package:flutter/material.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/ui/pages/Support/Requests/edit_request_dialog.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/api/global_cache.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/ui/pages/Projects/Projects_Widgets/uu_requests_data_table.dart';

class ProjectRequestsView extends StatefulWidget {
  final String? filterType;
  final String? filterStatus;
  final String? filterCompliance;
  final int? projectId;
  final List<String>? taskUUIDs;
  final bool showAllGroups;

  const ProjectRequestsView({super.key, this.filterType, this.filterStatus, this.filterCompliance, this.projectId, this.taskUUIDs, this.showAllGroups = false});

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
  String? _selectedStatus;
  int? _selectedUserId;
  String? _selectedLevel;
  String? _selectedPhase;
  String? _selectedTask;
  String? _selectedCategory;
  int? _selectedSalesRepId;
  bool _isAscending = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => _applyFilters());
    _initData();
  }

  Future<void> _initData({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) setState(() => _isLoading = true);

    _users = GlobalCache.users;
    _statusIdMap = GlobalCache.statuses;

    await _loadRequests();
  }

  Future<void> _loadRequests() async {
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
      final project = GlobalCache.projects.firstWhere((p) => p['id']?.toString() == widget.projectId?.toString(), orElse: () => <String, dynamic>{});

      if (project.isNotEmpty) {
        _projectName = project['Name'] ?? '';

        final phases = List<dynamic>.from(project['C_ProjectPhase'] as List? ?? []);
        final directTasks = List<dynamic>.from(project['C_ProjectTask'] as List? ?? []);

        for (var phase in phases) {
          final phaseName = phase['Name'] ?? 'Fase';
          final phaseIdStr = phase['id']?.toString();
          if (phaseIdStr != null) {
            idToPhaseName[phaseIdStr] = phaseName;
          }
          final tasks = List<dynamic>.from(phase['C_ProjectTask'] as List? ?? []);
          for (var task in tasks) {
            final taskName = task['Name'] ?? 'Tarea';
            final taskIdStr = task['id']?.toString();
            if (taskIdStr != null) {
              taskUUIDs.add(taskIdStr.toLowerCase());
              taskIdToTaskName[taskIdStr] = taskName;
              taskIdToPhaseName[taskIdStr] = phaseName;
            }
            final uuidList = [task['C_ProjectTask_UU'], task['Record_UU'], task['UUID'], task['uuid'], task['uid']];
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
          final uuidList = [task['C_ProjectTask_UU'], task['Record_UU'], task['UUID'], task['uuid'], task['uid']];
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

    // 2. Filtrado con lógica de respaldo (Fallback)
    List<Map<String, dynamic>> rawFound = GlobalCache.requests.where((req) {
      if (req['IsActive'] == false || req['IsActive'] == 'N') return false;

      final rProjectId = (req['C_Project_ID'] is Map ? req['C_Project_ID']['id'] : req['C_Project_ID'])?.toString();
      final rRecordUU = req['Record_UU']?.toString().toLowerCase();
      final rTaskId = (req['C_ProjectTask_ID'] is Map ? req['C_ProjectTask_ID']['id'] : req['C_ProjectTask_ID'])?.toString();

      // COINCIDENCIA POR PROYECTO DIRECTO
      if (widget.projectId != null && rProjectId == widget.projectId.toString()) {
        return true;
      }

      // COINCIDENCIA POR UUID DE TAREA
      if (rRecordUU != null && taskUUIDs.contains(rRecordUU)) {
        return true;
      }

      // COINCIDENCIA POR ID DE TAREA (Si iDempiere lo manda como ID)
      if (rTaskId != null && taskUUIDs.contains(rTaskId.toLowerCase())) {
        return true;
      }

      return false;
    }).toList();

    print("DEBUG: Solicitudes encontradas tras filtro: ${rawFound.length}");

    // 3. Procesar para la tabla
    final processed = await processRequests(rawFound, _statusIdMap);
    List<Map<String, dynamic>> finalReqs = [];

    for (var req in processed['requests']) {
      final reqUU = req['recordUU']?.toString().toLowerCase();
      final rawReq = req['original'] ?? req;
      final rTaskId = (rawReq['C_ProjectTask_ID'] is Map ? rawReq['C_ProjectTask_ID']['id'] : rawReq['C_ProjectTask_ID'])?.toString();
      final rPhaseId = (rawReq['C_ProjectPhase_ID'] is Map ? rawReq['C_ProjectPhase_ID']['id'] : rawReq['C_ProjectPhase_ID'])?.toString();

      String taskName = 'General / Proyecto';
      String phaseName = '-';

      if (reqUU != null && uuidToTaskName.containsKey(reqUU)) {
        taskName = uuidToTaskName[reqUU]!;
        phaseName = uuidToPhaseName[reqUU] ?? '-';
      } else if (rTaskId != null && taskIdToTaskName.containsKey(rTaskId)) {
        taskName = taskIdToTaskName[rTaskId]!;
        phaseName = taskIdToPhaseName[rTaskId] ?? '-';
      } else {
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
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final filtered = _allProjectRequests.where((req) {
      if (_selectedType != null && req['type'] != _selectedType) return false;
      if (_selectedStatus != null && req['status'] != _selectedStatus) return false;
      if (_selectedLevel != null && req['level'] != _selectedLevel) return false;
      if (_selectedPhase != null && req['phaseName'] != _selectedPhase) return false;
      if (_selectedTask != null && req['taskName'] != _selectedTask) return false;
      if (_selectedCategory != null && req['category'] != _selectedCategory) return false;
      if (_selectedSalesRepId != null && req['salesRepId'] != _selectedSalesRepId) return false;

      if (_searchController.text.isNotEmpty) {
        final search = _searchController.text.toLowerCase();
        return req['id'].toString().toLowerCase().contains(search) || (req['descriptionClean'] ?? '').toString().toLowerCase().contains(search);
      }
      return true;
    }).toList();

    setState(() {
      _requests = filtered.map((req) {
        final map = Map<String, dynamic>.from(req['original']);
        map['taskName'] = req['taskName'];
        map['phaseName'] = req['phaseName'];
        map['id'] = req['id'];
        map['realId'] = req['realId'];
        return map;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_projectName.isNotEmpty ? 'Solicitudes del Proyecto $_projectName' : 'Solicitudes de Proyecto'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _initData)],
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _requests.isEmpty
                ? const Center(child: Text('No se encontraron solicitudes vinculadas.'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: RequestsDataTable(requests: _requests, statusIdMap: _statusIdMap, priorityMap: priorityMap, onEdit: (req) => _editRequest(req), onRefresh: () => _initData(showLoading: false), showProjectContext: true),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    // Extracción de datos únicos para alimentar los Dropdowns de forma dinámica
    final phases = _allProjectRequests.map((e) => e['phaseName'].toString()).where((e) => e != '-').toSet().toList()..sort();
    final tasks = _allProjectRequests.where((e) => _selectedPhase == null || e['phaseName'] == _selectedPhase).map((e) => e['taskName'].toString()).where((e) => e != 'General / Proyecto').toSet().toList()..sort();
    final categories = _allProjectRequests.map((e) => e['category'].toString()).where((e) => e.isNotEmpty && e != 'null').toSet().toList()..sort();
    final types = _allProjectRequests.map((e) => e['type'].toString()).where((e) => e.isNotEmpty && e != 'null').toSet().toList()..sort();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: CustomTextField(controller: _searchController, hintText: 'Buscar por ID o resumen...', prefixIcon: const Icon(Icons.search)),
              ),
              const SizedBox(width: 16),
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
                  _searchController.clear(); // Esto dispara _applyFilters automáticamente
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 200,
                child: _simpleDropdown(
                  'Fase',
                  _selectedPhase,
                  phases,
                  (v) => setState(() {
                    _selectedPhase = v;
                    _selectedTask = null;
                  }),
                ),
              ),
              SizedBox(width: 200, child: _simpleDropdown('Tarea', _selectedTask, tasks, (v) => setState(() => _selectedTask = v))),
              SizedBox(width: 200, child: _simpleDropdown('Categoría', _selectedCategory, categories, (v) => setState(() => _selectedCategory = v))),
              SizedBox(width: 200, child: _simpleDropdown('Tipo', _selectedType, types, (v) => setState(() => _selectedType = v))),
              SizedBox(
                width: 200,
                child: CustomDropdown<int?>(
                  label: 'Rep. Comercial',
                  value: _selectedSalesRepId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    ..._users.map(
                      (u) => DropdownMenuItem<int?>(
                        value: u['AD_User_ID'] ?? u['id'],
                        child: Text(u['Name'] ?? 'Sin Nombre', overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedSalesRepId = val);
                    _applyFilters();
                  },
                ),
              ),
              SizedBox(width: 200, child: _simpleDropdown('Estado', _selectedStatus, _statusIdMap.keys.toList()..sort(), (v) => setState(() => _selectedStatus = v))),
              SizedBox(width: 150, child: _simpleDropdown('Prioridad', _selectedLevel, ['Urgente', 'Alta', 'Media', 'Baja', 'Menor'], (v) => setState(() => _selectedLevel = v))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _simpleDropdown(String label, String? value, List<String> items, Function(String?) onChanged) {
    return CustomDropdown<String?>(
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
        _applyFilters();
      },
    );
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
    // Rescatamos la versión ya procesada del ticket para que el diálogo reciba los campos correctos ('level', 'status', etc.)
    final processedReq = _allProjectRequests.firstWhere((p) => p['realId'] == req['realId'], orElse: () => req);

    showDialog(
      context: context,
      builder: (context) => EditRequestDialog(request: processedReq, statusIdMap: _statusIdMap, priorityMap: priorityMap, onSave: () => _initData(showLoading: false), onDelete: () => _deleteRequest(processedReq['realId'] ?? processedReq['id'])),
    );
  }
}
