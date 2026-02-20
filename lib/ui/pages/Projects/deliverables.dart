import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:primhub/api/auth_api.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/pages/Projects/project_file_manager.dart';
import 'package:primhub/ui/shared/custom_inputs.dart';
import 'package:primhub/ui/shared/custom_modal.dart';
import 'package:primhub/ui/pages/request/request_functions.dart';
import '../../shared/custom_button.dart';
import '../../widgets/custom_drawer.dart';

class DeliverablesPage extends StatefulWidget {
  const DeliverablesPage({super.key});

  @override
  State<DeliverablesPage> createState() => _DeliverablesPageState();
}

class _DeliverablesPageState extends State<DeliverablesPage> {
  bool _showingFiles = false;
  // Key para acceder a los métodos del ProjectFileManager (refresh, upload, etc.)
  final GlobalKey<ProjectFileManagerState> _fileManagerKey = GlobalKey();

  // State for Projects Tab
  List<dynamic> _projects = [];
  List<Map<String, dynamic>> _requests = [];
  Map<String, dynamic>? _selectedProject;
  bool _isLoadingProjects = false;
  String? _projectsErrorMessage;
  bool _projectsLoaded = false;
  final TextEditingController _searchController = TextEditingController();
  bool _expandAll = false;
  int _expansionKey = 0;
  Map<String, dynamic>? _pendingArgs;
  int? _targetExpandedProjectId;
  bool _isInit = true;
  List<dynamic> _bPartners = [];
  bool _isLoadingBPartners = false;
  List<dynamic> _projectTypes = [];
  bool _isLoadingProjectTypes = false;
  String _currentViewType = ''; // 'Entregables', 'Seguimiento', 'General'

