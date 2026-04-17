import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:primhub/ui/Shared_Custom/custom_table.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/ui/pages/Projects/dialogs/request_details_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/ui/pages/Support/Requests/edit_request_dialog.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ImagesManagment/fecthAttachments.dart';
import 'package:primhub/ImagesManagment/postAttachments.dart';
import 'package:primhub/ImagesManagment/downloadAttachments.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/api/token.dart';
import 'package:primhub/ui/pages/Projects/Projects_Widgets/file_preview_manager.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';
import 'package:primhub/ui/pages/Support/Requests/bulk_edit_request_dialog.dart';
import 'dart:math';

class RequestsDataTable extends StatefulWidget {
  final List<Map<String, dynamic>> requests;
  final Map<String, int> statusIdMap;
  final Map<String, String> priorityMap;
  final Function(Map<String, dynamic>) onEdit;
  final VoidCallback? onRefresh;
  final bool showProjectContext;

  const RequestsDataTable({super.key, required this.requests, required this.statusIdMap, required this.priorityMap, required this.onEdit, this.onRefresh, this.showProjectContext = false});

  @override
  State<RequestsDataTable> createState() => _RequestsDataTableState();
}

class _RequestsDataTableState extends State<RequestsDataTable> {
  final Set<int> _selectedIds = {};
  int? _lastSelectedIndex;

  int _getRealId(Map<String, dynamic> req) => req['realId'] ?? req['_rawId'] ?? int.tryParse(req['id'].toString()) ?? 0;

