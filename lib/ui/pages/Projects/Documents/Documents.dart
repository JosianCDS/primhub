import 'package:flutter/material.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/pages/Projects/Documents/projects_logic.dart';
import 'package:primhub/ui/pages/Projects/Documents/project_file_manager.dart';
import 'package:primhub/ui/shared/custom_inputs.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/ui/pages/Projects/Projects_Widgets/project_item.dart';
import 'package:primhub/ui/pages/Projects/dialogs/project_create_dialog.dart';
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
  bool _expandAll = false;
  int _expansionKey = 0;
  int? _targetExpandedProjectId;
  bool _isInit = true;
  String _currentViewType = '';
  final ProjectsLogic _logic = ProjectsLogic();
  final _DocumentsLogic = DocumentsLogic();
  Map<String, int> _statusIdMap = {};
  final Map<String, String> _priorityMap = {'Urgente': '1', 'Alta': '3', 'Media': '5', 'Baja': '7', 'Menor': '9'};

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
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && _projects.isNotEmpty) {
        _applyPendingArgs(args);
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
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
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
    final statuses = await DocumentsLogic.fetchStatuses();
    if (mounted) {
      setState(() {
        _statusIdMap = Map<String, int>.from(statuses as Map);
      });
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
        _exitFileManager();
        _expansionKey++;
      });
    } else if (view == 'Entregables' || view == 'Seguimiento' || view == 'General') {
      setState(() {
        _selectedProject = project;
        _currentViewType = view;
        _showingFiles = true;
      });
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

  Future<void> _createProject(String value, String name, String description, int? bpId, String dateContract, String dateFinish, int? projectTypeId) async {
    setState(() => _isLoadingProjects = true);
    try {
      final success = await _logic.createProject(value: value, name: name, description: description, bpId: bpId, dateContract: dateContract, dateFinish: dateFinish, projectTypeId: projectTypeId);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Proyecto creado correctamente')));
        _loadProjects();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al crear proyecto')));
        setState(() => _isLoadingProjects = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _isLoadingProjects = false);
    }
  }

  Future<void> _createPhase(int projectId, String name, String description) async {
    setState(() => _isLoadingProjects = true);
    try {
      final success = await _logic.createPhase(projectId, name, description);
      if (success) {
        _loadProjects();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al crear fase')));
        setState(() => _isLoadingProjects = false);
      }
    } catch (e) {
      setState(() => _isLoadingProjects = false);
    }
  }

  Future<void> _createTask(int phaseId, String name, String description) async {
    setState(() => _isLoadingProjects = true);
    try {
      final success = await _logic.createTask(phaseId, name, description);
      if (success) {
        _loadProjects();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al crear tarea')));
        setState(() => _isLoadingProjects = false);
      }
    } catch (e) {
      setState(() => _isLoadingProjects = false);
    }
  }

  Future<void> _updateItem(String type, int id, String name, String desc) async {
    setState(() => _isLoadingProjects = true);
    try {
      final success = await _logic.updateItem(type, id, name, desc);
      if (success) {
        _loadProjects();
      } else {
        setState(() => _isLoadingProjects = false);
      }
    } catch (_) {
      setState(() => _isLoadingProjects = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      floatingActionButton: _showingFiles && AccessControl.canManageFiles ? FloatingActionButton(onPressed: () => _fileManagerKey.currentState?.pickAndUploadFile(), tooltip: 'Subir Archivo', child: const Icon(Icons.upload_file)) : null,
      appBar: AppBar(
        title: const Text('Mis Proyectos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        elevation: 0,
        leading: _showingFiles
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  final handled = _fileManagerKey.currentState?.navigateBack() ?? false;
                  if (!handled) {
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
          if (_showingFiles && _isFileManagerRoot && AccessControl.canManageFiles)
            IconButton(
              icon: const Icon(Icons.create_new_folder),
              tooltip: 'Crear Carpeta',
              onPressed: () {
                if (_fileManagerKey.currentState?.isRoot() ?? false) {
                  _fileManagerKey.currentState?.createFolderDialog();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solo se pueden crear carpetas en la raíz.')));
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
            Expanded(
              child: Container(
                color: isDark ? theme.cardColor.withOpacity(0.5) : const Color(0xFFF9FAFB),
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

  Widget _buildProjectsView() {
    if (_isLoadingProjects) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_projectsErrorMessage != null) {
      return Center(child: Text('Error: '));
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
          child: Row(
            children: [
              Expanded(
                child: CustomTextField(controller: _searchController, hintText: 'Buscar proyecto...', prefixIcon: const Icon(Icons.search)),
              ),
              if (AccessControl.canCreateProjectItems) ...[
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 32),
                  color: Theme.of(context).primaryColor,
                  tooltip: 'Nuevo Proyecto',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => ProjectCreateDialog(projects: _projects, onCreateProject: _createProject, onCreatePhase: _createPhase, onCreateTask: _createTask),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredProjects.length,
            itemBuilder: (context, index) {
              return ProjectItem(key: Key('project-${filteredProjects[index]['id']}-'), project: filteredProjects[index], isExpanded: _expandAll || _targetExpandedProjectId == filteredProjects[index]['id'], statusIdMap: _statusIdMap, priorityMap: _priorityMap, onRefresh: _loadProjects, onEdit: _updateItem, onCreatePhase: _createPhase, onCreateTask: _createTask, onShowFiles: _onShowFiles);
            },
          ),
        ),
      ],
    );
  }
}
