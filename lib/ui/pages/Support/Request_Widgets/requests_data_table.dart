import 'dart:convert';
import 'package:flutter/material.dart';
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

class RequestsDataTable extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final Function(Map<String, dynamic>) onEdit;

  const RequestsDataTable({super.key, required this.requests, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: CustomTable(
        columns: [
          const DataColumn(label: Text('Ticket')),
          const DataColumn(label: Text('Tipo de Solicitud')),
          const DataColumn(label: Text('Asunto')),
          const DataColumn(label: Text('Tercero')),
          const DataColumn(label: Text('Usuario')),
          const DataColumn(label: Text('Nivel')),
          const DataColumn(label: Text('Ultima Actualización')),
          const DataColumn(label: Text('Descripción')),
          const DataColumn(label: Text('Estado')),
          const DataColumn(label: Text('Horas')),
          const DataColumn(label: Text('Acciones')),
        ],
        rows: requests.map((alert) {
          final double h = double.tryParse(alert['qtyPlan']?.toString() ?? '0.0') ?? 0.0;
          final String hoursStr = DurationFormatter.format(h);
          return DataRow(
            onSelectChanged: (value) => AccessControl.canManageRequests ? onEdit(alert) : null,
            cells: [
              DataCell(Text(alert['id'])),
              DataCell(Text(alert['situation'])),
              DataCell(
                Tooltip(
                  message: (alert['emailSubject'] != null && alert['emailSubject'].toString().trim().isNotEmpty) ? alert['emailSubject'].toString() : 'Sin asunto',
                  preferBelow: false,
                  child: SizedBox(width: 200, child: Text((alert['emailSubject']?.toString() ?? '').length > 25 ? '${(alert['emailSubject']?.toString() ?? '').substring(0, 25)}...' : (alert['emailSubject']?.toString() ?? ''))),
                ),
              ),
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
                  message: (alert['description'] != null && alert['description'].toString().trim().isNotEmpty) ? alert['description'].toString() : 'Sin descripción',
                  preferBelow: false,
                  child: SizedBox(width: 300, child: Text((alert['description']?.toString() ?? '').length > 70 ? '${(alert['description']?.toString() ?? '').substring(0, 70)}...' : (alert['description']?.toString() ?? ''))),
                ),
              ),
              DataCell(Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 8), Text(alert['status'])])),
              DataCell(Text(hoursStr)),
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