  void _handleRowSelection(bool? selected, int index, int realId) {
    final isShiftPressed = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) || HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight);

    setState(() {
      if (isShiftPressed && _lastSelectedIndex != null) {
        int start = min(_lastSelectedIndex!, index);
        int end = max(_lastSelectedIndex!, index);
        for (int i = start; i <= end; i++) {
          final id = _getRealId(widget.requests[i]);
          if (selected == true)
            _selectedIds.add(id);
          else
            _selectedIds.remove(id);
        }
      } else {
        if (selected == true)
          _selectedIds.add(realId);
        else
          _selectedIds.remove(realId);
        _lastSelectedIndex = index;
      }
    });
  }

  void _handleSelectAll(bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedIds.addAll(widget.requests.map((r) => _getRealId(r)));
      } else {
        _selectedIds.clear();
      }
      _lastSelectedIndex = null;
    });
  }

  void _handleRowClick(Map<String, dynamic> req) {
    if (AccessControl.canManageRequests) {
      widget.onEdit(req);
    } else if (AccessControl.canViewRequestDetails) {
      showDialog(
        context: context,
        builder: (context) => RequestDetailsDialog(req: req),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomTable(
              showCheckboxColumn: !AccessControl.isProject && (AccessControl.canManageRequests || AccessControl.canViewRequestDetails),
              onSelectAll: _handleSelectAll,
              columns: [
                const DataColumn(label: Text('#')),
                const DataColumn(label: Text('Acciones')),
                const DataColumn(label: Text('Solicitud')),
                const DataColumn(label: Text('Resumen')),
                if (widget.showProjectContext) const DataColumn(label: Text('Fase')),
                if (widget.showProjectContext) const DataColumn(label: Text('Tarea')),
                const DataColumn(label: Text('Tipo')),
                const DataColumn(label: Text('Asunto')),
                const DataColumn(label: Text('Categoría')),
                if (!AccessControl.isProject) const DataColumn(label: Text('Usuario')),
                if (!AccessControl.isProject) const DataColumn(label: Text('Representante Comercial')),
                const DataColumn(label: Text('Grupo')),
                const DataColumn(label: Text('Estado')),
                const DataColumn(label: Text('Prioridad')),
                const DataColumn(label: Text('Fecha Fin Plan')),
              ],
              rows: widget.requests.asMap().entries.map((entry) {
                final int index = entry.key;
                final Map<String, dynamic> req = entry.value;
                final int realId = _getRealId(req);
                return DataRow(
                  selected: _selectedIds.contains(realId),
                  onSelectChanged: (_) => _handleRowClick(req),
                  cells: [
                    if (AccessControl.canManageRequests) DataCell(Checkbox(value: _selectedIds.contains(realId), onChanged: (selected) => _handleRowSelection(selected, index, realId))),
                    DataCell(Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(AccessControl.canAddUpdates ? Icons.reply : Icons.forum),
                            tooltip: AccessControl.canAddUpdates ? 'Responder Solicitud' : 'Ver Actualizaciones',
                            onPressed: () {
                              final id = Uri.encodeComponent(req['id'].toString());
                              GoRouter.of(context).push('/request-updates/$id', extra: {'docNo': req['DocumentNo'] ?? req['id'].toString()});
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.attach_file),
                            tooltip: 'Ver / Añadir Adjuntos',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => _RequestAttachmentsDialog(requestId: req['_rawId'] ?? req['realId'] ?? int.tryParse(req['id'].toString()) ?? 0, documentNo: req['DocumentNo']?.toString() ?? req['id'].toString()),
                              );
                            },
                          ),
                          if (AccessControl.canManageRequests)
                            IconButton(icon: const Icon(Icons.edit), tooltip: 'Editar', onPressed: () => widget.onEdit(req))
                          else if (AccessControl.canViewRequestDetails)
                            IconButton(
                              icon: const Icon(Icons.visibility),
                              tooltip: 'Ver Detalles',
                              onPressed: () => showDialog(
                                context: context,
                                builder: (context) => RequestDetailsDialog(req: req),
                              ),
                            ),
                        ],
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(req['id'].toString()),
                          const SizedBox(width: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: req['id'].toString()));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código copiado al portapapeles')));
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(Icons.copy, size: 16, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Tooltip(
                        message: stripHtmlTags(DocumentsLogic.extractValue(req['Summary'])),
                        child: Text(() {
                          final text = stripHtmlTags(DocumentsLogic.extractValue(req['Summary']));
                          return text.length > 35 ? '${text.substring(0, 35)}...' : text;
                        }()),
                      ),
                    ),
                    if (widget.showProjectContext) DataCell(Text(req['phaseName'] ?? '-')),
                    if (widget.showProjectContext) DataCell(Text(req['taskName'] ?? 'General')),
                    DataCell(Text(DocumentsLogic.extractValue(req['R_RequestType_ID']))),
                    DataCell(
                      Tooltip(
                        message: req['CDS_EmailSubject']?.toString() ?? '',
                        child: Text(() {
                          final text = req['CDS_EmailSubject']?.toString() ?? '';
                          return text.length > 25 ? '${text.substring(0, 25)}...' : text;
                        }()),
                      ),
                    ),
                    DataCell(Text(DocumentsLogic.extractValue(req['R_Category_ID']))),
                    if (AccessControl.isAdmin) DataCell(Text(DocumentsLogic.extractValue(req['C_BPartner_ID']))),
                    if (AccessControl.isAdmin) DataCell(Text(DocumentsLogic.extractValue(req['AD_User_ID']))),
                    if (AccessControl.isAdmin) DataCell(Text(DocumentsLogic.extractValue(req['SalesRep_ID']))),
                    DataCell(Text(DocumentsLogic.extractValue(req['R_Group_ID']))),
                    DataCell(Text(DocumentsLogic.extractValue(req['R_Status_ID']))),
                    DataCell(Text(DocumentsLogic.extractValue(req['Priority']))),
                    DataCell(Text(req['DateCompletePlan']?.toString().split('T')[0] ?? '')),
                  ],
                );
              }).toList(),
            ),
            // Espaciador animado para permitir scroll debajo del Toast flotante
            AnimatedContainer(duration: const Duration(milliseconds: 250), height: _selectedIds.isNotEmpty && AccessControl.canManageRequests ? 80.0 : 0.0),
          ],
        ),
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(animation),
                child: child,
              ),
            ),
            child: _selectedIds.isNotEmpty && AccessControl.canManageRequests
                ? Container(
                    key: const ValueKey('action_bar'),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_box, color: Theme.of(context).colorScheme.onSecondaryContainer),
                        const SizedBox(width: 8),
                        Text(
                          '${_selectedIds.length} solicitudes seleccionadas',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSecondaryContainer),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() {
                            _selectedIds.clear();
                            _lastSelectedIndex = null;
                          }),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.edit),
                          label: const Text('Edición Masiva'),
                          onPressed: () => showDialog(
                            context: context,
                            builder: (context) => BulkEditRequestDialog(
                              selectedIds: _selectedIds,
                              onSaved: () {
                                setState(() {
                                  _selectedIds.clear();
                                  _lastSelectedIndex = null;
                                });
                                widget.onRefresh?.call();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('empty_bar')),
          ),
        ),
      ],
    );
  }
}

