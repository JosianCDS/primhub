import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
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
    final theme = Theme.of(context);

    // --- 1. Definir las columnas fijas y desplazables ---
    final fixedColumns = <DataColumn>[
      if (AccessControl.canManageRequests)
        DataColumn(
          label: Checkbox(value: (widget.requests.isNotEmpty && _selectedIds.length == widget.requests.length) ? true : (_selectedIds.isNotEmpty ? null : false), tristate: true, onChanged: (val) => _handleSelectAll(val == true)),
        ),
      const DataColumn(label: Text('#')),
      const DataColumn(label: Text('Acciones')),
      const DataColumn(label: Text('Ticket')),
      const DataColumn(label: Text('Tipo de Solicitud')),
      const DataColumn(label: Text('Asunto')),
    ];

    final scrollableColumns = <DataColumn>[
      const DataColumn(label: Text('Categoría')),
      const DataColumn(label: Text('Nivel')),
      if (AccessControl.isAdmin) const DataColumn(label: Text('Tercero')),
      if (AccessControl.isAdmin) const DataColumn(label: Text('Usuario')),
      if (AccessControl.isAdmin) const DataColumn(label: Text('Rep. Comercial')),
      const DataColumn(label: Text('Descripción')),
      const DataColumn(label: Text('Estado')),
      const DataColumn(label: Text('Horas')),
      const DataColumn(label: Text('Ultima Actualización')),
    ];

    // --- 2. Generar las celdas para cada fila ---
    final List<Map<String, List<DataCell>>> allCells = widget.requests.asMap().entries.map((entry) {
      final int index = entry.key;
      final Map<String, dynamic> alert = entry.value;
      final double h = double.tryParse(alert['qtyPlan']?.toString() ?? '0.0') ?? 0.0;
      final String hoursStr = DurationFormatter.format(h);
      final int realId = _getRealId(alert);

      final fixedCells = <DataCell>[
        if (AccessControl.canManageRequests) DataCell(Checkbox(value: _selectedIds.contains(realId), onChanged: (selected) => _handleRowSelection(selected, index, realId))),
        DataCell(Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(AccessControl.canAddUpdates ? Icons.reply : Icons.forum),
                tooltip: AccessControl.canAddUpdates ? 'Responder Solicitud' : 'Ver Actualizaciones',
                onPressed: () => GoRouter.of(context).push('/request-updates/${Uri.encodeComponent(alert['realId'].toString())}', extra: {'docNo': alert['id']}),
              ),
              IconButton(
                icon: const Icon(Icons.attach_file),
                tooltip: 'Ver / Añadir Adjuntos',
                onPressed: () => showDialog(
                  context: context,
                  builder: (context) => _RequestAttachmentsDialog(requestId: alert['realId'], documentNo: alert['id']),
                ),
              ),
              if (AccessControl.canManageRequests) IconButton(icon: const Icon(Icons.edit), tooltip: 'Editar', onPressed: () => widget.onEdit(alert)) else IconButton(icon: const Icon(Icons.visibility), tooltip: 'Ver Detalles', onPressed: () => widget.onEdit(alert)),
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
                onTap: () => Clipboard.setData(ClipboardData(text: alert['id'].toString())).then((_) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código copiado al portapapeles')))),
                child: const Padding(padding: EdgeInsets.all(4.0), child: Icon(Icons.copy, size: 16)),
              ),
            ],
          ),
          onTap: () => widget.onEdit(alert),
        ),
        DataCell(Text(alert['situation']), onTap: () => widget.onEdit(alert)),
        DataCell(
          Tooltip(
            message: (alert['emailSubject'] != null && alert['emailSubject'].toString().trim().isNotEmpty) ? alert['emailSubject'].toString() : 'Sin asunto',
            preferBelow: false,
            child: SizedBox(width: 200, child: Text((alert['emailSubject']?.toString() ?? '').length > 25 ? '${(alert['emailSubject']?.toString() ?? '').substring(0, 25)}...' : (alert['emailSubject']?.toString() ?? ''))),
          ),
          onTap: () => widget.onEdit(alert),
        ),
      ];

      final scrollableCells = <DataCell>[
        DataCell(Text(alert['category']?.toString() ?? 'Sin categoría'), onTap: () => widget.onEdit(alert)),
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
        if (AccessControl.isAdmin) DataCell(Text(alert['bpName']?.toString() ?? ''), onTap: () => widget.onEdit(alert)),
        if (AccessControl.isAdmin) DataCell(Text(alert['userName']?.toString() ?? ''), onTap: () => widget.onEdit(alert)),
        if (AccessControl.isAdmin) DataCell(Text(alert['salesRepName']?.toString() ?? ''), onTap: () => widget.onEdit(alert)),
        DataCell(
          Tooltip(
            message: (alert['descriptionClean'] != null && alert['descriptionClean'].toString().trim().isNotEmpty) ? alert['descriptionClean'].toString() : 'Sin descripción',
            preferBelow: false,
            child: SizedBox(width: 300, child: Text((alert['descriptionClean']?.toString() ?? '').length > 70 ? '${(alert['descriptionClean']?.toString() ?? '').substring(0, 70)}...' : (alert['descriptionClean']?.toString() ?? ''))),
          ),
        ),
        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 8), Text(alert['status'])])),
        DataCell(Text(hoursStr)),
        DataCell(Text(alert['time'] ?? '')),
      ];

      return {'fixed': fixedCells, 'scrollable': scrollableCells};
    }).toList();

    // --- 3. Construir las DataRows para cada tabla ---
    final fixedRows = widget.requests.asMap().entries.map((entry) {
      final int realId = _getRealId(entry.value);
      return DataRow(selected: _selectedIds.contains(realId), onSelectChanged: (_) => widget.onEdit(entry.value), cells: allCells[entry.key]['fixed']!);
    }).toList();

    final scrollableRows = widget.requests.asMap().entries.map((entry) {
      final int realId = _getRealId(entry.value);
      return DataRow(selected: _selectedIds.contains(realId), onSelectChanged: (_) => widget.onEdit(entry.value), cells: allCells[entry.key]['scrollable']!);
    }).toList();

    // --- 4. Definir un tema consistente para ambas tablas ---
    const double rowHeight = 52.0;
    final baseDataTableTheme = DataTableTheme.of(context).copyWith(
      dataRowMinHeight: rowHeight,
      dataRowMaxHeight: rowHeight,
      headingRowHeight: rowHeight,
      headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
    );

    final scrollableDataTableTheme = baseDataTableTheme.copyWith(
      headingRowColor: MaterialStateProperty.all(theme.colorScheme.surfaceContainerHighest.withOpacity(0.3)),
      dataRowColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
        if (states.contains(MaterialState.hovered)) return theme.colorScheme.primary.withOpacity(0.08);
        return null;
      }),
    );

    final fixedDataTableTheme = baseDataTableTheme.copyWith(
      headingRowColor: MaterialStateProperty.all(theme.colorScheme.surfaceContainerHighest), // Encabezado fijo más oscuro
      dataRowColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
        if (states.contains(MaterialState.hovered)) return theme.colorScheme.primary.withOpacity(0.12);
        // Tono de fondo permanente para distinguir la sección fija
        return theme.colorScheme.surfaceContainerHigh; // Filas fijas más oscuras
      }),
    );

    // --- 5. Vista móvil ---
    Widget mobileView = ListView.builder(
      shrinkWrap: true, // Evita que el ListView intente ocupar un espacio infinito.
      physics: const NeverScrollableScrollPhysics(), // Deshabilita el scroll del ListView, el padre (SingleChildScrollView) se encargará.
      itemCount: widget.requests.length,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemBuilder: (context, index) {
        final request = widget.requests[index];
        return _RequestCard(
          request: request,
          onEdit: widget.onEdit,
          onGoToUpdates: () => GoRouter.of(context).push('/request-updates/${Uri.encodeComponent(request['realId'].toString())}', extra: {'docNo': request['id']}),
          onShowAttachments: () => showDialog(
            context: context,
            builder: (context) => _RequestAttachmentsDialog(requestId: request['realId'], documentNo: request['id']),
          ),
        );
      },
    );

    // --- 6. Vista de escritorio ---
    Widget desktopView = Card(
      elevation: 4,
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Parte Fija ---
                    DataTableTheme(
                      data: fixedDataTableTheme,
                      child: DataTable(
                        showCheckboxColumn: false, // La manejamos manualmente
                        columns: fixedColumns,
                        rows: fixedRows,
                      ),
                    ),
                    // --- Parte con Scroll ---
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTableTheme(
                          data: scrollableDataTableTheme,
                          child: DataTable(showCheckboxColumn: false, columns: scrollableColumns, rows: scrollableRows),
                        ),
                      ),
                    ),
                  ],
                ),
                // Espaciador animado para permitir scroll debajo del Toast flotante
                AnimatedContainer(duration: const Duration(milliseconds: 250), height: _selectedIds.isNotEmpty && AccessControl.canManageRequests ? 80.0 : 0.0),
              ],
            ),
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
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Usar 800 como punto de quiebre para cambiar a la vista de tarjetas
        return constraints.maxWidth < 800 ? mobileView : desktopView;
      },
    );
  }
}

