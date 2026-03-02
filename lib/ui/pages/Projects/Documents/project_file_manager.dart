import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/ImagesManagment/downloadAttachments.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/ui/pages/Projects/Projects_Widgets/breadcrumb_navigator.dart';
import 'package:primhub/ui/pages/Projects/Projects_Widgets/file_card.dart';
import 'package:primhub/ui/pages/Projects/Projects_Widgets/file_preview_manager.dart';
import 'package:primhub/ui/shared/custom_button.dart';
import 'package:primhub/ui/shared/custom_inputs.dart';
import 'package:primhub/ui/shared/custom_modal.dart';

class ProjectFileManager extends StatefulWidget {
  final Map<String, dynamic> project;
  final String viewType; // 'Entregables', 'Seguimiento', 'General'
  final VoidCallback onExit;
  final ValueChanged<bool>? onRootChanged;

  const ProjectFileManager({super.key, required this.project, required this.viewType, required this.onExit, this.onRootChanged});

  @override
  State<ProjectFileManager> createState() => ProjectFileManagerState();
}

class ProjectFileManagerState extends State<ProjectFileManager> {
  List<String> _currentPath = [];
  List<dynamic> _documents = [];
  bool _isLoadingDocuments = false;
  bool _isDragging = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  int? _downloadingId;

  @override
  void initState() {
    super.initState();
    _currentPath = ['Mis Proyectos', widget.project['Name'] ?? 'Proyecto', widget.viewType];
    _fetchDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _notifyRootChanged() => widget.onRootChanged?.call(isRoot());
  void refresh() => _fetchDocuments();
  bool isRoot() => _currentPath.length <= 3;

  bool navigateBack() {
    if (_currentPath.length > 3) {
      setState(() {
        _currentPath.removeLast();
        _notifyRootChanged();
      });
      return true;
    }
    return false;
  }

  Future<void> _fetchDocuments() async {
    setState(() => _isLoadingDocuments = true);
    final docs = await DocumentsLogic.fetchDocuments(projectId: widget.project['id'], viewType: widget.viewType, currentPath: _currentPath);
    if (mounted) {
      setState(() {
        _documents = docs;
        _isLoadingDocuments = false;
      });
      if (docs.isEmpty && _currentPath.length > 3) context.go('/login'); // Simple auth check fallback
    }
  }

  Future<void> pickAndUploadFile() async {
    if (!AccessControl.canManageFiles) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tienes permisos para subir archivos.')));
      return;
    }
    FilePickerResult? result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    setState(() => _isLoadingDocuments = true);
    final success = await DocumentsLogic.uploadFile(fileName: result.files.first.name, fileBytes: result.files.first.bytes!, projectId: widget.project['id'], viewType: widget.viewType, currentPath: _currentPath, documents: _documents);
    if (success)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archivo subido correctamente')));
    else
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al subir archivo')));
    _fetchDocuments();
  }