class _RequestAttachmentsDialog extends StatefulWidget {
  final int requestId;
  final String documentNo;

  const _RequestAttachmentsDialog({required this.requestId, required this.documentNo});

  @override
  State<_RequestAttachmentsDialog> createState() => _RequestAttachmentsDialogState();
}

class _RequestAttachmentsDialogState extends State<_RequestAttachmentsDialog> {
  List<Map<String, dynamic>> _attachments = [];
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadAttachments();
  }

  Future<void> _loadAttachments() async {
    setState(() => _isLoading = true);
    final tableName = '${Endpoint.baseUrl}/api/v1/models/R_Request';
    final attachments = await fetchAttachments(recordID: widget.requestId, tableName: tableName);
    if (mounted) {
      setState(() {
        _attachments = attachments;
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadAttachment() async {
    if (!AccessControl.canManageFiles) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tienes permisos para subir archivos.')));
      return;
    }

    if (_attachments.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solo se pueden subir 4 Adjuntos'), backgroundColor: Colors.orange));
      return;
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;

    setState(() => _isUploading = true);

    final tableName = '${Endpoint.baseUrl}/api/v1/models/R_Request';
    final file = result.files.first;

    final convertedFile = {'title': file.name, 'base64': base64Encode(file.bytes!)};
    final success = await postAttachments(recordID: widget.requestId, tableName: tableName, convertedFile: convertedFile);

    if (mounted) {
      setState(() => _isUploading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archivo subido correctamente')));
        _loadAttachments();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al subir archivo'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tableName = '${Endpoint.baseUrl}/api/v1/models/R_Request';

    return CustomModal(
      title: 'Adjuntos: ${widget.documentNo}',
      width: 500,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_attachments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: Text('No hay archivos adjuntos en esta solicitud.')),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              itemCount: _attachments.length,
              itemBuilder: (context, index) {
                final att = _attachments[index];
                return ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: Text(att['name'] ?? 'Sin nombre'),
                  onTap: () {
                    FilePreviewManager.showPreview(context, {'id': widget.requestId, 'Status': 'N/A', 'VersionNo': 'N/A'}, tableName, att['name'] ?? '', () async {
                      try {
                        setState(() => _isLoading = true);
                        final url = Uri.parse('$tableName/${widget.requestId}/attachments/${Uri.encodeComponent(att['name'] ?? '')}');
                        final response = await http.delete(url, headers: {'Authorization': Token.token});
                        if (response.statusCode == 200 || response.statusCode == 204) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adjunto eliminado')));
                            _loadAttachments();
                          }
                        } else {
                          if (mounted) {
                            setState(() => _isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al eliminar adjunto'), backgroundColor: Colors.red));
                          }
                        }
                      } catch (e) {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    }, () {});
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.download, color: Color(0xFF4F47E5)),
                    tooltip: 'Descargar',
                    onPressed: () => downloadAttachment(context: context, recordID: widget.requestId, tableName: tableName, fileName: att['name']),
                  ),
                );
              },
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        if (AccessControl.canManageFiles) CustomButton(text: 'Subir Archivo', icon: Icons.upload_file, isLoading: _isUploading, onPressed: _uploadAttachment),
      ],
    );
  }
}
