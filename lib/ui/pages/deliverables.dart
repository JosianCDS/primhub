import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:primhub/ImagesManagment/downloadAttachments.dart';
import 'package:primhub/ImagesManagment/postAttachments.dart';
import 'package:primhub/api/auth_api.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/shared/custom_inputs.dart';
import 'package:primhub/ui/shared/custom_modal.dart';
import '../shared/custom_button.dart';
import '../widgets/custom_drawer.dart';
import '../shared/hover_widgets.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';

class DeliverablesPage extends StatefulWidget {
  const DeliverablesPage({super.key});

  @override
  State<DeliverablesPage> createState() => _DeliverablesPageState();
}

class _DeliverablesPageState extends State<DeliverablesPage> {
  List<String> _currentPath = ['Mis Proyectos'];
  bool _showingFiles = false;

  // State for Projects Tab
  List<dynamic> _projects = [];
  List<dynamic> _documents = [];
  Map<String, dynamic>? _selectedProject;
  bool _isLoadingProjects = false;
  bool _isLoadingDocuments = false;
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
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
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
        _showingFiles = false;
        _currentPath = ['Mis Proyectos'];
        _expansionKey++;
      });
    } else if (view == 'Entregables' ||
        view == 'Seguimiento' ||
        view == 'General') {
      setState(() {
        _selectedProject = project;
        _currentPath = ['Mis Proyectos', project['Name'] ?? 'Proyecto', view];
        _showingFiles = true;
      });
      _fetchDocuments(view);
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

  Future<void> _fetchDocuments(String type) async {
    if (_selectedProject == null) return;
    setState(() {
      _isLoadingDocuments = true;
      _documents = [];
    });

    final projectId = _selectedProject!['id'];
    // Type: ET = Entregable, SG = Seguimiento, GN = General
    String typeCode;
    if (type == 'Entregables') {
      typeCode = 'ET';
    } else if (type == 'Seguimiento') {
      typeCode = 'SG';
    } else {
      typeCode = 'GN';
    }

    try {
      var response = await http.get(
        Uri.parse(
          '${Endpoint.primDocuments}?\$filter=C_Project_ID eq $projectId and Type eq \'$typeCode\'&\$expand=PRIM_Documents_Related',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
      );

      if (response.statusCode == 401) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          response = await http.get(
            Uri.parse(
              '${Endpoint.primDocuments}?\$filter=C_Project_ID eq $projectId and Type eq \'$typeCode\'&\$expand=PRIM_Documents_Related',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': Token.token,
            },
          );
        } else {
          if (mounted) {
            setState(() => _isLoadingDocuments = false);
            context.go('/login');
          }
          return;
        }
      }

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        List<dynamic> records = data['records'];

        // Si estamos dentro de una carpeta, forzamos la carga de sus hijos
        // para asegurar que el nuevo archivo aparezca.
        if (_currentPath.length > 3) {
          final folderName = _currentPath.last;
          final folderIndex = records.indexWhere(
            (doc) =>
                doc['Name'] == folderName &&
                (doc['IsSummary'] == true || doc['IsSummary'] == 'Y'),
          );

          if (folderIndex != -1) {
            final folderId = records[folderIndex]['id'];
            try {
              final childrenResponse = await http.get(
                Uri.parse(
                  '${Endpoint.primDocuments}/$folderId/PRIM_Documents_Related',
                ),
                headers: {'Authorization': Token.token},
              );
              if (childrenResponse.statusCode == 200) {
                final childrenData = json.decode(
                  utf8.decode(childrenResponse.bodyBytes),
                );
                records[folderIndex]['PRIM_Documents_Related'] =
                    childrenData['records'];
              }
            } catch (e) {
              debugPrint('Error fetching folder children: $e');
            }
          }
        }

        if (mounted) {
          setState(() {
            _documents = records;
            _isLoadingDocuments = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingDocuments = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error al cargar documentos: ${response.statusCode}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching documents: $e');
      if (mounted) setState(() => _isLoadingDocuments = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      floatingActionButton: _showingFiles
          ? FloatingActionButton(
              onPressed: _pickAndUploadFile,
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
                  // Si la ruta actual tiene más de 2 elementos (ej. ['Mis Proyectos', 'Proyecto X', 'Entregables']),
                  // podemos retroceder un nivel.
                  setState(() {
                    if (_currentPath.length > 2) {
                      _currentPath.removeLast();
                      // Si al retroceder nos quedamos con menos de 3 elementos en la ruta,
                      // significa que hemos salido de la vista de 'Entregables'/'Seguimiento',
                      // por lo que volvemos a la lista de proyectos.
                      if (_currentPath.length < 3) {
                        _showingFiles = false;
                      }
                    } else {
                      _showingFiles = false;
                    }
                  });
                },
              )
            : null,
        actions: [
          if (_showingFiles && _currentPath.length <= 3)
            IconButton(
              icon: const Icon(Icons.create_new_folder),
              tooltip: 'Crear Carpeta',
              onPressed: _createFolderDialog,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_showingFiles) {
                _fetchDocuments(_currentPath[2]);
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
                    ? DropTarget(
                        onDragDone: (details) async {
                          for (final file in details.files) {
                            final bytes = await file.readAsBytes();
                            await _uploadFileBytes(file.name, bytes);
                          }
                        },
                        onDragEntered: (details) =>
                            setState(() => _isDragging = true),
                        onDragExited: (details) =>
                            setState(() => _isDragging = false),
                        child: Container(
                          color: _isDragging
                              ? theme.colorScheme.primary.withOpacity(0.1)
                              : null,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              double containerWidth = constraints.maxWidth > 800
                                  ? 800
                                  : constraints.maxWidth;
                              int crossAxisCount = 2;
                              double childAspectRatio = 0.75;
                              int charLimit = containerWidth < 600 ? 12 : 25;

                              return SingleChildScrollView(
                                padding: const EdgeInsets.all(16.0),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 800,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (_currentPath.length > 1) ...[
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 16.0,
                                              left: 8.0,
                                              right: 8.0,
                                            ),
                                            child: _buildBreadcrumbs(context),
                                          ),
                                        ],
                                        _buildContentGrid(
                                          crossAxisCount,
                                          childAspectRatio,
                                          charLimit,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      )
                    : _buildProjectsView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs(BuildContext context) {
    List<Widget> crumbs = [];
    for (int i = 0; i < _currentPath.length; i++) {
      final isLast = i == _currentPath.length - 1;
      crumbs.add(
        InkWell(
          onTap: isLast
              ? null
              : () {
                  if (i <= 1) {
                    setState(() {
                      _showingFiles = false;
                    });
                  } else {
                    setState(() {
                      _currentPath = _currentPath.sublist(0, i + 1);
                    });
                  }
                },
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            child: Text(
              _currentPath[i]
                  .split('.')
                  .first, // No mostrar extensión en breadcrumb
              style: TextStyle(
                color: isLast
                    ? Theme.of(context).textTheme.bodyLarge?.color
                    : Theme.of(context).colorScheme.primary,
                fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
      if (!isLast) {
        crumbs.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Icon(Icons.chevron_right, color: Colors.grey, size: 16),
          ),
        );
      }
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: crumbs,
      ),
    );
  }

  Widget _buildContentGrid(
    int crossAxisCount,
    double childAspectRatio,
    int charLimit,
  ) {
    if (_isLoadingDocuments) {
      return const Center(child: CircularProgressIndicator());
    }

    List<dynamic> currentItems = List.from(_documents);
    String tableName = Endpoint.primDocuments;

    // Navegación simple: Si estamos en una subcarpeta (path > 3), buscamos en los hijos
    // Estructura: Mis Proyectos -> Proyecto -> Entregables -> [Carpeta]
    if (_currentPath.length > 3) {
      final folderName = _currentPath.last;
      final folder = _documents.firstWhere(
        (doc) =>
            doc['Name'] == folderName &&
            (doc['IsSummary'] == true || doc['IsSummary'] == 'Y'),
        orElse: () => null,
      );

      if (folder != null) {
        // Filter children by current view type
        String typeCode = _currentPath[2] == 'Entregables'
            ? 'ET'
            : (_currentPath[2] == 'Seguimiento' ? 'SG' : 'GN');

        final allChildren = folder['PRIM_Documents_Related'] as List? ?? [];
        currentItems = allChildren.where((child) {
          dynamic typeVal = child['Type'];
          String childTypeCode = '';
          if (typeVal is Map) {
            childTypeCode = typeVal['id']?.toString() ?? '';
          } else if (typeVal != null) {
            childTypeCode = typeVal.toString();
          }
          return childTypeCode == typeCode;
        }).toList();

        tableName = Endpoint.primDocumentsRelated;
      }
    }

    // Ordenar: Carpetas primero, luego archivos. Ambos por fecha de creación ascendente.
    currentItems.sort((a, b) {
      final isFolderA = a['IsSummary'] == true || a['IsSummary'] == 'Y';
      final isFolderB = b['IsSummary'] == true || b['IsSummary'] == 'Y';

      if (isFolderA && !isFolderB) return -1;
      if (!isFolderA && isFolderB) return 1;

      final dateA = DateTime.tryParse(a['Created'] ?? '') ?? DateTime(0);
      final dateB = DateTime.tryParse(b['Created'] ?? '') ?? DateTime(0);

      // Ordenar por fecha de creación, los más antiguos primero
      return dateA.compareTo(dateB);
    });

    if (currentItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No hay documentos.",
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: currentItems.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final item = currentItems[index];
        final name = item['Name'] ?? 'Sin Nombre';
        final isFolder = item['IsSummary'] == true || item['IsSummary'] == 'Y';

        String size = '';
        if (isFolder) {
          final children = item['PRIM_Documents_Related'] as List? ?? [];
          size = '${children.length} archivo${children.length != 1 ? 's' : ''}';
        }

        String extension = '';
        if (!isFolder && name.contains('.')) {
          extension = name.split('.').last.toUpperCase();
        }

        return _buildDeliverableCard(
          extension,
          name,
          size,
          isFolder ? Colors.amber : Colors.blue,
          charLimit,
          isFolder: isFolder,
          details: item,
          tableName: tableName,
        );
      },
    );
  }

  Widget _buildDeliverableCard(
    String extension,
    String name,
    String size,
    Color color,
    int charLimit, {
    bool isFolder = false,
    required Map<String, dynamic> details,
    required String tableName,
  }) {
    final status = _extractStatus(details['Status']);
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final statusColor = _getStatusColor(status);

    return HoverScaleCard(
      child: InkWell(
        onTap: () {
          if (isFolder) {
            setState(() {
              _currentPath.add(name);
            });
          } else {
            _previewFile(details, tableName, name);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Card(
          elevation: 4,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: isFolder
                          ? const EdgeInsets.all(8)
                          : const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        border: Border.all(color: color, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: isFolder
                          ? Icon(Icons.folder, color: color, size: 28)
                          : Icon(
                              _getFileIcon(extension),
                              color: color,
                              size: 28,
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name.split('.').first.length > charLimit
                          ? '${name.split('.').first.substring(0, charLimit)}...'
                          : name.split('.').first,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      size,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    if (isFolder)
                      _buildFolderStatusChip(details)
                    else
                      _buildFileStatusChip(details),
                    const SizedBox(height: 12),
                    Icon(
                      isFolder ? Icons.folder_open : Icons.download,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.info_outline),
                  color: Colors.grey[500],
                  tooltip: 'Ver propiedades',
                  onPressed: () {
                    _showPropertiesDialog(context, name, details, tableName);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileStatusChip(Map<String, dynamic> details) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final status = _extractStatus(details['Status']);
    final statusColor = _getStatusColor(status);

    IconData statusIcon;
    switch (status) {
      case 'Entregado':
        statusIcon = Icons.check_circle;
        break;
      case 'En revisión':
        statusIcon = Icons.visibility;
        break;
      case 'Pendiente':
      default:
        statusIcon = Icons.access_time;
        break;
    }

    return Chip(
      avatar: Icon(
        isMobile ? statusIcon : Icons.circle,
        color: statusColor,
        size: isMobile ? 14 : 12,
      ),
      label: Text(status),
      backgroundColor: statusColor.withOpacity(0.15),
      labelStyle: TextStyle(
        color: statusColor,
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildFolderStatusChip(Map<String, dynamic> details) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final List<dynamic> children = details['PRIM_Documents_Related'] ?? [];
    final pendingCount = children
        .where(
          (child) =>
              child is Map && _extractStatus(child['Status']) == 'Pendiente',
        )
        .length;
    final reviewCount = children
        .where(
          (child) =>
              child is Map && _extractStatus(child['Status']) == 'En revisión',
        )
        .length;

    if (pendingCount == 0 && reviewCount == 0) {
      final statusColor = _getStatusColor('Entregado');
      return Chip(
        avatar: Icon(Icons.check_circle, color: statusColor, size: 14),
        label: Text(isMobile ? 'OK' : 'Completo'),
        backgroundColor: statusColor.withOpacity(0.15),
        labelStyle: TextStyle(
          color: statusColor,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }

    List<Widget> statusWidgets = [];
    if (pendingCount > 0) {
      final color = _getStatusColor('Pendiente');
      statusWidgets.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMobile ? Icons.access_time : Icons.circle,
              color: color,
              size: isMobile ? 14 : 10,
            ),
            const SizedBox(width: 4),
            Text(
              isMobile ? '$pendingCount' : '$pendingCount Pendiente',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    if (reviewCount > 0) {
      if (statusWidgets.isNotEmpty) {
        statusWidgets.add(const SizedBox(width: 8));
      }
      final color = _getStatusColor('En revisión');
      statusWidgets.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMobile ? Icons.visibility : Icons.circle,
              color: color,
              size: isMobile ? 14 : 10,
            ),
            const SizedBox(width: 4),
            Text(
              isMobile ? '$reviewCount' : '$reviewCount Revisión',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Chip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: statusWidgets,
      ),
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surfaceVariant.withOpacity(0.3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Future<bool> _updateDocumentRemote(
    int id,
    Map<String, dynamic> originalDetails,
    String description,
    String version,
    String status,
    bool isFolder,
  ) async {
    // try {
    final url = Uri.parse('${Endpoint.primDocuments}/$id');

    dynamic prepareValue(dynamic val) {
      if (val is Map && val.containsKey('id')) {
        return {'id': val['id']};
      }
      return val;
    }

    final body = <String, dynamic>{
      'Description': description,
      'VersionNo': version,
    };

    if (originalDetails['Name'] != null) {
      body['Name'] = originalDetails['Name'];
      body['name'] = originalDetails['Name'];
    }
    if (originalDetails['C_Project_ID'] != null)
      body['C_Project_ID'] = prepareValue(originalDetails['C_Project_ID']);
    if (originalDetails['Type'] != null) {
      dynamic val = originalDetails['Type'];
      if (val is Map && val.containsKey('id')) {
        body['Type'] = val['id'];
      } else {
        body['Type'] = val;
      }
    }
    if (originalDetails['Extension'] != null)
      body['Extension'] = originalDetails['Extension'];
    if (originalDetails['PRIM_Documents_ID'] != null) {
      dynamic val = originalDetails['PRIM_Documents_ID'];
      if (val is Map && val.containsKey('id')) {
        body['PRIM_Documents_ID'] = val['id'];
      } else {
        body['PRIM_Documents_ID'] = val;
      }
    }

    if (!isFolder) {
      // Map display status to backend code
      const statusCodes = {
        'Pendiente': 'PD',
        'En revisión': 'IR',
        'Entregado': 'DL',
      };
      body['Status'] = statusCodes[status] ?? status;
    } else {
      if (originalDetails['Status'] != null) {
        body['Status'] = prepareValue(originalDetails['Status']);
      }
    }

    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': Token.token,
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      debugPrint('Update Error ${response.statusCode}: ${response.body}');
    }

    return response.statusCode == 200 || response.statusCode == 201;
    // } catch (e) {
    //   debugPrint('Update exception: $e');
    //   return false;
    // }
  }

  void _showPropertiesDialog(
    BuildContext context,
    String name,
    Map<String, dynamic> details,
    String tableName,
  ) {
    final status = _extractStatus(details['Status']);
    final bool isFolder =
        details['IsSummary'] == true || details['IsSummary'] == 'Y';

    final TextEditingController nameController = TextEditingController(
      text: details['Name'],
    );
    final TextEditingController descController = TextEditingController(
      text: details['Description']?.toString() ?? '',
    );
    final TextEditingController versionController = TextEditingController(
      text: details['VersionNo']?.toString() ?? '',
    );
    final TextEditingController statusController = TextEditingController(
      text: status,
    );
    String currentStatus = status;
    bool isSaving = false;

    dynamic typeVal = details['Type'];
    String typeCode = '';
    if (typeVal is Map) {
      typeCode = typeVal['id']?.toString() ?? '';
    } else if (typeVal != null) {
      typeCode = typeVal.toString();
    }

    final List<String> statuses = ['Pendiente', 'En revisión', 'Entregado'];
    if (!statuses.contains(currentStatus)) {
      statuses.add(currentStatus);
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return CustomModal(
              title: 'Editar Propiedades',
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomTextField(
                      controller: nameController,
                      label: 'Nombre',
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: descController,
                      label: 'Descripción',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: versionController,
                            label: 'Versión',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: isFolder
                              ? CustomTextField(
                                  controller: statusController,
                                  label: 'Estado',
                                  readOnly: true,
                                )
                              : CustomDropdown<String>(
                                  value: currentStatus,
                                  label: 'Estado',
                                  items: statuses
                                      .map(
                                        (s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(s),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setStateDialog(() => currentStatus = val);
                                    }
                                  },
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildPropertyRow(
                      'Tipo',
                      typeCode == 'ET'
                          ? 'Entregable'
                          : (typeCode == 'SG' ? 'Seguimiento' : 'General'),
                    ),
                    _buildPropertyRow(
                      'Extensión',
                      _extractIdentifier(details['Extension']),
                    ),
                    _buildPropertyRow(
                      'Creado',
                      _formatDate(details['Created']),
                    ),
                    _buildPropertyRow(
                      'Creado Por',
                      _extractIdentifier(
                        details['CreatedBy'],
                        defaultValue: 'Sistema',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteFile(details['id'], tableName, name),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                CustomButton(
                  text: 'Guardar',
                  isLoading: isSaving,
                  onPressed: () async {
                    setStateDialog(() => isSaving = true);
                    final success = await _updateDocumentRemote(
                      details['id'],
                      details,
                      descController.text,
                      versionController.text,
                      currentStatus,
                      isFolder,
                    );
                    setStateDialog(() => isSaving = false);

                    if (success) {
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Documento actualizado correctamente',
                            ),
                          ),
                        );
                        // Refrescar lista
                        if (_currentPath.length > 2) {
                          _fetchDocuments(_currentPath[2]);
                        }
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Error al actualizar documento'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _previewFile(
    Map<String, dynamic> details,
    String tableName,
    String name,
  ) {
    final extension = name.split('.').last.toLowerCase();
    final isImage = [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
    ].contains(extension);
    final isPdf = extension == 'pdf';

    showDialog(
      context: context,
      builder: (context) => CustomModal(
        title: name,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isImage || isPdf)
                FutureBuilder<Uint8List?>(
                  future: _fetchImage(tableName, details['id'], name),
                  builder: (context, snapshot) {
                    return _buildPreviewWidget(
                      snapshot,
                      isImage,
                      isPdf,
                      name,
                      details,
                      tableName,
                    );
                  },
                )
              else
                _buildNoPreviewWidget(extension),
              const SizedBox(height: 20),
              _buildPropertyRow('Estado', _extractStatus(details['Status'])),
              _buildPropertyRow(
                'Versión',
                _extractIdentifier(details['VersionNo']),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteFile(details['id'], tableName, name),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          CustomButton(
            text: 'Descargar',
            icon: Icons.download,
            onPressed: () {
              downloadAttachment(
                context: context,
                recordID: details['id'],
                tableName: tableName,
                fileName: name,
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadFile() async {
    if (_selectedProject == null || _currentPath.length < 3) return;

    // Determinar tipo y contexto
    String typeStr = _currentPath[2];
    String typeCode;
    if (typeStr == 'Entregables') {
      typeCode = 'ET';
    } else if (typeStr == 'Seguimiento') {
      typeCode = 'SG';
    } else {
      typeCode = 'GN';
    }
    int projectId = _selectedProject!['id'];

    // Seleccionar archivo
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final PlatformFile file = result.files.first;
    final Uint8List? fileBytes = file.bytes;

    if (fileBytes != null) {
      if (fileBytes.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('El archivo está vacío')));
        return;
      }
      await _uploadFileBytes(file.name, fileBytes);
    }
  }

  Future<void> _uploadFileBytes(String fileName, Uint8List fileBytes) async {
    final String extension = fileName.contains('.')
        ? fileName.split('.').last
        : '';

    setState(() => _isLoadingDocuments = true);

    try {
      // 1. Crear Registro del Documento
      Uri createUrl = Uri.parse(Endpoint.primDocuments);
      final Map<String, dynamic> payload = {
        'Name': fileName,
        'name': fileName,
        'C_Project_ID': {'id': _selectedProject!['id']},
        'Type': _currentPath[2] == 'Entregables'
            ? 'ET'
            : (_currentPath[2] == 'Seguimiento' ? 'SG' : 'GN'),
        'Extension': extension,
        'VersionNo': '1.0',
        'Status': 'PD',
        'IsActive': true,
      };

      // Si estamos en una subcarpeta, intentar vincular (Lógica simplificada)
      if (_currentPath.length > 3) {
        final folderName = _currentPath.last;
        final folder = _documents.firstWhere(
          (doc) =>
              doc['Name'] == folderName &&
              (doc['IsSummary'] == true || doc['IsSummary'] == 'Y'),
          orElse: () => null,
        );
        if (folder != null) {
          createUrl = Uri.parse(Endpoint.primDocumentsRelated);
          payload['PRIM_Documents_ID'] = {'id': folder['id']};
          payload.remove('C_Project_ID');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: No se encuentra la carpeta padre.'),
            ),
          );
          setState(() => _isLoadingDocuments = false);
          return;
        }
      }

      final createResponse = await http.post(
        createUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
        body: jsonEncode(payload),
      );

      if (createResponse.statusCode == 200 ||
          createResponse.statusCode == 201) {
        final newRecord = jsonDecode(createResponse.body);
        final newRecordId = newRecord['id'];

        // 2. Subir Adjunto usando la función centralizada
        final bool attached = await postAttachments(
          recordID: newRecordId,
          tableName: createUrl.toString(),
          convertedFile: {'title': fileName, 'base64': base64Encode(fileBytes)},
        );
        if (attached) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Archivo subido correctamente')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Registro creado, pero error al subir adjunto.'),
            ),
          );
        }
      } else {
        debugPrint('Error create: ${createResponse.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al crear registro: ${createResponse.statusCode}',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      _fetchDocuments(_currentPath[2]);
    }
  }

  Future<void> _createFolderDialog() async {
    final TextEditingController controller = TextEditingController();
    final bool? create = await showDialog<bool>(
      context: context,
      builder: (context) => CustomModal(
        title: 'Nueva Carpeta',
        content: CustomTextField(
          controller: controller,
          label: 'Nombre de la carpeta',
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

    if (create == true && controller.text.isNotEmpty) {
      _createFolder(controller.text);
    }
  }

  Future<void> _createFolder(String name) async {
    if (_selectedProject == null) return;
    setState(() => _isLoadingDocuments = true);

    String typeStr = _currentPath[2];
    String typeCode;
    if (typeStr == 'Entregables') {
      typeCode = 'ET';
    } else if (typeStr == 'Seguimiento') {
      typeCode = 'SG';
    } else {
      typeCode = 'GN';
    }
    int projectId = _selectedProject!['id'];

    try {
      final Uri createUrl = Uri.parse(Endpoint.primDocuments);
      final Map<String, dynamic> payload = {
        'Name': name,
        'name': name,
        'C_Project_ID': {'id': projectId},
        'Type': typeCode,
      };

      if (_currentPath.length > 3) {
        final folderName = _currentPath.last;
        final folder = _documents.firstWhere(
          (doc) =>
              doc['Name'] == folderName &&
              (doc['IsSummary'] == true || doc['IsSummary'] == 'Y'),
          orElse: () => null,
        );
        if (folder != null) {
          // Usar endpoint principal y enviar PRIM_Documents_ID como entero
          payload['PRIM_Documents_ID'] = folder['id'];
        }
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
          const SnackBar(content: Text('Carpeta creada correctamente')),
        );
      } else {
        debugPrint('Error create folder: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear carpeta: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      _fetchDocuments(typeStr);
    }
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

  Future<void> _deleteFile(int id, String tableName, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => CustomModal(
        title: 'Eliminar Archivo',
        content: Text('¿Estás seguro de que deseas eliminar "$name"?'),
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
      // Cerrar el diálogo de previsualización
      Navigator.pop(context);

      setState(() => _isLoadingDocuments = true);
      try {
        final response = await http.delete(
          Uri.parse('$tableName/$id'),
          headers: {'Authorization': Token.token},
        );

        if (response.statusCode == 200 || response.statusCode == 204) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Archivo eliminado correctamente')),
          );
          if (_currentPath.length > 2) {
            _fetchDocuments(_currentPath[2]);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: ${response.statusCode}'),
            ),
          );
          setState(() => _isLoadingDocuments = false);
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoadingDocuments = false);
      }
    }
  }

  Widget _buildPreviewWidget(
    AsyncSnapshot<Uint8List?> snapshot,
    bool isImage,
    bool isPdf,
    String name,
    Map<String, dynamic> details,
    String tableName,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (snapshot.hasData && snapshot.data != null) {
      if (isImage) {
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: Image.memory(snapshot.data!, fit: BoxFit.contain),
        );
      } else if (isPdf) {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
          return Container(
            height: 200,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.picture_as_pdf, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Vista previa no disponible en Linux',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    downloadAttachment(
                      context: context,
                      recordID: details['id'],
                      tableName: tableName,
                      fileName: name,
                    );
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir externamente'),
                ),
              ],
            ),
          );
        }
        return SizedBox(height: 500, child: SfPdfViewer.memory(snapshot.data!));
      }
    }
    return Container(
      height: 200,
      color: Colors.grey.shade200,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, size: 50, color: Colors.grey),
            SizedBox(height: 8),
            Text('No se pudo cargar la previsualización'),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPreviewWidget(String extension) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(_getFileIcon(extension), size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Previsualización no disponible para este tipo de archivo.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<Uint8List?> _fetchImage(
    String tableName,
    int recordId,
    String fileName,
  ) async {
    try {
      final url =
          '$tableName/$recordId/attachments/${Uri.encodeComponent(fileName)}';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': Token.token},
      );
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('Error fetching image preview: $e');
    }
    return null;
  }

  Widget _buildPropertyRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          const Divider(),
        ],
      ),
    );
  }

  String _extractStatus(dynamic val) {
    if (val == null) return 'Pendiente';
    if (val is String) return val;
    if (val is Map) {
      return val['identifier']?.toString() ??
          val['name']?.toString() ??
          'Pendiente';
    }
    return 'Pendiente';
  }

  String _extractIdentifier(dynamic val, {String defaultValue = 'N/A'}) {
    if (val == null) return defaultValue;
    if (val is String) return val.isEmpty ? defaultValue : val;
    if (val is Map) {
      return val['identifier']?.toString() ??
          val['name']?.toString() ??
          defaultValue;
    }
    return val.toString();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'No definida';
    try {
      final DateTime date = DateTime.parse(dateStr).toLocal();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  IconData _getFileIcon(String extension) {
    switch (extension.toUpperCase()) {
      case 'PDF':
        return Icons.picture_as_pdf;
      case 'DOC':
      case 'DOCX':
        return Icons.description;
      case 'XLS':
      case 'XLSX':
      case 'CSV':
        return Icons.table_chart;
      case 'JPG':
      case 'JPEG':
      case 'PNG':
        return Icons.image;
      case 'TXT':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Entregado':
        return Colors.green.shade600;
      case 'En revisión':
        return Colors.amber.shade700;
      case 'Pendiente':
        return Colors.red.shade600;
      default:
        return Colors.grey;
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
                  _currentPath = [
                    'Mis Proyectos',
                    project['Name'] ?? 'Proyecto',
                    'Entregables',
                  ];
                  _fetchDocuments('Entregables');
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
                  _currentPath = [
                    'Mis Proyectos',
                    project['Name'] ?? 'Proyecto',
                    'Seguimiento',
                  ];
                  _fetchDocuments('Seguimiento');
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
                  _currentPath = [
                    'Mis Proyectos',
                    project['Name'] ?? 'Proyecto',
                    'General',
                  ];
                  _fetchDocuments('General');
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
            /*
            IconButton(
              icon: Icon(isComplete ? Icons.check_box : Icons.check_box_outline_blank, color: isComplete ? Colors.green : Colors.grey),
              onPressed: () {
                 // Manual check for project if needed, or rely on cascade
              },
              tooltip: 'Completar Proyecto',
            ),
            */
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
              IconButton(
                icon: Icon(
                  isComplete ? Icons.check_box : Icons.check_box_outline_blank,
                  color: isComplete ? Colors.green : Colors.grey,
                ),
                onPressed: () =>
                    _toggleComplete('phase', phase['id'], isComplete, null),
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
          IconButton(
            icon: Icon(
              isComplete ? Icons.check_box : Icons.check_box_outline_blank,
              color: isComplete ? Colors.green : Colors.grey,
            ),
            onPressed: () =>
                _toggleComplete('task', task['id'], isComplete, phase),
          ),
        ],
      ),
    );
  }
}
