import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:primhub/ui/Shared_Custom/custom_table.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ImagesManagment/fecthAttachments.dart';
import 'package:primhub/ImagesManagment/postAttachments.dart';
import 'package:primhub/ImagesManagment/downloadAttachments.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/api/token.dart';
import 'package:primhub/ui/pages/Projects/Projects_Widgets/file_preview_manager.dart';
import 'package:primhub/ui/widgets/duration_formatter.dart';
import 'package:primhub/ui/pages/Support/Requests/bulk_edit_request_dialog.dart';
import 'dart:math';

class RequestsDataTable extends StatefulWidget {
  final List<Map<String, dynamic>> requests;
  final Function(Map<String, dynamic>) onEdit;
  final VoidCallback? onRefresh;

  const RequestsDataTable({super.key, required this.requests, required this.onEdit, this.onRefresh});

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

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_selectedIds.isNotEmpty && AccessControl.canManageRequests)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
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
            ),
          CustomTable(
            showCheckboxColumn: AccessControl.canManageRequests,
            onSelectAll: _handleSelectAll,
            columns: [
              const DataColumn(label: Text('#')),
              const DataColumn(label: Text('Acciones')),
              const DataColumn(label: Text('Ticket')),
              const DataColumn(label: Text('Tipo de Solicitud')),
              const DataColumn(label: Text('Asunto')),
              const DataColumn(label: Text('Categoría')),
              const DataColumn(label: Text('Tercero')),
              const DataColumn(label: Text('Usuario')),
              const DataColumn(label: Text('Nivel')),
              const DataColumn(label: Text('Ultima Actualización')),
              const DataColumn(label: Text('Descripción')),
              const DataColumn(label: Text('Estado')),
              const DataColumn(label: Text('Horas')),
            ],
            rows: widget.requests.asMap().entries.map((entry) {
              final int index = entry.key;
              final Map<String, dynamic> alert = entry.value;
              final double h = double.tryParse(alert['qtyPlan']?.toString() ?? '0.0') ?? 0.0;
              final String hoursStr = DurationFormatter.format(h);
              final int realId = _getRealId(alert);
              return DataRow(
                selected: _selectedIds.contains(realId),
                onSelectChanged: AccessControl.canManageRequests ? (selected) => _handleRowSelection(selected, index, realId) : null,
                cells: [
                  DataCell(Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(AccessControl.canAddUpdates ? Icons.reply : Icons.forum),
                          tooltip: AccessControl.canAddUpdates ? 'Responder Solicitud' : 'Ver Actualizaciones',
                          onPressed: () {
                            final id = Uri.encodeComponent(alert['realId'].toString());
                            GoRouter.of(context).push('/request-updates/$id', extra: {'docNo': alert['id']});
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.attach_file),
                          tooltip: 'Ver / Añadir Adjuntos',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => _RequestAttachmentsDialog(requestId: alert['realId'], documentNo: alert['id']),
                            );
                          },
                        ),
                        if (AccessControl.canManageRequests) IconButton(icon: const Icon(Icons.edit), tooltip: 'Editar', onPressed: () => widget.onEdit(alert)),
                      ],
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(alert['id'].toString()),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: alert['id'].toString()));
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
                  DataCell(Text(alert['situation'])),
                  DataCell(
                    Tooltip(
                      message: (alert['emailSubject'] != null && alert['emailSubject'].toString().trim().isNotEmpty) ? alert['emailSubject'].toString() : 'Sin asunto',
                      preferBelow: false,
                      child: SizedBox(width: 200, child: Text((alert['emailSubject']?.toString() ?? '').length > 25 ? '${(alert['emailSubject']?.toString() ?? '').substring(0, 25)}...' : (alert['emailSubject']?.toString() ?? ''))),
                    ),
                  ),
                  DataCell(Text(alert['category']?.toString() ?? 'Sin categoría')),
                  DataCell(Text(alert['bpName']?.toString() ?? '')),
                  DataCell(Text(alert['userName']?.toString() ?? '')),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: alert['levelBgColor'], borderRadius: BorderRadius.circular(30)),
                      child: Text(
                        alert['level'],
                        style: TextStyle(color: alert['levelColor'], fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  DataCell(Text(alert['time'] ?? '')),
                  DataCell(
                    Tooltip(
                      message: (alert['descriptionClean'] != null && alert['descriptionClean'].toString().trim().isNotEmpty) ? alert['descriptionClean'].toString() : 'Sin descripción',
                      preferBelow: false,
                      child: SizedBox(width: 300, child: Text((alert['descriptionClean']?.toString() ?? '').length > 70 ? '${(alert['descriptionClean']?.toString() ?? '').substring(0, 70)}...' : (alert['descriptionClean']?.toString() ?? ''))),
                    ),
                  ),
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 8), Text(alert['status'])])),
                  DataCell(Text(hoursStr)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
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
