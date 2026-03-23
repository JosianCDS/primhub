import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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

class RequestsDataTable extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final Map<String, int> statusIdMap;
  final Map<String, String> priorityMap;
  final Function(Map<String, dynamic>) onEdit;

  const RequestsDataTable({super.key, required this.requests, required this.statusIdMap, required this.priorityMap, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        headingRowHeight: 30,
        dataRowMinHeight: 30,
        dataRowMaxHeight: 40,
        columns: const [
          DataColumn(label: Text('Solicitud')),
          DataColumn(label: Text('Resumen')),
          DataColumn(label: Text('Tipo')),
          DataColumn(label: Text('Asunto')),
          DataColumn(label: Text('Categoría')),
          DataColumn(label: Text('Grupo')),
          DataColumn(label: Text('Estado')),
          DataColumn(label: Text('Prioridad')),
          DataColumn(label: Text('Fecha Fin Plan')),
          DataColumn(label: Text('Acciones')),
        ],
        rows: requests.map((req) {
          return DataRow(
            onSelectChanged: (selected) {
              if (selected == true) {
                if (AccessControl.canManageRequests) {
                  onEdit(req);
                } else if (AccessControl.canViewRequestDetails) {
                  showDialog(
                    context: context,
                    builder: (context) => RequestDetailsDialog(req: req),
                  );
                }
              }
            },
            cells: [
              DataCell(Text(req['id'].toString())),
              DataCell(
                Text(() {
                  final text = DocumentsLogic.extractValue(req['Summary']);
                  return text.length > 35 ? '${text.substring(0, 35)}...' : text;
                }()),
              ),
              DataCell(Text(DocumentsLogic.extractValue(req['R_RequestType_ID']))),
              DataCell(Text(req['CDS_EmailSubject']?.toString() ?? '')),
              DataCell(Text(DocumentsLogic.extractValue(req['R_Category_ID']))),
              DataCell(Text(DocumentsLogic.extractValue(req['R_Group_ID']))),
              DataCell(Text(DocumentsLogic.extractValue(req['R_Status_ID']))),
              DataCell(Text(DocumentsLogic.extractValue(req['Priority']))),
              DataCell(Text(req['DateCompletePlan']?.toString().split('T')[0] ?? '')),
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
                          builder: (context) => _RequestAttachmentsDialog(requestId: req['id'], documentNo: req['DocumentNo'] ?? req['id'].toString()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
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