  @override
  void initState() {
    super.initState();
    _fetchRequestsData();
    _fetchProjects();
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
      if (args != null) {
        _pendingArgs = args;
      }
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRequestsData() async {
    try {
      final reqs = await fetchRequest();
      if (mounted) {
        setState(() {
          _requests = reqs;
        });
      }
    } catch (e) {
      debugPrint('Error fetching requests for projects: $e');
    }
  }

  Future<void> _fetchProjects() async {
    setState(() {
      _isLoadingProjects = true;
      _projectsErrorMessage = null;
    });

    String url =
        '${Endpoint.project}?\$expand=C_ProjectPhase(\$expand=C_ProjectTask)';

    try {
      var response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
      );

      if (response.statusCode == 401) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          response = await http.get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': Token.token,
            },
          );
        } else {
          if (mounted) {
            setState(() => _isLoadingProjects = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Sesión expirada. Por favor inicie sesión nuevamente.',
                ),
                backgroundColor: Colors.red,
              ),
            );
            context.go('/login');
          }
          return;
        }
      }

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _projects = data['records'];
            _isLoadingProjects = false;
            _projectsLoaded = true;
          });
          _applyPendingArgs();
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingProjects = false;
            _projectsErrorMessage =
                'Error al cargar proyectos: ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProjects = false;
          _projectsErrorMessage = 'Error de conexión. Verifique su internet.';
        });
      }
    }
  }

  Future<bool> _tryRefreshToken() async {
    if (Token.refreshToken == null) return false;
    final response = await refreshToken(Token.refreshToken!);
    if (response.containsKey('token')) {
      Token.auth = response['token'];
      if (response.containsKey('refresh_token')) {
        Token.refreshToken = response['refresh_token'];
      }
      return true;
    }
    return false;
  }

  void _applyPendingArgs() {
    if (_pendingArgs == null) return;
    final projectId = _pendingArgs!['projectId'];
    final view = _pendingArgs!['view'];

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
    _pendingArgs = null;
  }

  Future<void> _fetchBPartners() async {
    if (_bPartners.isNotEmpty) return;
    setState(() => _isLoadingBPartners = true);
    try {
      final response = await http.get(
        Uri.parse(
          '${Endpoint.cBPartner}?\$select=id,Name,Value&\$orderby=Name',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() => _bPartners = data['records']);
      }
    } catch (_) {}
    setState(() => _isLoadingBPartners = false);
  }

  Future<void> _fetchProjectTypes() async {
    if (_projectTypes.isNotEmpty) return;
    setState(() => _isLoadingProjectTypes = true);
    try {
      final response = await http.get(
        Uri.parse(
          '${Endpoint.baseUrl}/api/v1/models/C_ProjectType?\$select=id,Name&\$orderby=Name',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() => _projectTypes = data['records']);
      }
    } catch (_) {}
    setState(() => _isLoadingProjectTypes = false);
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
      floatingActionButton: _showingFiles
          ? FloatingActionButton(
              onPressed: () =>
                  _fileManagerKey.currentState?.pickAndUploadFile(),
              tooltip: 'Subir Archivo',
              child: const Icon(Icons.upload_file),
            )
          : FloatingActionButton(
              onPressed: _createProjectDialog,
              tooltip: 'Crear Proyecto',
              child: const Icon(Icons.add),
            ),
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
          if (_showingFiles)
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
                _fetchProjects();
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
      final createUrl = Uri.parse(Endpoint.project);
      final Map<String, dynamic> payload = {
        'Value': value,
        'Name': name,
        'Description': description,
      };

      if (bpId != null) {
        payload['C_BPartner_ID'] = {'id': bpId};
      }
      if (dateContract.isNotEmpty) {
        payload['DateContract'] = dateContract.contains('T')
            ? dateContract
            : '${dateContract}T00:00:00Z';
      }
      if (dateFinish.isNotEmpty) {
        payload['DateFinish'] = dateFinish.contains('T')
            ? dateFinish
            : '${dateFinish}T00:00:00Z';
      }
      if (projectTypeId != null) {
        payload['C_ProjectType_ID'] = {'id': projectTypeId};
      }

      final response = await http.post(
        createUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proyecto creado correctamente')),
        );
        _fetchProjects();
      } else {
        debugPrint('Error create project: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear proyecto: ${response.statusCode}'),
          ),
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
      final url = Uri.parse('${Endpoint.baseUrl}/api/v1/models/C_ProjectPhase');
      final body = {
        'C_Project_ID': {'id': projectId},
        'Name': name,
        'Description': description,
        'IsActive': true,
      };
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        _fetchProjects();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear fase: ${response.statusCode}'),
          ),
        );
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
      final url = Uri.parse('${Endpoint.baseUrl}/api/v1/models/C_ProjectTask');
      final body = {
        'C_ProjectPhase_ID': {'id': phaseId},
        'Name': name,
        'Description': description,
        'IsActive': true,
      };
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        _fetchProjects();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear tarea: ${response.statusCode}'),
          ),
        );
        setState(() => _isLoadingProjects = false);
      }
    } catch (e) {
      setState(() => _isLoadingProjects = false);
    }
  }

  Future<void> _toggleComplete(
    String type,
    int id,
    bool currentStatus,
    Map<String, dynamic>? parent,
  ) async {
    setState(() => _isLoadingProjects = true);
    try {
      String endpoint = '';
      if (type == 'project') endpoint = Endpoint.project;
      if (type == 'phase')
        endpoint = '${Endpoint.baseUrl}/api/v1/models/C_ProjectPhase';
      if (type == 'task')
        endpoint = '${Endpoint.baseUrl}/api/v1/models/C_ProjectTask';

      final url = Uri.parse('$endpoint/$id');
      // Assuming IsComplete is the field. Some systems use 'Processed' or a Status ID.
      // Using IsComplete based on context usage.
      final body = {'IsComplete': !currentStatus};

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Logic for cascading checks
        if (type == 'task' && !currentStatus == true && parent != null) {
          // Task marked as complete. Check if all tasks in phase are complete.
          // We need to refresh data first to get latest state or check locally.
          // For simplicity and correctness, we refresh and then check logic or do it optimistically.
          // Let's refresh to be safe, then check parent.
          await _fetchProjects();
          // Find the updated task and its phase
          // This logic is complex to do perfectly without backend triggers, but we can try.
          // A simpler approach requested: "si esta check todas las tareas de una fase se pone en check la fase"
          // We can do this by checking the local state of siblings *before* refresh or after.
          // Let's do it after refresh.
          _checkCascadingCompletion();
        } else if (type == 'phase' && !currentStatus == true) {
          await _fetchProjects();
          _checkCascadingCompletion();
        } else {
          _fetchProjects();
        }
      } else {
        setState(() => _isLoadingProjects = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoadingProjects = false);
    }
  }

  void _checkCascadingCompletion() {
    // Iterate projects to check if phases/projects need update
    // This runs after _fetchProjects so _projects has latest data
    for (var proj in _projects) {
      bool projChanged = false;
      bool allPhasesComplete = true;
      List phases = proj['C_ProjectPhase'] ?? [];

      if (phases.isEmpty) allPhasesComplete = false;

      for (var phase in phases) {
        bool phaseChanged = false;
        bool allTasksComplete = true;
        List tasks = phase['C_ProjectTask'] ?? [];

        if (tasks.isEmpty) allTasksComplete = false;

        for (var task in tasks) {
          if (task['IsComplete'] != true) {
            allTasksComplete = false;
            break;
          }
        }

        if (tasks.isNotEmpty &&
            allTasksComplete &&
            phase['IsComplete'] != true) {
          // Update Phase
          _toggleComplete('phase', phase['id'], false, null); // false -> true
          phaseChanged = true;
        }

        if (phase['IsComplete'] != true && !phaseChanged) {
          allPhasesComplete = false;
        }
      }

      if (phases.isNotEmpty &&
          allPhasesComplete &&
          proj['IsComplete'] != true) {
        // Update Project (Assuming IsComplete exists on Project, or maybe ProjectStatus)
        // If Project uses IsComplete:
        // _toggleComplete('project', proj['id'], false, null);
      }
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
      // Reuse create logic or make generic update. For brevity, generic update here:
      setState(() => _isLoadingProjects = true);
      try {
        String endpoint = type == 'project'
            ? Endpoint.project
            : type == 'phase'
            ? '${Endpoint.baseUrl}/api/v1/models/C_ProjectPhase'
            : '${Endpoint.baseUrl}/api/v1/models/C_ProjectTask';
        await http.put(
          Uri.parse('$endpoint/$id'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': Token.token,
          },
          body: jsonEncode({
            'Name': nameController.text,
            'Description': descController.text,
          }),
        );
        _fetchProjects();
      } catch (_) {
        setState(() => _isLoadingProjects = false);
      }
    }
  }

  Widget _buildProjectsView() {
    if (_isLoadingProjects) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_projectsErrorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _projectsErrorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }
    if (_projects.isEmpty) {
      return const Center(child: Text('No tienes proyectos activos.'));
    }

    final filteredProjects = _projects.where((project) {
      final name = (project['Name'] ?? '').toString().toLowerCase();
      final search = _searchController.text.toLowerCase();
      return name.contains(search);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              CustomTextField(
                controller: _searchController,
                hintText: 'Buscar proyecto...',
                prefixIcon: const Icon(Icons.search),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _expandAll = true;
                      _expansionKey++;
                    }),
                    icon: const Icon(Icons.unfold_more),
                    label: const Text('Expandir todo'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _expandAll = false;
                      _expansionKey++;
                    }),
                    icon: const Icon(Icons.unfold_less),
                    label: const Text('Contraer todo'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredProjects.isEmpty
              ? const Center(child: Text('No se encontraron proyectos.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredProjects.length,
                  itemBuilder: (context, index) {
                    return _buildProjectCard(filteredProjects[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    final phases = project['C_ProjectPhase'] as List? ?? [];
    final directTasks = project['C_ProjectTask'] as List? ?? [];
    final String name = project['Name'] ?? 'Proyecto sin nombre';
    final String description = project['Description'] ?? '';
    final bool isComplete =
        project['IsComplete'] == true; // Assuming project has IsComplete

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        key: Key('${project['id']}-$_expansionKey'),
        initiallyExpanded:
            _expandAll || (project['id'] == _targetExpandedProjectId),
        leading: CircleAvatar(
          backgroundColor: isComplete
              ? Colors.green
              : Theme.of(context).colorScheme.primary,
          child: Icon(
            isComplete ? Icons.check : Icons.assignment,
            color: Colors.white,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.folder, size: 20),
              tooltip: 'Entregables',
              onPressed: () {
                setState(() {
                  _selectedProject = project;
                  _currentViewType = 'Entregables';
                  _showingFiles = true;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.timeline, size: 20),
              tooltip: 'Seguimiento',
              onPressed: () {
                setState(() {
                  _selectedProject = project;
                  _currentViewType = 'Seguimiento';
                  _showingFiles = true;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.description, size: 20),
              tooltip: 'General',
              onPressed: () {
                setState(() {
                  _selectedProject = project;
                  _currentViewType = 'General';
                  _showingFiles = true;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () =>
                  _editItemDialog('project', project['id'], name, description),
              tooltip: 'Editar Proyecto',
            ),
          ],
        ),
        subtitle: description.isNotEmpty
            ? Text(description, maxLines: 2, overflow: TextOverflow.ellipsis)
            : null,
        children: [
          if (phases.isNotEmpty)
            ...phases.map((phase) => _buildPhaseItem(phase, project)),
          if (directTasks.isNotEmpty)
            ...directTasks.map((task) => _buildTaskItem(task, null)),
          if (phases.isEmpty && directTasks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'No hay detalles de fases o tareas disponibles.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CustomButton(
              text: 'Agregar Fase',
              icon: Icons.add,
              onPressed: () => _createPhaseDialog(project['id']),
              width: double.infinity,
              backgroundColor: Colors.grey.shade200,
              textColor: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPhaseItem(
    Map<String, dynamic> phase,
    Map<String, dynamic> project,
  ) {
    final tasks = phase['C_ProjectTask'] as List? ?? [];
    final bool isComplete = phase['IsComplete'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: Card(
        elevation: 0,
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        child: ExpansionTile(
          leading: Icon(
            isComplete ? Icons.check_circle : Icons.flag,
            color: isComplete ? Colors.green : Colors.grey,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  phase['Name'] ?? 'Fase',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: () => _editItemDialog(
                  'phase',
                  phase['id'],
                  phase['Name'] ?? '',
                  phase['Description'] ?? '',
                ),
              ),
            ],
          ),
          subtitle: Text('${tasks.length} Tareas'),
          children: [
            ...tasks
                .map((task) => _buildTaskItem(task, phase, isNested: true))
                .toList(),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Agregar Tarea'),
                onPressed: () => _createTaskDialog(phase['id']),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(
    Map<String, dynamic> task,
    Map<String, dynamic>? phase, {
    bool isNested = false,
  }) {
    final bool isComplete = task['IsComplete'] == true;
    final String taskUUID = task['UUID'] ?? '';

    // Buscar solicitudes relacionadas por UUID
    final relatedRequests = _requests.where((r) {
      return r['Record_UU'] != null &&
          r['Record_UU'].toString() == taskUUID &&
          taskUUID.isNotEmpty;
    }).toList();

    if (relatedRequests.isNotEmpty) {
      return ExpansionTile(
        tilePadding: EdgeInsets.only(left: isNested ? 16.0 : 16.0, right: 16.0),
        leading: Icon(
          isComplete ? Icons.check_circle : Icons.circle_outlined,
          size: 18,
          color: isComplete ? Colors.green : Colors.blueGrey,
        ),
        title: Text(
          task['Name'] ?? 'Tarea',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        subtitle: task['Description'] != null
            ? Text(
                task['Description'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              )
            : null,
        children: relatedRequests.map((req) => _buildRequestItem(req)).toList(),
      );
    }

    return ListTile(
      contentPadding: EdgeInsets.only(
        left: isNested ? 16.0 : 16.0,
        right: 16.0,
      ),
      leading: Icon(
        isComplete ? Icons.check_circle : Icons.circle_outlined,
        size: 18,
        color: isComplete ? Colors.green : Colors.blueGrey,
      ),
      title: Text(
        task['Name'] ?? 'Tarea',
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: task['Description'] != null
          ? Text(
              task['Description'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            )
          : null,
      dense: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 16),
            onPressed: () => _editItemDialog(
              'task',
              task['id'],
              task['Name'] ?? '',
              task['Description'] ?? '',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestItem(Map<String, dynamic> req) {
    final bool isClosed =
        req['R_Status_Name'] == '9_Final Close' || req['R_Status_ID'] == 103;

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 32.0, right: 16.0),
      leading: const Icon(
        Icons.confirmation_number_outlined,
        size: 16,
        color: Colors.indigo,
      ),
      title: Text(
        req['Summary'] ?? 'Solicitud',
        style: const TextStyle(fontSize: 12),
      ),
      subtitle: Text(
        '${req['DocumentNo']} - ${req['R_Status_Name']}',
        style: const TextStyle(fontSize: 10),
      ),
      trailing: isClosed
          ? const Icon(Icons.check_circle, size: 18, color: Colors.green)
          : const Icon(Icons.pending_actions, size: 18, color: Colors.orange),
      dense: true,
    );
  }
}
