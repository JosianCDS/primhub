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
  Map<String, dynamic>? _requestDetails;
  bool _isLoadingDetails = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
    _refreshUpdates();
  }

  Future<void> _fetchDetails() async {
    try {
      final reqs = await fetchRequest(filter: "R_Request_ID eq ${widget.requestId}");
      if (reqs.isNotEmpty && mounted) {
        setState(() {
          _requestDetails = reqs.first;
          _isLoadingDetails = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  void _refreshUpdates() {
    setState(() {
      _updatesFuture = fetchRequestUpdates(widget.requestId).then((list) {
        // Ordenar por fecha de creación descendente (más recientes arriba)
        list.sort((a, b) {
          final dateA = DateTime.tryParse(a['Created'] ?? '') ?? DateTime(1900);
          final dateB = DateTime.tryParse(b['Created'] ?? '') ?? DateTime(1900);
          return dateB.compareTo(dateA);
        });
        return list;
      });
    });
  }

  Future<void> _addUpdate() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _AddUpdateDialog(
        requestId: widget.requestId,
        summary: _requestDetails?['Summary'] ?? _requestDetails?['description'] ?? 'Sin resumen.',
      ),
    );

    if (result == true) {
      _refreshUpdates();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text('Actualizaciones: ${widget.docNo}')),
      floatingActionButton: AccessControl.canAddUpdates
          ? FloatingActionButton.extended(
              onPressed: _addUpdate,
              label: Text('Responder', style: textTheme.labelLarge?.copyWith(color: colorScheme.onPrimary, fontWeight: FontWeight.bold)),
              icon: Icon(Icons.reply, color: colorScheme.onPrimary),
            )
          : null,
      body: Column(
        children: [
          // Cabecera Desplegable con el resumen de la solicitud
          if (_requestDetails != null)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                backgroundColor: colorScheme.surface,
                collapsedBackgroundColor: colorScheme.surface,
                shape: Border(bottom: BorderSide(color: colorScheme.outlineVariant, width: 1)),
                collapsedShape: Border(bottom: BorderSide(color: colorScheme.outlineVariant, width: 1)),
                title: Text(
                  'RESUMEN DE LA SOLICITUD',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    letterSpacing: 1.1,
                  ),
                ),
                leading: Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4, // Límite de expansión
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(
                        _requestDetails?['Summary'] ?? _requestDetails?['description'] ?? 'Sin descripción.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _updatesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: colorScheme.outline),
                        const SizedBox(height: 16),
                        Text('No hay respuestas aún', style: textTheme.bodyLarge?.copyWith(color: colorScheme.outline)),
                      ],
                    ),
                  );
                }

                final updates = snapshot.data!;
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: updates.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) => _UpdateCard(update: updates[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  final Map<String, dynamic> update;
  const _UpdateCard({required this.update});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final created = DateTime.tryParse(update['Created'] ?? '');
    final formattedDate = created != null ? '${created.day}/${created.month}/${created.year} a las ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}' : 'Fecha desconocida';
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_circle, size: 20, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      formattedDate,
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 4.0,
                  children: [
                    _buildBadge(context, confidential, colorScheme.tertiaryContainer, colorScheme.onTertiaryContainer),
                    if (isPrinted) _buildBadge(context, 'Impreso', colorScheme.primaryContainer, colorScheme.onPrimaryContainer, icon: Icons.print),
                  ],
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(height: 1),
            ),
            Html(
              data: result,
              style: {
                "body": Style(
                  margin: Margins.zero,
                  padding: HtmlPaddings.zero,
                  fontSize: FontSize(14),
                  fontFamily: 'Poppins',
                  color: colorScheme.onSurface,
                )
              },
            ),
            if (imageIds.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: imageIds.map((id) => _ImagePreview(imageId: id)).toList(),
              )
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(BuildContext context, String label, Color bgColor, Color textColor, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 10, color: textColor), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }
}

class _AddUpdateDialog extends StatefulWidget {
  final int requestId;
  final String summary;
  const _AddUpdateDialog({required this.requestId, required this.summary});

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
            // Resumen de referencia con scroll si es muy largo (Estilo Neutro)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REFERENCIA: RESUMEN DE LA SOLICITUD',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                              letterSpacing: 1.0,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.summary,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              height: 1.4,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
