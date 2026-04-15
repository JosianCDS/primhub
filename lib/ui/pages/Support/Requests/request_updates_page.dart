import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:primhub/api/access_control.dart';

class RequestUpdatesPage extends StatefulWidget {
  final int requestId;
  final String docNo;

  const RequestUpdatesPage({super.key, required this.requestId, required this.docNo});

  @override
  State<RequestUpdatesPage> createState() => _RequestUpdatesPageState();
}

class _RequestUpdatesPageState extends State<RequestUpdatesPage> {
  late Future<List<Map<String, dynamic>>> _updatesFuture;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _refreshUpdates();
  }

  void _refreshUpdates() {
    setState(() {
      _currentIndex = 0;
      _updatesFuture = fetchRequestUpdates(widget.requestId);
    });
  }

  Future<void> _addUpdate() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _AddUpdateDialog(requestId: widget.requestId),
    );

    if (result == true) {
      _refreshUpdates();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Actualizaciones para la Solicitud ${widget.docNo}')),
      floatingActionButton: AccessControl.canAddUpdates ? FloatingActionButton(onPressed: _addUpdate, tooltip: 'Añadir Actualización', child: const Icon(Icons.add_comment)) : null,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _updatesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay actualizaciones para esta solicitud.'));
          }

          final updates = snapshot.data!;
          return Column(
            children: [
              if (updates.length > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(icon: const Icon(Icons.chevron_left), onPressed: _currentIndex > 0 ? () => setState(() => _currentIndex--) : null),
                      Text('Actualización ${_currentIndex + 1} de ${updates.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(icon: const Icon(Icons.chevron_right), onPressed: _currentIndex < updates.length - 1 ? () => setState(() => _currentIndex++) : null),
                    ],
                  ),
                ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: SingleChildScrollView(
                    key: ValueKey<int>(_currentIndex),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _UpdateCard(update: updates[_currentIndex]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  final Map<String, dynamic> update;
  const _UpdateCard({required this.update});

  @override
  Widget build(BuildContext context) {
    final created = DateTime.tryParse(update['Created'] ?? '')?.toLocal();
    final formattedDate = created != null ? '${created.day}/${created.month}/${created.year} a las ${created.hour}:${created.minute.toString().padLeft(2, '0')}' : 'Fecha desconocida';
    final result = update['Result'] ?? 'Sin resultado.';
    final confidential = update['ConfidentialTypeEntry']?['identifier'] ?? 'N/A';
    final isPrinted = update['IsPrinted'] == true;

    final List<int> imageIds = [];
    for (String key in ['AD_Image_ID', 'AD_Image1_ID', 'AD_Image2_ID', 'AD_Image3_ID']) {
      if (update[key] != null) {
        if (update[key] is Map && update[key]['id'] != null) {
          imageIds.add(update[key]['id'] is int ? update[key]['id'] : int.tryParse(update[key]['id'].toString()) ?? 0);
        } else if (update[key] is int) {
          imageIds.add(update[key]);
        } else if (update[key] is String && int.tryParse(update[key]) != null) {
          imageIds.add(int.parse(update[key]));
        }
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formattedDate, style: Theme.of(context).textTheme.bodySmall),
                Wrap(
                  spacing: 8.0,
                  children: [
                    Chip(
                      label: Text(confidential, style: const TextStyle(fontSize: 10)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      label: Text(isPrinted ? 'Impreso' : 'No Impreso', style: const TextStyle(fontSize: 10)),
                      avatar: Icon(isPrinted ? Icons.print_outlined : Icons.print_disabled_outlined, size: 12),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            Html(
              data: result,
              style: {"body": Style(margin: Margins.zero, padding: HtmlPaddings.zero)},
            ),
            if (imageIds.isNotEmpty) ...[const SizedBox(height: 12), Wrap(spacing: 8, runSpacing: 8, children: imageIds.map((id) => _ImagePreview(imageId: id)).toList())],
          ],
        ),
      ),
    );
  }
}

class _AddUpdateDialog extends StatefulWidget {
  final int requestId;
  const _AddUpdateDialog({required this.requestId});

  @override
  State<_AddUpdateDialog> createState() => _AddUpdateDialogState();
}

class _AddUpdateDialogState extends State<_AddUpdateDialog> {
  final _resultController = TextEditingController();
  String _confidentialType = 'I'; // Internal
  bool _isPrinted = false;
  List<PlatformFile?> _evidences = [null, null, null, null];
  bool _isSaving = false;

  Future<void> _pickFile(int index) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);

    if (result != null && result.files.isNotEmpty) {
      if (result.files.first.bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al leer la imagen. Verifique que no sea un archivo en la nube o intente con otro formato.'), backgroundColor: Colors.orange));
        return;
      }
      setState(() {
        _evidences[index] = result.files.first;
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _evidences[index] = null;
    });
  }

  Future<void> _handleSave() async {
    if (_resultController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El campo de resultado no puede estar vacío.'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isSaving = true);

    final result = await createRequestUpdate(requestId: widget.requestId, resultText: _resultController.text, confidentialType: _confidentialType, isPrinted: _isPrinted, evidences: _evidences);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Error desconocido'), backgroundColor: result['success'] == true ? Colors.green : Colors.red));
      if (result['success'] == true) {
        Navigator.of(context).pop(true);
      }
    }
  }

  Widget _buildEvidenceField(int index) {
    final file = _evidences[index];
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                file != null ? file.name : 'Evidencia ${index + 1} (Sin archivo)',
                style: TextStyle(color: file != null ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (file == null) IconButton(icon: const Icon(Icons.attach_file), onPressed: () => _pickFile(index), tooltip: 'Adjuntar Imagen', color: theme.colorScheme.primary) else IconButton(icon: const Icon(Icons.delete), onPressed: () => _removeFile(index), tooltip: 'Eliminar Imagen', color: theme.colorScheme.error),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomModal(
      title: 'Añadir Actualización',
      width: 600,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomTextField(controller: _resultController, label: 'Resultado o comentario *', maxLines: 5),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CustomDropdown<String>(
                    label: 'Confidencialidad',
                    value: _confidentialType,
                    items: const [
                      DropdownMenuItem(value: 'I', child: Text('Nota Interna')),
                      DropdownMenuItem(value: 'C', child: Text('Visible para Cliente')),
                      DropdownMenuItem(value: 'P', child: Text('Público')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _confidentialType = val);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Impreso'),
                    value: _isPrinted,
                    onChanged: (val) {
                      if (val != null) setState(() => _isPrinted = val);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Evidencias (Opcional, hasta 4 imágenes):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildEvidenceField(0),
            _buildEvidenceField(1),
            _buildEvidenceField(2),
            _buildEvidenceField(3),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isSaving ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
        CustomButton(text: 'Guardar', onPressed: _handleSave, isLoading: _isSaving),
      ],
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final int imageId;
  const _ImagePreview({required this.imageId});

  Future<Uint8List?> _fetchImage() async {
    try {
      final url = '${Endpoint.baseUrl}/api/v1/models/AD_Image/$imageId?\$select=BinaryData';
      var response = await http.get(Uri.parse(url), headers: {'Authorization': Token.token});
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final binaryData = data['BinaryData'];
        if (binaryData is String && binaryData.isNotEmpty) {
          return base64Decode(binaryData);
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _fetchImage(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(width: 80, height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        if (snapshot.hasData && snapshot.data != null) {
          return InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      InteractiveViewer(child: Image.memory(snapshot.data!)),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(snapshot.data!, width: 80, height: 80, fit: BoxFit.cover),
            ),
          );
        }
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
        );
      },
    );
  }
}
