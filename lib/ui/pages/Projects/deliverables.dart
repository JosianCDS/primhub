import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/api/auth_api.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/pages/Projects/projects_logic.dart';
import 'package:primhub/ui/pages/Projects/project_file_manager.dart';
import 'package:primhub/ui/pages/request/create_request_dialog.dart';
import 'package:primhub/ui/pages/request/edit_request_dialog.dart';
import 'package:primhub/ui/shared/custom_inputs.dart';
import 'package:primhub/ui/shared/custom_modal.dart';
import '../../shared/custom_button.dart';
import '../../widgets/custom_drawer.dart';

class DeliverablesPage extends StatefulWidget {
  const DeliverablesPage({super.key});

  @override
  State<DeliverablesPage> createState() => _DeliverablesPageState();
}

class _DeliverablesPageState extends State<DeliverablesPage> {
  bool _showingFiles = false;
  bool _isFileManagerRoot = true;
  // Key para acceder a los métodos del ProjectFileManager (refresh, upload, etc.)
  final GlobalKey<ProjectFileManagerState> _fileManagerKey = GlobalKey();

  // State for Projects Tab
  List<dynamic> _projects = [];
  Map<String, dynamic>? _selectedProject;
  bool _isLoadingProjects = false;
  String? _projectsErrorMessage;
  bool _projectsLoaded = false;
  final TextEditingController _searchController = TextEditingController();
  bool _expandAll = false;
  int _expansionKey = 0;
  int? _targetExpandedProjectId;
  bool _isInit = true;
  List<dynamic> _bPartners = [];
  bool _isLoadingBPartners = false;
  List<dynamic> _projectTypes = [];
  bool _isLoadingProjectTypes = false;
  String _currentViewType = ''; // 'Entregables', 'Seguimiento', 'General'
  final ProjectsLogic _logic = ProjectsLogic();
  Map<String, int> _statusIdMap = {};
  final Map<String, String> _priorityMap = {
    'Urgente': '1',
    'Alta': '3',
    'Media': '5',
    'Baja': '7',
    'Menor': '9',
  };

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _fetchStatuses();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && _projects.isNotEmpty) {
        _applyPendingArgs(args);
      } else if (args != null) {
        // Si los proyectos aún no se han cargado, espera a que se carguen.
      }
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoadingProjects = true;
      _projectsErrorMessage = null;
    });
    try {
      final projects = await _logic.fetchProjects(context);
      if (mounted) {
        setState(() {
          _projects = projects;
          _isLoadingProjects = false;
          _projectsLoaded = true;
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          if (args != null) {
            _applyPendingArgs(args);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProjects = false;
          _projectsErrorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _fetchStatuses() async {
    try {
      final response = await http.get(
        Uri.parse('${Endpoint.baseUrl}/api/v1/models/R_Status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
      );
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final records = jsonResponse['records'] as List;
        if (mounted) {
          setState(() {
            _statusIdMap = {for (var r in records) r['Name']: r['id']};
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProjects = false;
          _projectsErrorMessage = e.toString();
        });
      }
    }
  }

  void _applyPendingArgs(Map<String, dynamic> args) {
    final projectId = args['projectId'];
    final view = args['view'];

    // Usar toString() para asegurar comparación correcta entre int y String si fuera necesario
    final project = _projects.firstWhere(
      (p) => p['id'].toString() == projectId.toString(),
      orElse: () => null,
    );
    if (project == null) return;

    if (view == 'projects') {
      setState(() {
        _targetExpandedProjectId =
            project['id']; // Usar el ID del proyecto encontrado
        _exitFileManager();
        _expansionKey++;
      });
    } else if (view == 'Entregables' ||
        view == 'Seguimiento' ||
        view == 'General') {
      setState(() {
        _selectedProject = project;
        _currentViewType = view;
        _showingFiles = true;
      });
    }
  }

  Future<void> _fetchBPartners() async {
    if (_bPartners.isNotEmpty) return;
    setState(() => _isLoadingBPartners = true);
    _bPartners = await _logic.fetchBPartners();
    setState(() => _isLoadingBPartners = false);
  }

  Future<void> _fetchProjectTypes() async {
    if (_projectTypes.isNotEmpty) return;
    setState(() => _isLoadingProjectTypes = true);
    _projectTypes = await _logic.fetchProjectTypes();
    setState(() => _isLoadingProjectTypes = false);
  }

  void _onShowFiles(Map<String, dynamic> project, String viewType) {
    setState(() {
      _selectedProject = project;
      _currentViewType = viewType;
      _showingFiles = true;
      _isFileManagerRoot = true;
    });
  }

  void _exitFileManager() {
    setState(() {
      _showingFiles = false;
      _selectedProject = null;
      _currentViewType = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      floatingActionButton: _showingFiles && AccessControl.canManageFiles
          ? FloatingActionButton(
              onPressed: () =>
                  _fileManagerKey.currentState?.pickAndUploadFile(),
              tooltip: 'Subir Archivo',
              child: const Icon(Icons.upload_file),
            )
          : null,
      appBar: AppBar(
        title: const Text(
          'Mis Proyectos',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        leading: _showingFiles
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  // Intentar navegar atrás dentro del gestor de archivos
                  final handled =
                      _fileManagerKey.currentState?.navigateBack() ?? false;
                  if (!handled) {
                    // Si no se manejó (estamos en la raíz), salir
                    _exitFileManager();
                  }
                },
              )
            : null,
        actions: [
          if (!_showingFiles)
            IconButton(
              icon: Icon(_expandAll ? Icons.unfold_less : Icons.unfold_more),
              tooltip: _expandAll ? 'Contraer todo' : 'Expandir todo',
              onPressed: () {
                setState(() {
                  _expandAll = !_expandAll;
                  if (!_expandAll) _targetExpandedProjectId = null;
                  _expansionKey++;
                });
              },
            ),
          if (_showingFiles &&
              _isFileManagerRoot &&
              AccessControl.canManageFiles)
            IconButton(
              icon: const Icon(Icons.create_new_folder),
              tooltip: 'Crear Carpeta',
              onPressed: () {
                // Solo permitir crear carpeta si estamos en la raíz (o manejar lógica interna)
                // Por simplicidad, delegamos al widget hijo
                if (_fileManagerKey.currentState?.isRoot() ?? false) {
                  _fileManagerKey.currentState?.createFolderDialog();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Solo se pueden crear carpetas en la raíz.',
                      ),
                    ),
                  );
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_showingFiles) {
                _fileManagerKey.currentState?.refresh();
              } else {
                _loadProjects();
              }
            },
          ),
        ],
      ),
      drawer: _showingFiles ? null : const CustomDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Content Area
            Expanded(
              child: Container(
                color: isDark
                    ? theme.cardColor.withOpacity(0.5)
                    : const Color(0xFFF9FAFB),
                child: _showingFiles
                    ? ProjectFileManager(
                        key: _fileManagerKey,
                        project: _selectedProject!,
                        viewType: _currentViewType,
                        onExit: _exitFileManager,
                        onRootChanged: (isRoot) {
                          if (_isFileManagerRoot != isRoot) {
                            setState(() => _isFileManagerRoot = isRoot);
                          }
                        },
                      )
                    : _buildProjectsView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createProjectDialog() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController valueController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    final TextEditingController dateContractController =
        TextEditingController();
    final TextEditingController dateFinishController = TextEditingController();

    // Cargar datos necesarios
    await Future.wait([_fetchBPartners(), _fetchProjectTypes()]);

    int? selectedBpId;
    if (_bPartners.any((bp) => bp['id'] == User.cBPartnerID)) {
      selectedBpId = User.cBPartnerID;
    }

    String creationType = 'Project'; // Project, Phase, Task
    int? selectedProjectId;
    int? selectedPhaseId;
    int? selectedProjectTypeId;

    if (!mounted) return;

    await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return CustomModal(
            title: 'Nuevo Proyecto',
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: creationType,
                    decoration: InputDecoration(
                      labelText: 'Tipo de Registro',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Project',
                        child: Text('Proyecto'),
                      ),
                      DropdownMenuItem(value: 'Phase', child: Text('Fase')),
                      DropdownMenuItem(value: 'Task', child: Text('Tarea')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setStateDialog(() => creationType = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // --- CAMPOS PARA PROYECTO ---
                  if (creationType == 'Project') ...[
                    CustomTextField(
                      controller: valueController,
                      label: 'Código (Value)',
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: nameController,
                      label: 'Nombre',
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: descController,
                      label: 'Descripción',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selectedProjectTypeId,
                      decoration: InputDecoration(
                        labelText: 'Tipo de Proyecto',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _projectTypes.map<DropdownMenuItem<int>>((pt) {
                        return DropdownMenuItem<int>(
                          value: pt['id'],
                          child: Text(
                            pt['Name'] ?? 'Sin Nombre',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setStateDialog(() => selectedProjectTypeId = val),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selectedBpId,
                      decoration: InputDecoration(
                        labelText: 'Tercero (Cliente)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _bPartners.map<DropdownMenuItem<int>>((bp) {
                        return DropdownMenuItem<int>(
                          value: bp['id'],
                          child: Text(
                            bp['Name'] ?? 'Sin Nombre',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setStateDialog(() => selectedBpId = val),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                dateContractController.text =
                                    "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                              }
                            },
                            child: AbsorbPointer(
                              child: CustomTextField(
                                controller: dateContractController,
                                label: 'Fecha Contrato',
                                hintText: 'YYYY-MM-DD',
                                prefixIcon: const Icon(Icons.calendar_today),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                dateFinishController.text =
                                    "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                              }
                            },
                            child: AbsorbPointer(
                              child: CustomTextField(
                                controller: dateFinishController,
                                label: 'Fecha Fin',
                                hintText: 'YYYY-MM-DD',
                                prefixIcon: const Icon(Icons.calendar_today),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // --- CAMPOS PARA FASE O TAREA ---
                  if (creationType == 'Phase' || creationType == 'Task') ...[
                    DropdownButtonFormField<int>(
                      value: selectedProjectId,
                      decoration: InputDecoration(
                        labelText: 'Proyecto Padre',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _projects.map<DropdownMenuItem<int>>((p) {
                        return DropdownMenuItem<int>(
                          value: p['id'],
                          child: Text(
                            p['Name'] ?? 'Sin Nombre',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setStateDialog(() {
                          selectedProjectId = val;
                          selectedPhaseId =
                              null; // Resetear fase al cambiar proyecto
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (creationType == 'Task') ...[
                    DropdownButtonFormField<int>(
                      value: selectedPhaseId,
                      decoration: InputDecoration(
                        labelText: 'Fase Padre',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: selectedProjectId == null
                          ? []
                          : (_projects.firstWhere(
                                          (p) => p['id'] == selectedProjectId,
                                        )['C_ProjectPhase']
                                        as List? ??
                                    [])
                                .map<DropdownMenuItem<int>>((ph) {
                                  return DropdownMenuItem<int>(
                                    value: ph['id'],
                                    child: Text(
                                      ph['Name'] ?? 'Sin Nombre',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                })
                                .toList(),
                      onChanged: (val) =>
                          setStateDialog(() => selectedPhaseId = val),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (creationType != 'Project') ...[
                    CustomTextField(
                      controller: nameController,
                      label: 'Nombre',
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: descController,
                      label: 'Descripción',
                      maxLines: 2,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              CustomButton(
                text: 'Crear',
                onPressed: () {
                  if (creationType == 'Project') {
                    if (nameController.text.isNotEmpty &&
                        valueController.text.isNotEmpty) {
                      Navigator.pop(context);
                      _createProject(
                        valueController.text,
                        nameController.text,
                        descController.text,
                        selectedBpId,
                        dateContractController.text,
                        dateFinishController.text,
                        selectedProjectTypeId,
                      );
                    }
                  } else if (creationType == 'Phase') {
                    if (selectedProjectId != null &&
                        nameController.text.isNotEmpty) {
                      Navigator.pop(context);
                      _createPhase(
                        selectedProjectId!,
                        nameController.text,
                        descController.text,
                      );
                    }
                  } else if (creationType == 'Task') {
                    if (selectedPhaseId != null &&
                        nameController.text.isNotEmpty) {
                      Navigator.pop(context);
                      _createTask(
                        selectedPhaseId!,
                        nameController.text,
                        descController.text,
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createProject(
    String value,
    String name,
    String description,
    int? bpId,
    String dateContract,
    String dateFinish,
    int? projectTypeId,
  ) async {
    setState(() => _isLoadingProjects = true);

    try {
      final success = await _logic.createProject(
        value: value,
        name: name,
        description: description,
        bpId: bpId,
        dateContract: dateContract,
        dateFinish: dateFinish,
        projectTypeId: projectTypeId,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proyecto creado correctamente')),
        );
        _loadProjects();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al crear proyecto')),
        );
        setState(() => _isLoadingProjects = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _isLoadingProjects = false);
    }
  }

  Future<void> _createPhaseDialog(int projectId) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descController = TextEditingController();

    final bool? create = await showDialog<bool>(
      context: context,
      builder: (context) => CustomModal(
        title: 'Nueva Fase',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(controller: nameController, label: 'Nombre'),
            const SizedBox(height: 16),
            CustomTextField(
              controller: descController,
              label: 'Descripción',
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          CustomButton(
            text: 'Crear',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (create == true && nameController.text.isNotEmpty) {
      _createPhase(projectId, nameController.text, descController.text);
    }
  }

  Future<void> _createPhase(
    int projectId,
    String name,
    String description,
  ) async {
    setState(() => _isLoadingProjects = true);
    try {
      final success = await _logic.createPhase(projectId, name, description);
      if (success) {
        _loadProjects();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error al crear fase')));
        setState(() => _isLoadingProjects = false);
      }
    } catch (e) {
      setState(() => _isLoadingProjects = false);
    }
  }

  Future<void> _createTaskDialog(int phaseId) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descController = TextEditingController();

    final bool? create = await showDialog<bool>(
      context: context,
      builder: (context) => CustomModal(
        title: 'Nueva Tarea',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(controller: nameController, label: 'Nombre'),
            const SizedBox(height: 16),
            CustomTextField(
              controller: descController,
              label: 'Descripción',
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          CustomButton(
            text: 'Crear',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (create == true && nameController.text.isNotEmpty) {
      _createTask(phaseId, nameController.text, descController.text);
    }
  }

  Future<void> _createTask(int phaseId, String name, String description) async {
    setState(() => _isLoadingProjects = true);
    try {
      final success = await _logic.createTask(phaseId, name, description);
      if (success) {
        _loadProjects();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error al crear tarea')));
        setState(() => _isLoadingProjects = false);
      }
    } catch (e) {
      setState(() => _isLoadingProjects = false);
    }
  }

  Future<void> _editItemDialog(
    String type,
    int id,
    String currentName,
    String currentDesc,
  ) async {
    final TextEditingController nameController = TextEditingController(
      text: currentName,
    );
    final TextEditingController descController = TextEditingController(
      text: currentDesc,
    );

    final bool? save = await showDialog<bool>(
      context: context,
      builder: (context) => CustomModal(
        title:
            'Editar ${type == 'project'
                ? 'Proyecto'
                : type == 'phase'
                ? 'Fase'
                : 'Tarea'}',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(controller: nameController, label: 'Nombre'),
            const SizedBox(height: 16),
            CustomTextField(
              controller: descController,
              label: 'Descripción',
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          CustomButton(
            text: 'Guardar',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (save == true) {
      setState(() => _isLoadingProjects = true);
      try {
        final success = await _logic.updateItem(
          type,
          id,
          nameController.text,
          descController.text,
        );
        if (success) {
          _loadProjects();
        } else {
          setState(() => _isLoadingProjects = false);
        }
      } catch (_) {
        setState(() => _isLoadingProjects = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRequestsForTask(
    String? taskUU,
  ) async {
    return await _logic.fetchRequestsForTask(taskUU);
  }

  Widget _buildProjectsView() {
    if (_isLoadingProjects) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_projectsErrorMessage != null) {
      return Center(child: Text('Error: $_projectsErrorMessage'));
    }
    if (_projects.isEmpty) {
      return const Center(child: Text('No hay proyectos.'));
    }

    final filteredProjects = _projects.where((project) {
      final projectName = (project['Name'] as String? ?? '').toLowerCase();
      final searchQuery = _searchController.text.toLowerCase();
      return projectName.contains(searchQuery);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: CustomTextField(
            controller: _searchController,
            hintText: 'Buscar proyecto...',
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredProjects.length,
            itemBuilder: (context, index) {
              return _buildProjectItem(filteredProjects[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProjectItem(Map<String, dynamic> project) {
    final phases = project['C_ProjectPhase'] as List? ?? [];
    final directTasks = project['C_ProjectTask'] as List? ?? [];
    final bool isExpanded =
        _expandAll || _targetExpandedProjectId == project['id'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        key: Key('project-${project['id']}-$_expansionKey'),
        initiallyExpanded: isExpanded,
        leading: const Icon(Icons.folder, color: Color(0xFF4F47E5)),
        title: Row(
          children: [
            Expanded(
              child: Text(
                project['Name'] ?? 'Sin Nombre',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (phases.isNotEmpty) ...[
              const Icon(Icons.layers_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '${phases.length}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (project['Description'] != null)
              Text(
                project['Description'],
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 8),
            // Botones de acción para las diferentes vistas
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildActionButton(
                  Icons.folder_open,
                  'Entregables',
                  Colors.orange,
                  () => _onShowFiles(project, 'Entregables'),
                ),
                const SizedBox(width: 16),
                _buildActionButton(
                  Icons.assignment,
                  'Seguimiento',
                  Colors.blue,
                  () => _onShowFiles(project, 'Seguimiento'),
                ),
                const SizedBox(width: 16),
                _buildActionButton(
                  Icons.assignment_add,
                  'General',
                  Colors.grey,
                  () => _onShowFiles(project, 'General'),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (AccessControl.canCreateProjectItems)
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva Fase'),
                    onPressed: () => _createPhaseDialog(project['id']),
                  ),
                if (AccessControl.canEditProject)
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    tooltip: 'Editar Proyecto',
                    onPressed: () => _editItemDialog(
                      'project',
                      project['id'],
                      project['Name'],
                      project['Description'] ?? '',
                    ),
                  ),
              ],
            ),
          ),
          const Divider(),
          if (phases.isEmpty && directTasks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No hay fases ni tareas registradas.'),
            ),
          ...phases.map((phase) => _buildPhaseItem(phase)),
          ...directTasks.map((task) => _buildTaskItem(task)),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseItem(Map<String, dynamic> phase) {
    final tasks = phase['C_ProjectTask'] as List? ?? [];
    return ExpansionTile(
      key: Key('phase-${phase['id']}-$_expansionKey'),
      initiallyExpanded: _expandAll,
      title: Row(
        children: [
          Expanded(
            child: Text(
              phase['Name'] ?? 'Fase',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (tasks.isNotEmpty) ...[
            const Icon(Icons.task_outlined, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Text('${tasks.length}', style: const TextStyle(color: Colors.grey)),
          ],
        ],
      ),
      subtitle: Text(
        phase['Description'] ?? '',
        style: const TextStyle(fontSize: 12),
      ),
      leading: const Icon(Icons.flag_outlined),
      trailing: AccessControl.canEditProject
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_task, size: 20),
                  tooltip: 'Nueva Tarea',
                  onPressed: () => _createTaskDialog(phase['id']),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _editItemDialog(
                    'phase',
                    phase['id'],
                    phase['Name'],
                    phase['Description'] ?? '',
                  ),
                ),
              ],
            )
          : null,
      children: tasks.map((task) => _buildTaskItem(task)).toList(),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task) {
    final taskId = task['id'];
    final taskName = task['Name'] ?? 'Tarea sin nombre';
    final rawUU =
        task['UUID'] ?? task['uuid'] ?? task['Record_UU'] ?? task['uid'];
    String? taskUU;
    if (rawUU is String) taskUU = rawUU;

    if (taskUU == null) {
      print(
        'DEBUG: Task $taskId ($taskName) has no UUID. Available keys: ${task.keys.toList()}',
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchRequestsForTask(taskUU),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? [];
        final countText = snapshot.connectionState == ConnectionState.waiting
            ? '...'
            : '${requests.length}';

        return ExpansionTile(
          key: Key('task-${taskId}-$_expansionKey'),
          initiallyExpanded: _expandAll,
          leading: const Icon(Icons.task_alt_outlined, size: 20),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  taskName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              if (requests.isNotEmpty) ...[
                const Icon(
                  Icons.description_outlined,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  countText,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ],
          ),
          subtitle: task['Description'] != null
              ? Text(
                  task['Description'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing:
              (AccessControl.canCreateRequests || AccessControl.canEditProject)
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (AccessControl.canCreateRequests)
                      IconButton(
                        icon: const Icon(Icons.add_comment_outlined, size: 20),
                        tooltip: 'Crear Solicitud',
                        onPressed: () async {
                          final result = await showDialog(
                            context: context,
                            builder: (context) =>
                                CreateRequestDialog(linkedRecordUU: taskUU),
                          );
                          if (result == true) {
                            setState(() => _expansionKey++);
                          }
                        },
                      ),
                    if (AccessControl.canEditProject)
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => _editItemDialog(
                          'task',
                          taskId,
                          taskName,
                          task['Description'] ?? '',
                        ),
                      ),
                  ],
                )
              : null,
          children: [
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (requests.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildRequestsTable(requests),
              )
            else
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No hay solicitudes relacionadas.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _deleteRequest(dynamic id) async {
    if (!AccessControl.canManageRequests) return;
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
      try {
        final response = await http.delete(
          Uri.parse('${Endpoint.request}/$id'),
          headers: {'Authorization': Token.token},
        );
        if (response.statusCode == 200 || response.statusCode == 204) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Solicitud eliminada correctamente'),
              ),
            );
            setState(() => _expansionKey++);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al eliminar: ${response.body}')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  void _editRequest(Map<String, dynamic> req) {
    String level = _extractValue(req['Priority']);
    if (level == 'N/A') level = 'Media';
    String status = _extractValue(req['Status']);
    if (status == 'N/A') status = '1_Open';

    int? statusId;
    if (req['Status'] is Map) statusId = req['Status']['id'];

    Color baseColor = Colors.green;
    if (level == 'Urgente')
      baseColor = Colors.purple;
    else if (level == 'Alta')
      baseColor = Colors.red;
    else if (level == 'Media')
      baseColor = Colors.amber.shade800;
    else if (level == 'Menor')
      baseColor = Colors.grey;

    final mappedReq = {
      'id': req['DocumentNo'] ?? req['id'].toString(),
      'realId': req['id'],
      'situation': _extractValue(req['R_RequestType_ID']),
      'description': req['Summary'] ?? '',
      'level': level,
      'status': status,
      'statusId': statusId,
      'time': req['Created'] ?? '',
      'levelColor': baseColor,
      'levelBgColor': baseColor.withOpacity(0.2),
      'statusColor': Colors.grey,
      'dateStartPlan': req['DateStartPlan'] ?? '',
      'dateCompletePlan': req['DateCompletePlan'] ?? '',
      'startTime': req['StartTime'] ?? '',
      'endTime': req['EndTime'] ?? '',
      'qtyPlan': req['QtyPlan']?.toString() ?? '',
      'startDate': req['StartDate'],
      'closeDate': req['CloseDate'],
      'userName': _extractValue(req['AD_User_ID']),
      'bpName': _extractValue(req['C_BPartner_ID']),
    };

    showDialog(
      context: context,
      builder: (context) => EditRequestDialog(
        request: mappedReq,
        statusIdMap: _statusIdMap,
        priorityMap: _priorityMap,
        onSave: () {
          setState(() => _expansionKey++);
        },
        onDelete: () => _deleteRequest(req['id']),
      ),
    );
  }

  String _extractValue(dynamic val) {
    if (val == null) return 'N/A';
    if (val is String) return val;
    if (val is Map)
      return val['identifier']?.toString() ?? val['name']?.toString() ?? 'N/A';
    return val.toString();
  }

  Widget _buildRequestsTable(List<Map<String, dynamic>> requests) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        headingRowHeight: 30,
        dataRowMinHeight: 30,
        dataRowMaxHeight: 40,
        columns: const [
          DataColumn(label: Text('Ticket')),
          DataColumn(label: Text('Resumen')),
          DataColumn(label: Text('Estado')),
          DataColumn(label: Text('Prioridad')),
          DataColumn(label: Text('Fecha Fin Plan')),
        ],
        rows: requests.map((req) {
          return DataRow(
            onSelectChanged: (selected) {
              if (selected == true) {
                if (AccessControl.canManageRequests) {
                  _editRequest(req);
                } else if (AccessControl.canViewRequestDetails) {
                  _showRequestDetails(req);
                }
              }
            },
            cells: [
              DataCell(Text(req['id'].toString())),
              DataCell(
                Text(() {
                  final text = _extractValue(req['Summary']);
                  return text.length > 35
                      ? '${text.substring(0, 35)}...'
                      : text;
                }()),
              ),
              DataCell(Text(_extractValue(req['Status']))),
              DataCell(Text(_extractValue(req['Priority']))),
              DataCell(
                Text(req['DateCompletePlan']?.toString().split('T')[0] ?? ''),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showRequestDetails(Map<String, dynamic> req) {
    final summary = req['Summary'] ?? '';
    final status = _extractValue(req['Status'] ?? req['R_Status_ID']);
    final priority = _extractValue(req['Priority']);
    final dateStart = req['DateStartPlan']?.toString().split('T')[0] ?? '';
    final dateComplete =
        req['DateCompletePlan']?.toString().split('T')[0] ?? '';
    final qtyPlan = req['QtyPlan']?.toString() ?? '0';

    showDialog(
      context: context,
      builder: (context) => CustomModal(
        title: 'Detalle Solicitud ${req['DocumentNo'] ?? req['id']}',
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: TextEditingController(text: summary),
                label: 'Resumen',
                readOnly: true,
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: TextEditingController(text: status),
                      label: 'Estado',
                      readOnly: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      controller: TextEditingController(text: priority),
                      label: 'Prioridad',
                      readOnly: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: TextEditingController(text: dateStart),
                      label: 'Fecha Inicio',
                      readOnly: true,
                      prefixIcon: const Icon(Icons.calendar_today),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      controller: TextEditingController(text: dateComplete),
                      label: 'Fecha Fin',
                      readOnly: true,
                      prefixIcon: const Icon(Icons.calendar_today),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: TextEditingController(text: qtyPlan),
                label: 'Horas Planificadas',
                readOnly: true,
                prefixIcon: const Icon(Icons.timer),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
