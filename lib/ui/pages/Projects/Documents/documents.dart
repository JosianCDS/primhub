import 'package:flutter/material.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/ui/pages/Projects/Documents/project_file_manager.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/ui/pages/Projects/Projects_Widgets/project_item.dart';
import 'package:primhub/ui/pages/Projects/Documents/project_form_page.dart';
import '../../../widgets/custom_drawer.dart';

class DeliverablesPage extends StatefulWidget {
  const DeliverablesPage({super.key});

  @override
  State<DeliverablesPage> createState() => _DeliverablesPageState();
}

class _DeliverablesPageState extends State<DeliverablesPage> {
  bool _showingFiles = false;
  bool _isFileManagerRoot = true;
  final GlobalKey<ProjectFileManagerState> _fileManagerKey = GlobalKey();

  List<dynamic> _projects = [];
  Map<String, dynamic>? _selectedProject;
  bool _isLoadingProjects = false;
  String? _projectsErrorMessage;
  final TextEditingController _searchController = TextEditingController();

  // FILTROS DE ADMINISTRADOR
  int? _filterBPartnerId;
  // Usamos el ID del usuario logueado desde la clase Token/User
  int? _filterSalesRepId = User.userID; // Verifica si en tu clase Token es userID o User.userID
  bool _showInactive = false;
  bool _viewingInactive = false;

  bool _expandAll = false;
  int? _targetExpandedProjectId;
  bool _isInit = true;
  String _currentViewType = '';
  final ProjectsLogic _logic = ProjectsLogic();

  Map<String, int> _statusIdMap = {};
  final Map<String, String> _priorityMap = {'Urgente': '1', 'Alta': '3', 'Media': '5', 'Baja': '7', 'Menor': '9'};
  Map<int, Map<String, dynamic>> _projectStats = {}; // Almacenar stats

  @override
  void initState() {
    super.initState();
    if (AccessControl.isProject && User.cBPartnerID != null) {
      _filterBPartnerId = User.cBPartnerID;
      _filterSalesRepId = null; // Disable sales rep filter for client users
    }
    _loadProjects();
    _fetchStatuses();
    _searchController.addListener(() => setState(() {}));
  }