class _RequestAttachmentsDialog extends StatefulWidget {
  // ignore: unused_element
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
    if (!AccessControl.isAdmin && !AccessControl.isSupport) {
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
        if (AccessControl.isAdmin || AccessControl.isSupport) CustomButton(text: 'Subir Archivo', icon: Icons.upload_file, isLoading: _isUploading, onPressed: _uploadAttachment),
      ],
    );
  }
}

/// Tarjeta individual para la vista móvil de solicitudes.
class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final Function(Map<String, dynamic>) onEdit;
  final VoidCallback onGoToUpdates;
  final VoidCallback onShowAttachments;

  const _RequestCard({required this.request, required this.onEdit, required this.onGoToUpdates, required this.onShowAttachments});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final String subject = request['emailSubject']?.toString() ?? 'Sin asunto';
    final String bpName = request['bpName']?.toString() ?? '';
    final String userName = request['userName']?.toString() ?? '';
    final String time = request['time'] ?? '';
    final String status = request['status'] ?? 'N/A';
    final String level = request['level'] ?? 'N/A';
    final Color levelBgColor = request['levelBgColor'] ?? Colors.transparent;
    final Color levelColor = request['levelColor'] ?? colorScheme.onSurface;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => onEdit(request),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Ticket #${request['id']}',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: request['id'].toString()));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket copiado al portapapeles')));
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: const Padding(padding: EdgeInsets.all(4.0), child: Icon(Icons.copy, size: 16)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(subject, style: theme.textTheme.bodyLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'updates') onGoToUpdates();
                      if (value == 'attachments') onShowAttachments();
                      if (value == 'edit') onEdit(request);
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'updates',
                        child: ListTile(leading: Icon(AccessControl.canAddUpdates ? Icons.reply : Icons.forum), title: Text(AccessControl.canAddUpdates ? 'Responder' : 'Ver Actualizaciones')),
                      ),
                      const PopupMenuItem<String>(
                        value: 'attachments',
                        child: ListTile(leading: Icon(Icons.attach_file), title: Text('Adjuntos')),
                      ),
                      if (AccessControl.canManageRequests)
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: ListTile(leading: Icon(Icons.edit), title: Text('Editar')),
                        ),
                    ],
                  ),
                ],
              ),
              if (AccessControl.isAdmin && (bpName.isNotEmpty || userName.isNotEmpty)) ...[
                const SizedBox(height: 4),
                Text(
                  '$bpName • $userName',
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const Divider(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(label: Text(status), visualDensity: VisualDensity.compact, backgroundColor: colorScheme.surfaceContainerHighest),
                  Chip(
                    label: Text(level),
                    labelStyle: TextStyle(color: levelColor, fontWeight: FontWeight.bold, fontSize: 12),
                    backgroundColor: levelBgColor,
                    visualDensity: VisualDensity.compact,
                  ),
                  if (time.isNotEmpty)
                    Chip(
                      avatar: Icon(Icons.calendar_today, size: 14, color: colorScheme.onSurfaceVariant),
                      label: Text(time),
                      labelStyle: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      backgroundColor: Colors.transparent,
                      shape: StadiumBorder(side: BorderSide(color: colorScheme.outline.withOpacity(0.2))),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
