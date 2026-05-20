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
import 'package:primhub/api/global_cache.dart';
import 'package:primhub/ImagesManagment/fecthAttachments.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/ui/Shared_Custom/help_icon.dart';

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
  String? _memoizedDescription;
  bool _isLoadingDetails = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
    _refreshUpdates();
  }

  Future<void> _fetchDetails({bool forceNetwork = false}) async {
    try {
// [Mantenimiento] Log removido:       debugPrint("DEBUG: [INIT] Fetching details. ID: ${widget.requestId}, DocNo: ${widget.docNo}, Force: $forceNetwork");

      // 1. INTENTO EN CACHÉ (Instantáneo si no se fuerza red)
      if (!forceNetwork) {
        var cached = GlobalCache.requests.where((r) => r['id']?.toString() == widget.requestId.toString()).toList();

        // Buscar también en la caché de proyectos
        if (cached.isEmpty) {
          for (var projList in GlobalCache.projectRequestsCache.values) {
            final foundInProj = projList.where((r) => r['id']?.toString() == widget.requestId.toString()).toList();
            if (foundInProj.isNotEmpty) {
              cached = foundInProj;
              break;
            }
          }
        }

        if (cached.isNotEmpty) {
// [Mantenimiento] Log removido:           debugPrint("DEBUG: [CACHE] Found request in GlobalCache.");
          _handleFoundRequest(cached.first);
          return;
        }
      }

      // 2. INTENTO API POR ID (Búsqueda principal y más precisa)
// [Mantenimiento] Log removido:       debugPrint("DEBUG: [STAGE 1] Searching by ID: ${widget.requestId}");
      final reqsId = await fetchRequest(
        filter: "id eq ${widget.requestId} or R_Request_ID eq ${widget.requestId}",
        select: "id,DocumentNo,Summary,Description,Help,Result,CDS_EmailSubject,Created,Priority,R_Status_ID,R_Category_ID,R_RequestType_ID,C_BPartner_ID,AD_User_ID,SalesRep_ID,QtySpent,ConfidentialTypeEntry",
      );

      if (reqsId.isNotEmpty) {
// [Mantenimiento] Log removido:         debugPrint("DEBUG: [STAGE 1 SUCCESS] Found via internal ID.");
        _handleFoundRequest(reqsId.first);
        return;
      }

      // 3. INTENTO API POR DOCUMENT NO (Respaldo si el ID no funcionó)
      if (widget.docNo.isNotEmpty && widget.docNo != widget.requestId.toString()) {
// [Mantenimiento] Log removido:         debugPrint("DEBUG: [STAGE 2] ID search failed. Searching by DocumentNo: ${widget.docNo}");
        final reqsDoc = await fetchRequest(
          filter: "DocumentNo eq '${widget.docNo}'",
          select: "id,DocumentNo,Summary,Description,Help,Result,CDS_EmailSubject,Created,Priority,R_Status_ID,R_Category_ID,R_RequestType_ID,C_BPartner_ID,AD_User_ID,SalesRep_ID,QtySpent,ConfidentialTypeEntry",
        );
        if (reqsDoc.isNotEmpty) {
// [Mantenimiento] Log removido:           debugPrint("DEBUG: [STAGE 2 SUCCESS] Found via DocumentNo.");
          _handleFoundRequest(reqsDoc.first);
          return;
        }
      }

// [Mantenimiento] Log removido:       debugPrint("DEBUG: [FAILED] No request found after all stages for identifier: ${widget.requestId} / ${widget.docNo}");
      if (mounted) setState(() => _isLoadingDetails = false);

    } catch (e) {
// [Mantenimiento] Log removido:       debugPrint("DEBUG: [ERROR] Exception in _fetchDetails: $e");
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  void _handleFoundRequest(Map<String, dynamic> details) {
    if (!mounted) return;
    
    final realId = details['id'] is int ? details['id'] : int.tryParse(details['id']?.toString() ?? '');
    final docNo = details['DocumentNo']?.toString();

// [Mantenimiento] Log removido:     debugPrint("DEBUG: [RESOLVED] ID: $realId, DocNo: $docNo");

    if (realId != null && realId != widget.requestId) {
// [Mantenimiento] Log removido:       debugPrint("DEBUG: [SYNC] Refreshing updates with REAL ID: $realId");
      _refreshUpdates(realId);
    }

    setState(() {
      _requestDetails = details;
      _isLoadingDetails = false;
      // Pre-calcular descripción para evitar lag en renderizado
      final fields = ['Description', 'description', 'Help', 'help', 'Result', 'result'];
      _memoizedDescription = 'Sin descripción adicional.';
      for (var f in fields) {
        final val = details[f]?.toString();
        if (val != null && val.trim().isNotEmpty && val != 'null') {
          _memoizedDescription = val;
          break;
        }
      }
    });
  }

  void _refreshUpdates([int? id]) {
    final targetId = id ?? widget.requestId;
    setState(() {
      _updatesFuture = fetchRequestUpdates(targetId).then((list) {
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
        requestId: _requestDetails?['id'] ?? widget.requestId,
        currentStatusId: _requestDetails?['R_Status_ID'] is Map 
            ? (_requestDetails!['R_Status_ID']['id'] as num?)?.toInt() 
            : (_requestDetails?['R_Status_ID'] as num?)?.toInt(),
        summary: (_requestDetails?['Summary'] ?? _requestDetails?['summary'] ?? widget.docNo).toString(),
        description: _memoizedDescription ?? 'Cargando...',
      ),
    );

    if (result == true) {
      _fetchDetails(forceNetwork: true); // Recargar detalles forzando red para ver el nuevo estado
      _refreshUpdates();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Actualizaciones: ${widget.docNo}'),
        actions: const [HelpIcon()],
      ),
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
            _RequestSummaryHeader(
              details: _requestDetails!,
              docNo: widget.docNo,
              description: _memoizedDescription ?? 'Sin descripción.',
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
            // Mostramos tanto imágenes en campos fijos como archivos adjuntos
            if (imageIds.isNotEmpty || update['id'] != null) ...[
              const SizedBox(height: 16),
              AttachmentPreviewList(
                recordId: update['id'] is int ? update['id'] : int.tryParse(update['id']?.toString() ?? '') ?? 0,
                tableName: '${Endpoint.baseUrl}/api/v1/models/R_RequestUpdate',
                fixedImageIds: imageIds,
              ),
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
  final String description;
  final int? currentStatusId;
  const _AddUpdateDialog({required this.requestId, required this.summary, required this.description, this.currentStatusId});

  @override
  State<_AddUpdateDialog> createState() => _AddUpdateDialogState();
}

class _AddUpdateDialogState extends State<_AddUpdateDialog> {
  final _resultController = TextEditingController();
  String _confidentialType = 'I'; // Internal
  List<PlatformFile?> _evidences = [null, null, null, null];
  bool _isSaving = false;
  int? _newStatusId;

  @override
  void initState() {
    super.initState();
    if (widget.currentStatusId != null && SUPPORT_STATUS_MAPPING.containsKey(widget.currentStatusId)) {
      _newStatusId = widget.currentStatusId;
    } else {
      _newStatusId = null;
    }
  }

  Future<void> _pickFile(int index) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);

    if (result != null && result.files.isNotEmpty) {
      if (result.files.first.bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al leer el archivo.'), backgroundColor: Colors.orange));
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

    final result = await createRequestUpdate(requestId: widget.requestId, resultText: _resultController.text, confidentialType: _confidentialType, evidences: _evidences);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Error desconocido'), backgroundColor: result['success'] == true ? Colors.green : Colors.red));
      if (result['success'] == true) {
        if (_newStatusId != null && _newStatusId != widget.currentStatusId) {
          final statusResult = await updateRemoteRequest(id: widget.requestId, statusId: _newStatusId!);
          if (statusResult['success'] == true) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Estado actualizado correctamente'), backgroundColor: Colors.green));
            }
          }
        }
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
          if (file == null) IconButton(icon: const Icon(Icons.attach_file), onPressed: () => _pickFile(index), tooltip: 'Adjuntar Archivo', color: theme.colorScheme.primary) else IconButton(icon: const Icon(Icons.delete), onPressed: () => _removeFile(index), tooltip: 'Eliminar Archivo', color: theme.colorScheme.error),
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
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
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
                        widget.summary.toUpperCase(),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                              letterSpacing: 0.5,
                            ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4.0),
                        child: Divider(height: 12),
                      ),
                      Html(
                        data: widget.description,
                        style: {
                          "body": Style(
                            margin: Margins.zero,
                            padding: HtmlPaddings.zero,
                            fontSize: FontSize(12),
                            color: Theme.of(context).colorScheme.onSurface,
                            height: Height(1.4),
                          )
                        },
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
                  child: CustomDropdown<int>(
                    label: 'Estado',
                    value: _newStatusId,
                    items: SUPPORT_STATUS_MAPPING.entries.map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(cleanStatusName(e.value)),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _newStatusId = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Evidencias (Opcional, hasta 4 archivos):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

class AttachmentPreviewList extends StatelessWidget {
  final int recordId;
  final String tableName;
  final List<int> fixedImageIds;

  const AttachmentPreviewList({
    super.key,
    required this.recordId,
    required this.tableName,
    required this.fixedImageIds,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: fetchAttachments(recordID: recordId, tableName: tableName),
      builder: (context, snapshot) {
        final List<Widget> previews = [];

        // 1. Imágenes de campos fijos (Legacy/Compatibilidad)
        for (var id in fixedImageIds) {
          previews.add(_ImagePreview(imageId: id));
        }

        // 2. Archivos adjuntos reales
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          for (var attr in snapshot.data!) {
            final fileName = attr['name']?.toString() ?? 'archivo';
            previews.add(_AttachmentItem(
              tableName: tableName,
              recordId: recordId,
              fileName: fileName,
            ));
          }
        }

        if (previews.isEmpty && (snapshot.connectionState == ConnectionState.done)) {
          return const SizedBox.shrink();
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: previews,
        );
      },
    );
  }
}

class _AttachmentItem extends StatelessWidget {
  final String tableName;
  final int recordId;
  final String fileName;

  const _AttachmentItem({
    required this.tableName,
    required this.recordId,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    final extension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);

    if (isImage) {
      return FutureBuilder<Uint8List?>(
        future: DocumentsLogic.fetchImagePreview(tableName, recordId, fileName),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildBox(const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
          }
          if (snapshot.hasData && snapshot.data != null) {
            return InkWell(
              onTap: () => _showFullScreen(context, snapshot.data!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(snapshot.data!, width: 80, height: 80, fit: BoxFit.cover),
              ),
            );
          }
          return _buildBox(const Icon(Icons.broken_image_outlined, color: Colors.grey));
        },
      );
    }

    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Abriendo $fileName...')));
      },
      child: _buildBox(
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(DocumentsLogic.getFileIcon(extension), size: 32, color: Colors.indigo),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                fileName,
                style: const TextStyle(fontSize: 8),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBox(Widget child) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(child: child),
    );
  }

  void _showFullScreen(BuildContext context, Uint8List data) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(child: Image.memory(data)),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, shadows: [Shadow(blurRadius: 4)]),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
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

class _RequestSummaryHeader extends StatelessWidget {
  final Map<String, dynamic> details;
  final String docNo;
  final String description;

  const _RequestSummaryHeader({
    required this.details,
    required this.docNo,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RESUMEN DE LA SOLICITUD',
            style: textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary.withOpacity(0.8),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.25,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (details['Summary'] ?? details['summary'] ?? 'Sin resumen').toString(),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Html(
                    data: description,
                    style: {
                      "body": Style(
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                        fontSize: FontSize(14),
                        color: colorScheme.onSurfaceVariant,
                        height: Height(1.5),
                      )
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