  // Carga de proyectos con filtros aplicados
  Future<void> _loadProjects() async {
    if (!mounted) return;
    setState(() {
      _isLoadingProjects = true;
      _projectsErrorMessage = null;
    });
    try {
      // CORRECCIÓN: Se pasa 'context' como primer argumento según tu ProjectsLogic
      final projects = await _logic.fetchProjects(context, bPartnerId: _filterBPartnerId, salesRepId: _filterSalesRepId, showInactive: _showInactive, onlyInactive: _viewingInactive);

      if (mounted) {
        setState(() {
          _projects = projects;
          // Cargar stats en segundo plano para no bloquear
          _loadProjectStats();

          _isLoadingProjects = false;
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          if (args != null && _isInit) {
            _applyPendingArgs(args);
            _isInit = false;
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

  Future<void> _loadProjectStats() async {
    // Implementación simplificada o llamada a lógica compartida
    // Por ahora, para no duplicar código complejo de HomeController aquí,
    // podrías mover la lógica de 'loadDocumentStats' a DocumentsLogic.
    // Asumiremos que DocumentsLogic tiene un método para esto o lo añadimos.
    // Ver paso 7.
  }

  Future<void> _fetchStatuses() async {
    final statuses = await DocumentsLogic.fetchStatuses();
    if (mounted) {
      setState(() {
        _statusIdMap = {for (var s in statuses) s['name'].toString(): int.tryParse(s['id'].toString()) ?? 0};
      });
    }
  }

  // Navegación al formulario (Crear/Editar)
  Future<void> _navigateToForm({Map<String, dynamic>? project}) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => ProjectFormPage(project: project)));

    if (result == true) {
      _loadProjects();
    }
  }

  void _applyPendingArgs(Map<String, dynamic> args) {
    final projectId = args['projectId'];
    final view = args['view'];
    final project = _projects.firstWhere((p) => p['id'].toString() == projectId.toString(), orElse: () => null);
    if (project == null) return;

    if (view == 'projects') {
      setState(() {
        _targetExpandedProjectId = project['id'];
        _expandAll = false;
        _exitFileManager();
      });
    } else {
      _onShowFiles(project, view);
    }
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

  // Métodos de fases y tareas
  Future<void> _createPhase(int projectId, String name, String description) async {
    setState(() {
      _isLoadingProjects = true;
      _targetExpandedProjectId = projectId; // Asegurar que este proyecto se expanda
    });
    final success = await _logic.createPhase(projectId, name, description);
    if (success) {
      _loadProjects();
    } else {
      if (mounted) setState(() => _isLoadingProjects = false);
    }
  }

  Future<void> _createTask(int phaseId, String name, String description) async {
    // Necesitamos el ID del proyecto para mantenerlo expandido.
    // Buscamos el proyecto que contiene esta fase.
    final project = _projects.firstWhere((p) => (p['C_ProjectPhase'] as List? ?? []).any((ph) => ph['id'] == phaseId), orElse: () => null);
    setState(() {
      _isLoadingProjects = true;
      if (project != null) _targetExpandedProjectId = project['id'];
    });
    final success = await _logic.createTask(phaseId, name, description);
    if (success) {
      _loadProjects();
    } else {
      if (mounted) setState(() => _isLoadingProjects = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_viewingInactive ? 'Bitácora de Proyectos' : 'Mis Proyectos', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        leading: _showingFiles
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (!(_fileManagerKey.currentState?.navigateBack() ?? false)) _exitFileManager();
                },
              )
            : null,
        actions: [
          if (!_showingFiles) ...[
            if (!AccessControl.isProject)
              IconButton(
                icon: Icon(_filterSalesRepId != null ? Icons.person : Icons.group),
                tooltip: _filterSalesRepId != null ? 'Viendo mis proyectos' : 'Viendo todos',
                onPressed: () {
                  setState(() {
                    // Alternar entre filtro de mi usuario o ver todos (null)
                    _filterSalesRepId = (_filterSalesRepId == null) ? User.userID : null;
                  });
                  _loadProjects();
                },
              ),
            if (!AccessControl.isProject)
              IconButton(
                icon: Icon(_viewingInactive ? Icons.archive : Icons.archive_outlined),
                tooltip: _viewingInactive ? 'Ver Proyectos Activos' : 'Ver Proyectos Desactivados',
                onPressed: () {
                  setState(() {
                    _viewingInactive = !_viewingInactive;
                    _targetExpandedProjectId = null;
                    _expandAll = false;
                  });
                  _loadProjects();
                },
              ),
            IconButton(
              icon: Icon(_expandAll ? Icons.unfold_less : Icons.unfold_more),
              tooltip: _expandAll ? 'Contraer todo' : 'Expandir todo',
              onPressed: () => setState(() {
                _expandAll = !_expandAll;
                _targetExpandedProjectId = null;
              }),
            ),
          ],
          if (_showingFiles && AccessControl.canManageFiles) ...[if (_isFileManagerRoot) IconButton(icon: const Icon(Icons.create_new_folder_outlined), tooltip: 'Nueva Carpeta', onPressed: () => _fileManagerKey.currentState?.createFolderDialog()), IconButton(icon: const Icon(Icons.upload_file), tooltip: 'Subir Archivo', onPressed: () => _fileManagerKey.currentState?.pickAndUploadFile())],
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refrescar', onPressed: () => _showingFiles ? _fileManagerKey.currentState?.refresh() : _loadProjects()),
        ],
      ),
      drawer: _showingFiles ? null : const CustomDrawer(),
      floatingActionButton: !_showingFiles && !_viewingInactive && AccessControl.canCreateProjectItems ? FloatingActionButton(onPressed: () => _navigateToForm(), child: const Icon(Icons.add), tooltip: 'Nuevo Proyecto') : null,
      body: SafeArea(
        child: _showingFiles ? ProjectFileManager(key: _fileManagerKey, project: _selectedProject!, viewType: _currentViewType, onExit: _exitFileManager, onRootChanged: (isRoot) => setState(() => _isFileManagerRoot = isRoot)) : _buildProjectsView(),
      ),
    );
  }

  Widget _buildProjectsView() {
    if (_isLoadingProjects) return const Center(child: CircularProgressIndicator());

    final filteredProjects = _projects.where((project) {
      final projectName = (project['Name'] as String? ?? '').toLowerCase();
      return projectName.contains(_searchController.text.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: CustomTextField(controller: _searchController, hintText: 'Buscar proyecto...', prefixIcon: const Icon(Icons.search)),
        ),
        if (_projectsErrorMessage != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(_projectsErrorMessage!, style: const TextStyle(color: Colors.red)),
          ),
        Expanded(
          child: filteredProjects.isEmpty
              ? const Center(child: Text('No se encontraron proyectos.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredProjects.length,
                  itemBuilder: (context, index) {
                    final project = filteredProjects[index];
                    return ProjectItem(
                      key: ValueKey('pj-${project['id']}-$_expandAll'),
                      project: project,
                      isExpanded: _expandAll || (_targetExpandedProjectId == project['id']),
                      statusIdMap: _statusIdMap,
                      priorityMap: _priorityMap,
                      onRefresh: _loadProjects,
                      // Al editar, abrimos el formulario de administrador
                      onEdit: (type, id, name, desc) async {
                        if (type == 'project') {
                          _navigateToForm(project: project);
                        } else {
                          setState(() {
                            _isLoadingProjects = true;
                            _targetExpandedProjectId = project['id']; // Mantener expandido
                          });
                          final success = await _logic.updateItem(type, id, name, desc);
                          if (success) {
                            _loadProjects();
                          } else if (mounted)
                            setState(() => _isLoadingProjects = false);
                        }
                      },
                      onCreatePhase: _createPhase,
                      onCreateTask: _createTask,
                      onShowFiles: _onShowFiles,
                      isArchived: _viewingInactive,
                      stats: _projectStats[project['id']], // Pasar stats
                    );
                  },
                ),
        ),
      ],
    );
  }
}