  Future<void> createFolderDialog() async {
    if (!AccessControl.canManageFiles) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tienes permisos para crear carpetas.')));
      return;
    }
    final TextEditingController controller = TextEditingController();
    final bool? create = await showDialog<bool>(
      context: context,
      builder: (context) => CustomModal(
        title: 'Nueva Carpeta',
        content: CustomTextField(controller: controller, label: 'Nombre de la carpeta'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          CustomButton(text: 'Crear', onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (create == true && controller.text.isNotEmpty) {
      setState(() => _isLoadingDocuments = true);
      final success = await DocumentsLogic.createFolder(name: controller.text, projectId: widget.project['id'], viewType: widget.viewType, currentPath: _currentPath, documents: _documents);
      if (success)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Carpeta creada correctamente')));
      else
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al crear carpeta')));
      _fetchDocuments();
    }
  }

  Future<void> _deleteFile(int id, String tableName, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => CustomModal(
        title: 'Eliminar Archivo',
        content: Text('¿Estás seguro de que deseas eliminar "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          CustomButton(text: 'Eliminar', backgroundColor: Colors.red, onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (confirm == true) {
      if (Navigator.canPop(context)) Navigator.pop(context); // Close preview if open
      setState(() => _isLoadingDocuments = true);
      final success = await DocumentsLogic.deleteFile(id, tableName);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archivo eliminado')));
        _fetchDocuments();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al eliminar')));
        setState(() => _isLoadingDocuments = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DropTarget(
      onDragDone: (details) async {
        if (!AccessControl.canManageFiles) return;
        setState(() => _isLoadingDocuments = true);
        for (final file in details.files) await DocumentsLogic.uploadFile(fileName: file.name, fileBytes: await file.readAsBytes(), projectId: widget.project['id'], viewType: widget.viewType, currentPath: _currentPath, documents: _documents);
        _fetchDocuments();
      },
      onDragEntered: (details) => setState(() => _isDragging = true),
      onDragExited: (details) => setState(() => _isDragging = false),
      child: Container(
        color: _isDragging ? theme.colorScheme.primary.withOpacity(0.1) : null,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: CustomTextField(controller: _searchController, hintText: 'Buscar documento...', prefixIcon: const Icon(Icons.search)),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: _searchController.text.isNotEmpty
                            ? _buildSearchResults()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_currentPath.length > 1)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 16.0),
                                      child: BreadcrumbNavigator(
                                        currentPath: _currentPath,
                                        onNavigate: (i) => i <= 1
                                            ? widget.onExit()
                                            : setState(() {
                                                _currentPath = _currentPath.sublist(0, i + 1);
                                                _notifyRootChanged();
                                              }),
                                      ),
                                    ),
                                  _buildContentGrid(2, 0.75, constraints.maxWidth < 600 ? 12 : 25),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoadingDocuments) return const Center(child: CircularProgressIndicator());
    if (_searchResults.isEmpty) return const Center(child: Text('No se encontraron documentos.'));
    final results = DocumentsLogic.performSearch(_searchController.text, _documents, _currentPath.sublist(0, 3));

    return ListView.builder(
      shrinkWrap: true,
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        final doc = result['doc'] as Map<String, dynamic>;
        final path = result['path'] as List<String>;
        final docName = doc['Name'] as String? ?? 'Sin Nombre';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(DocumentsLogic.getFileIcon(DocumentsLogic.extractIdentifier(doc['Extension'], defaultValue: ''))),
            title: Text(docName),
            subtitle: Text('Ubicación: ${path.length > 3 ? path.sublist(3).join(' / ') : 'Principal'}'),
            trailing: AccessControl.canDownloadFiles
                ? (_downloadingId == doc['id']
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: () async {
                            final tableName = path.length > 3 ? Endpoint.primDocumentsRelated : Endpoint.primDocuments;
                            setState(() => _downloadingId = doc['id']);
                            await downloadAttachment(
                              context: context,
                              recordID: doc['id'],
                              tableName: tableName,
                              fileName: docName,
                              onStatusChanged: () async {
                                await _fetchDocuments();
                                setState(() {}); // Trigger rebuild for search
                              },
                            );
                            if (mounted) setState(() => _downloadingId = null);
                          },
                        ))
                : null,
            onTap: () {
              setState(() {
                _currentPath = path;
                _searchController.clear();
                _notifyRootChanged();
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildContentGrid(int crossAxisCount, double childAspectRatio, int charLimit) {
    if (_isLoadingDocuments) return const Center(child: CircularProgressIndicator());
    List<dynamic> currentItems = List.from(_documents);
    String tableName = Endpoint.primDocuments;

    if (_currentPath.length > 3) {
      final folderName = _currentPath.last;
      final folder = _documents.firstWhere((doc) => doc['Name'] == folderName && (doc['IsSummary'] == true || doc['IsSummary'] == 'Y'), orElse: () => null);
      if (folder != null) {
        String typeCode = widget.viewType == 'Entregables' ? 'ET' : (widget.viewType == 'Seguimiento' ? 'SG' : 'GN');
        final allChildren = folder['PRIM_Documents_Related'] as List? ?? [];
        currentItems = allChildren.where((child) => (child['Type'] is Map ? child['Type']['id']?.toString() : child['Type']?.toString()) == typeCode).toList();
        tableName = Endpoint.primDocumentsRelated;
      }
    }

    currentItems.sort((a, b) {
      final isFolderA = a['IsSummary'] == true || a['IsSummary'] == 'Y';
      final isFolderB = b['IsSummary'] == true || b['IsSummary'] == 'Y';

      if (isFolderA && !isFolderB) return -1;
      if (!isFolderA && isFolderB) return 1;

      final dateA = DateTime.tryParse(a['Created'] ?? '') ?? DateTime(0);
      final dateB = DateTime.tryParse(b['Created'] ?? '') ?? DateTime(0);
      return dateA.compareTo(dateB);
    });

    if (currentItems.isEmpty)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text("No hay documentos.", style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, crossAxisSpacing: 20, mainAxisSpacing: 20, childAspectRatio: childAspectRatio),
      itemCount: currentItems.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final item = currentItems[index];
        final name = item['Name'] ?? 'Sin Nombre';
        final isFolder = item['IsSummary'] == true || item['IsSummary'] == 'Y';
        final children = isFolder ? (item['PRIM_Documents_Related'] as List? ?? []) : [];
        String size = isFolder ? '${children.length} archivo${children.length != 1 ? 's' : ''}' : '';
        String extension = DocumentsLogic.extractIdentifier(item['Extension'], defaultValue: '');
        if (extension.isEmpty && !isFolder && name.contains('.')) extension = name.split('.').last;

        return FileCard(
          extension: extension,
          name: name,
          size: size,
          color: isFolder ? Colors.amber : Colors.blue,
          charLimit: charLimit,
          isFolder: isFolder,
          details: item,
          onTap: () => isFolder
              ? setState(() {
                  _currentPath.add(name);
                  _notifyRootChanged();
                })
              : FilePreviewManager.showPreview(context, item, tableName, name, () => _deleteFile(item['id'], tableName, name), () {
                  _fetchDocuments();
                  if (AccessControl.isProject)
                    setState(() {
                      item['Status'] = 'Entregado';
                    });
                }),
          onProperties: () => _showPropertiesDialog(context, name, item, tableName),
        );
      },
    );
  }

  void _showPropertiesDialog(BuildContext context, String name, Map<String, dynamic> details, String tableName) {
    final status = DocumentsLogic.extractStatus(details['Status']);
    final bool isFolder = details['IsSummary'] == true || details['IsSummary'] == 'Y';

    final TextEditingController nameController = TextEditingController(text: details['Name']);
    final TextEditingController descController = TextEditingController(text: details['Description']?.toString() ?? '');
    final TextEditingController versionController = TextEditingController(text: details['VersionNo']?.toString() ?? '');
    String currentStatus = status;
    bool isSaving = false;
    String typeCode = (details['Type'] is Map ? details['Type']['id']?.toString() : details['Type']?.toString()) ?? '';

    final List<String> statuses = ['Pendiente', 'En revisión', 'Entregado'];
    if (!statuses.contains(currentStatus)) statuses.add(currentStatus);

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
                    CustomTextField(controller: nameController, label: 'Nombre', readOnly: true),
                    const SizedBox(height: 16),
                    CustomTextField(controller: descController, label: 'Descripción', maxLines: 3),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(controller: versionController, label: 'Versión'),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: isFolder
                              ? CustomTextField(
                                  controller: TextEditingController(text: currentStatus),
                                  label: 'Estado',
                                  readOnly: true,
                                )
                              : CustomDropdown<String>(
                                  value: currentStatus,
                                  label: 'Estado',
                                  items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                  onChanged: (val) {
                                    if (val != null) setStateDialog(() => currentStatus = val);
                                  },
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildPropertyRow('Tipo', typeCode == 'ET' ? 'Entregable' : (typeCode == 'SG' ? 'Seguimiento' : 'General')),
                    _buildPropertyRow('Extensión', DocumentsLogic.extractIdentifier(details['Extension'])),
                    _buildPropertyRow('Creado', DocumentsLogic.formatDate(details['Created'])),
                    _buildPropertyRow('Creado Por', DocumentsLogic.extractIdentifier(details['CreatedBy'], defaultValue: 'Sistema')),
                  ],
                ),
              ),
              actions: [
                if (AccessControl.canManageFiles)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteFile(details['id'], tableName, name);
                    },
                  ),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                CustomButton(
                  text: 'Guardar',
                  isLoading: isSaving,
                  onPressed: !AccessControl.canManageFiles
                      ? null
                      : () async {
                          setStateDialog(() => isSaving = true);
                          final body = <String, dynamic>{'Description': descController.text, 'VersionNo': versionController.text};
                          if (!isFolder) {
                            const statusCodes = {'Pendiente': 'PD', 'En revisión': 'IR', 'Entregado': 'DL'};
                            body['Status'] = statusCodes[currentStatus] ?? currentStatus;
                          }
                          final success = await DocumentsLogic.updateDocumentRemote(details['id'], body);
                          setStateDialog(() => isSaving = false);
                          if (success) {
                            if (context.mounted) {
                              Navigator.pop(context);
                              _fetchDocuments();
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
}
