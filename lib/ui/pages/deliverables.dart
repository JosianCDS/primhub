import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/ImagesManagment/downloadAttachments.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/shared/custom_inputs.dart';
import 'package:primhub/ui/shared/custom_modal.dart';
import '../shared/custom_button.dart';
import '../widgets/custom_drawer.dart';
import '../shared/hover_widgets.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:file_picker/file_picker.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchProjects();
    _searchController.addListener(() {
      setState(() {});
    });
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

      if (response.statusCode == 500 &&
          response.body.contains('C_ProjectTask')) {
        response = await http.get(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': Token.token,
          },
        );
      }

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _projects = data['records'];
            _isLoadingProjects = false;
            _projectsLoaded = true;
          });
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

  Future<void> _fetchDocuments(String type) async {
    if (_selectedProject == null) return;
    setState(() {
      _isLoadingDocuments = true;
      _documents = [];
    });

    final projectId = _selectedProject!['id'];
    // Type: ET = Entregable, SG = Seguimiento
    final typeCode = type == 'Entregables' ? 'ET' : 'SG';

    try {
      final response = await http.get(
        Uri.parse(
          '${Endpoint.primDocuments}?\$filter=C_Project_ID eq $projectId and Type eq \'$typeCode\'&\$expand=PRIM_Documents_Related',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _documents = data['records'];
            _isLoadingDocuments = false;
          });
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
              onPressed: _uploadFile,
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
          if (_showingFiles)
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
                    ? LayoutBuilder(
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
        currentItems = List.from(folder['PRIM_Documents_Related'] ?? []);
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

    if (originalDetails['Name'] != null) body['Name'] = originalDetails['Name'];
    if (originalDetails['C_Project_ID'] != null)
      body['C_Project_ID'] = prepareValue(originalDetails['C_Project_ID']);
    if (originalDetails['Type'] != null)
      body['Type'] = prepareValue(originalDetails['Type']);
    if (originalDetails['IsSummary'] != null)
      body['IsSummary'] = originalDetails['IsSummary'];
    if (originalDetails['Extension'] != null)
      body['Extension'] = originalDetails['Extension'];
    if (originalDetails['Parent_ID'] != null)
      body['Parent_ID'] = prepareValue(originalDetails['Parent_ID']);

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
                      typeCode == 'ET' ? 'Entregable' : 'Seguimiento',
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

  Future<void> _uploadFile() async {
    if (_selectedProject == null || _currentPath.length < 3) return;

    // Determinar tipo y contexto
    String typeStr = _currentPath[2];
    String typeCode = typeStr == 'Entregables' ? 'ET' : 'SG';
    int projectId = _selectedProject!['id'];

    // Seleccionar archivo
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final PlatformFile file = result.files.first;
    final Uint8List? fileBytes = file.bytes;
    final String fileName = file.name;
    final String extension = fileName.contains('.')
        ? fileName.split('.').last
        : '';

    if (fileBytes == null) return;

    setState(() => _isLoadingDocuments = true);

    try {
      // 1. Crear Registro del Documento
      final createUrl = Uri.parse(Endpoint.primDocuments);
      final Map<String, dynamic> payload = {
        'Name': fileName,
        'C_Project_ID': projectId,
        'Type': typeCode,
        'Extension': extension,
      };

      // Si estamos en una subcarpeta, intentar vincular (Lógica simplificada)
      if (_currentPath.length > 3) {
        final folderName = _currentPath.last;
        final folder = _documents.firstWhere(
          (doc) => doc['Name'] == folderName && doc['IsSummary'] == true,
          orElse: () => null,
        );
        if (folder != null) {
          // Asumiendo que el backend soporta Parent_ID o similar para anidar
          payload['Parent_ID'] = folder['id'];
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

        // 2. Subir Adjunto
        final attachUrl = Uri.parse(
          '${Endpoint.primDocuments}/$newRecordId/attachments',
        );

        final String base64File = base64Encode(fileBytes);

        final attachResponse = await http.post(
          attachUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': Token.token,
          },
          body: jsonEncode({'name': fileName, 'data': base64File}),
        );

        if (attachResponse.statusCode >= 200 &&
            attachResponse.statusCode < 300) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Archivo subido correctamente')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Registro creado, pero error al subir adjunto: ${attachResponse.statusCode}',
              ),
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
      _fetchDocuments(typeStr);
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
    String typeCode = typeStr == 'Entregables' ? 'ET' : 'SG';
    int projectId = _selectedProject!['id'];

    try {
      final createUrl = Uri.parse(Endpoint.primDocuments);
      final Map<String, dynamic> payload = {
        'Name': name,
        'C_Project_ID': projectId,
        'Type': typeCode,
        'IsSummary': true,
      };

      if (_currentPath.length > 3) {
        final folderName = _currentPath.last;
        final folder = _documents.firstWhere(
          (doc) => doc['Name'] == folderName && doc['IsSummary'] == true,
          orElse: () => null,
        );
        if (folder != null) {
          payload['Parent_ID'] = folder['id'];
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

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        key: Key('${project['id']}-$_expansionKey'),
        initiallyExpanded: _expandAll,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.assignment, color: Colors.white),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: description.isNotEmpty
            ? Text(description, maxLines: 2, overflow: TextOverflow.ellipsis)
            : null,
        children: [
          ExpansionTile(
            title: const Text("Fases"),
            leading: const Icon(Icons.list_alt),
            children: [
              if (phases.isNotEmpty)
                ...phases.map((phase) => _buildPhaseItem(phase)),
              if (directTasks.isNotEmpty)
                ...directTasks.map((task) => _buildTaskItem(task)),
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
            ],
          ),
          ListTile(
            title: const Text("Entregables"),
            leading: const Icon(Icons.folder),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
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
          ListTile(
            title: const Text("Seguimiento"),
            leading: const Icon(Icons.timeline),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPhaseItem(Map<String, dynamic> phase) {
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
            color: isComplete ? Colors.green : Colors.orange,
          ),
          title: Text(
            phase['Name'] ?? 'Fase',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text('${tasks.length} Tareas'),
          children: tasks
              .map((task) => _buildTaskItem(task, isNested: true))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task, {bool isNested = false}) {
    return ListTile(
      contentPadding: EdgeInsets.only(
        left: isNested ? 16.0 : 16.0,
        right: 16.0,
      ),
      leading: const Icon(Icons.task_alt, size: 18, color: Colors.blueGrey),
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
    );
  }
}
