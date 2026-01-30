import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/shared/custom_inputs.dart';
import 'package:primhub/ui/shared/custom_modal.dart';
import '../shared/custom_button.dart';
import '../widgets/custom_drawer.dart';
import '../shared/hover_widgets.dart';

class DeliverablesPage extends StatefulWidget {
  const DeliverablesPage({super.key});

  @override
  State<DeliverablesPage> createState() => _DeliverablesPageState();
}

class _DeliverablesPageState extends State<DeliverablesPage> {
  List<String> _currentPath = ['Mis Proyectos'];
  bool _showingFiles = false;

  // Datos de ejemplo para simular un sistema de archivos
  final Map<String, dynamic> _fileSystem = {
    'Entregables': {
      'Manuales de Usuario': {
        'type': 'folder',
        'color': Colors.amber,
        'children': {
          'manual_cms.pdf': {
            'type': 'file',
            'size': '2.1 MB',
            'color': Colors.red,
            'status': 'Entregado',
          },
          'manual_plataforma.pdf': {
            'type': 'file',
            'size': '1.5 MB',
            'color': Colors.red,
            'status': 'En revisión',
          },
          'guia_rapida.docx': {
            'type': 'file',
            'size': '800 KB',
            'color': Colors.blue,
            'status': 'Pendiente',
          },
        },
      },
      'Codigo_Fuente.zip': {
        'type': 'file',
        'size': '150 MB',
        'color': Colors.orange,
        'status': 'Entregado',
      },
      'Especificaciones': {
        'type': 'folder',
        'color': Colors.amber,
        'children': {
          'requerimientos_v1.pdf': {
            'type': 'file',
            'size': '2.5 MB',
            'color': Colors.red,
            'status': 'Pendiente',
          },
          'diagrama_flujo.png': {
            'type': 'file',
            'size': '1.2 MB',
            'color': Colors.purple,
            'status': 'Pendiente',
          },
        },
      },
      'Reporte_Financiero.xlsx': {
        'type': 'file',
        'size': '850 KB',
        'color': Colors.green,
        'status': 'En revisión',
      },
    },
    'Seguimiento': {
      'Minutas de Sesiones': {
        'type': 'folder',
        'color': Colors.purple,
        'children': {
          'minuta_2023_01_10.pdf': {
            'type': 'file',
            'size': '500 KB',
            'color': Colors.red,
            'status': 'Entregado',
          },
        },
      },
      'Asistencia.pdf': {
        'type': 'file',
        'size': '1.8 MB',
        'color': Colors.red,
        'status': 'Entregado',
      },
    },
  };

  // State for Projects Tab
  List<dynamic> _projects = [];
  bool _isLoadingProjects = false;
  String? _projectsErrorMessage;
  bool _projectsLoaded = false;

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    setState(() {
      _isLoadingProjects = true;
      _projectsErrorMessage = null;
    });

    if (User.cBPartnerID == null) {
      if (mounted) {
        setState(() {
          _isLoadingProjects = false;
          _projectsErrorMessage = 'No se pudo identificar el socio de negocio.';
        });
      }
      return;
    }

    String baseUrl =
        '${Endpoint.project}?\$filter=C_BPartner_ID eq ${User.cBPartnerID}';
    String url =
        '$baseUrl&\$expand=C_ProjectPhase(\$expand=C_ProjectTask),C_ProjectTask';

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
        url = '$baseUrl&\$expand=C_ProjectPhase(\$expand=C_ProjectTask)';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis Proyectos',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        leading: _showingFiles
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _showingFiles = false),
              )
            : null,
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
                  if (_currentPath[i] == 'Mis Proyectos') {
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
    dynamic currentLevel = _fileSystem;
    for (String part in _currentPath) {
      if (part == 'Mis Proyectos') continue;

      if (currentLevel is Map && currentLevel.containsKey(part)) {
        currentLevel = currentLevel[part];
        if (currentLevel is Map && currentLevel['type'] == 'folder') {
          currentLevel = currentLevel['children'];
        }
      } else {
        return const Center(child: Text("Ruta no encontrada."));
      }
    }

    if (currentLevel is! Map) {
      return const Center(child: Text("Contenido no válido."));
    }

    final items = currentLevel.entries.toList();

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final item = items[index];
        final name = item.key;
        final details = item.value as Map<String, dynamic>;
        final isFolder = details['type'] == 'folder';

        String size = '';
        if (isFolder) {
          final children = details['children'] as Map<String, dynamic>;
          size = '${children.length} archivo${children.length != 1 ? 's' : ''}';
        } else {
          size = details['size'] ?? '';
        }

        String extension = '';
        if (!isFolder) {
          extension = name.split('.').last.toUpperCase();
        }

        return _buildDeliverableCard(
          extension,
          name,
          size,
          details['color'] ?? Colors.grey,
          charLimit,
          isFolder: isFolder,
          details: details,
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
  }) {
    final status = details['status'] ?? 'Pendiente';
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
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Descargando $name...')));
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
                          : Text(
                              extension,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
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
                    _showPropertiesDialog(context, name, details);
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
    final status = details['status'] ?? 'Pendiente';
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
    final Map<String, dynamic> children = details['children'] ?? {};
    final pendingCount = children.values
        .where(
          (child) =>
              child is Map &&
              (child['status'] == 'Pendiente' || child['status'] == null),
        )
        .length;
    final reviewCount = children.values
        .where((child) => child is Map && child['status'] == 'En revisión')
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

  void _showPropertiesDialog(
    BuildContext context,
    String name,
    Map<String, dynamic> details,
  ) {
    final status = details['status'] ?? 'Pendiente';
    final statusColor = _getStatusColor(status);

    showDialog(
      context: context,
      builder: (context) {
        return CustomModal(
          title: 'Propiedades: ${name.split('.').first}',
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPropertyRow(
                  'Descripción',
                  details['description'] ?? 'No disponible',
                ),
                _buildPropertyRow(
                  'Tipo',
                  details['fileType'] ?? 'No disponible',
                ),
                _buildPropertyRow('Versión', details['version'] ?? 'N/A'),
                _buildPropertyRow(
                  'Fecha de entrega',
                  details['deliveryDate'] ?? 'No definida',
                ),
                _buildPropertyRow(
                  'Responsable',
                  details['owner'] ?? 'No asignado',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Estado: ',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          status,
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: statusColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        labelStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
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
        );
      },
    );
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _projects.length,
      itemBuilder: (context, index) {
        return _buildProjectCard(_projects[index]);
      },
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
        initiallyExpanded: true,
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
                _currentPath = ['Mis Proyectos', 'Entregables'];
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
                _currentPath = ['Mis Proyectos', 'Seguimiento'];
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
