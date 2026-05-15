import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/api/access_control.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ImagesManagment/fecthAttachments.dart';
import 'package:primhub/ImagesManagment/postAttachments.dart';
import 'package:primhub/ImagesManagment/downloadAttachments.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/ui/pages/Projects/Projects_Widgets/file_preview_manager.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart' as DocumentsLogic;
import 'package:primhub/api/global_cache.dart';
import 'package:primhub/ui/widgets/duration_formatter.dart';
import 'package:primhub/ui/pages/Support/Requests/bulk_edit_request_dialog.dart';
import 'dart:math';
import 'package:primhub/ui/Shared_Custom/responsive_data_table.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';

class RequestsDataTableCore extends StatefulWidget {
  final List<Map<String, dynamic>> requests; // Aquí MyRequests pasará 'paginatedAlerts'
  final Map<String, int> statusIdMap;
  final Map<String, String> priorityMap;
  final Function(Map<String, dynamic>) onEdit;
  final VoidCallback? onRefresh;
  final bool showProjectContext;
  final bool serverSidePagination;
  final Widget? paginationControls;
  final bool useSimpleStatus;

  const RequestsDataTableCore({
    super.key,
    required this.requests,
    required this.statusIdMap,
    required this.priorityMap,
    required this.onEdit,
    this.onRefresh,
    this.showProjectContext = false,
    this.serverSidePagination = false,
    this.paginationControls,
    this.useSimpleStatus = true,
  });

  @override
  State<RequestsDataTableCore> createState() => _RequestsDataTableCoreState();
}

class _RequestsDataTableCoreState extends State<RequestsDataTableCore> {
  final Set<int> _selectedIds = {};
  int? _lastSelectedIndex;

  int _getRealId(Map<String, dynamic> req) => 
      req['realId'] ?? req['_rawId'] ?? int.tryParse(req['id']?.toString() ?? '0') ?? 0;

  void _handleRowSelection(bool? selected, int index, int realId) {
    final isShiftPressed = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) || 
                           HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight);
    setState(() {
      if (isShiftPressed && _lastSelectedIndex != null) {
        int start = min(_lastSelectedIndex!, index);
        int end = max(_lastSelectedIndex!, index);
        for (int i = start; i <= end; i++) {
          final id = _getRealId(widget.requests[i]);
          selected == true ? _selectedIds.add(id) : _selectedIds.remove(id);
        }
      } else {
        selected == true ? _selectedIds.add(realId) : _selectedIds.remove(realId);
        _lastSelectedIndex = index;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // RESTAURAMOS EL USO DE RESPONSIVE DATA TABLE PARA RECUPERAR EL DISEÑO
    return Column(
      children: [
        if (widget.serverSidePagination && widget.paginationControls != null)
          widget.paginationControls!,
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ResponsiveDataTable<Map<String, dynamic>>(
              items: widget.requests,
              getId: (item) => _getRealId(item),
              onRowTap: (item) => widget.onEdit(item),
              showCheckboxColumn: AccessControl.canManageRequests,
              selectedIds: _selectedIds,
              onSelectAll: (selected) {
                setState(() {
                  selected == true 
                      ? _selectedIds.addAll(widget.requests.map((r) => _getRealId(r))) 
                      : _selectedIds.clear();
                });
              },
              onSelectChanged: (id, isSelected) {
                final index = widget.requests.indexWhere((r) => _getRealId(r) == id);
                if (index != -1) _handleRowSelection(isSelected, index, id);
              },
              fixedColumns: const [
                ResponsiveDataColumn(label: 'Acciones'),
                ResponsiveDataColumn(label: 'Ticket'),
                ResponsiveDataColumn(label: 'Estado'),
                ResponsiveDataColumn(label: 'Tipo de Solicitud'),
              ],
              fixedCellBuilder: (alert) => [
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(AccessControl.canAddUpdates ? Icons.reply : Icons.forum),
                        onPressed: () => GoRouter.of(context).push('/request-updates/${Uri.encodeComponent(alert['realId'].toString())}', extra: {'docNo': alert['id']}),
                      ),
                      IconButton(
                        icon: const Icon(Icons.attach_file),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (context) => RequestAttachmentsDialog(requestId: alert['realId'], documentNo: alert['id']),
                        ),
                      ),
                      IconButton(
                        icon: Icon(AccessControl.canManageRequests ? Icons.edit : Icons.visibility),
                        onPressed: () => widget.onEdit(alert),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: alert['id']?.toString() ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ticket copiado'), duration: Duration(seconds: 1))
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(alert['id']?.toString() ?? ''),
                        const SizedBox(width: 4),
                        const Icon(Icons.copy, size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                DataCell(Text(DocumentsLogic.cleanStatusName(alert['status']?.toString() ?? 'Sin Estado'))),
                DataCell(Text(alert['situation']?.toString() ?? 'Sin tipo')),
              ],
              scrollableColumns: [
                const ResponsiveDataColumn(label: 'Asunto'),
                const ResponsiveDataColumn(label: 'Categoría'),
                const ResponsiveDataColumn(label: 'Prioridad'),
                if (widget.showProjectContext) const ResponsiveDataColumn(label: 'Fase'),
                if (widget.showProjectContext) const ResponsiveDataColumn(label: 'Tarea'),
                if (AccessControl.isAdmin) const ResponsiveDataColumn(label: 'Tercero'),
                if (AccessControl.isAdmin) const ResponsiveDataColumn(label: 'Usuario'),
                if (AccessControl.isAdmin) const ResponsiveDataColumn(label: 'Rep. Comercial'),
                const ResponsiveDataColumn(label: 'Descripción'),
                const ResponsiveDataColumn(label: 'Horas Consumidas'),
                if (!widget.showProjectContext) const ResponsiveDataColumn(label: 'Ficha de Producto'),
              ],
              scrollableCellBuilder: (alert) => [
                DataCell(
                  Tooltip(
                    message: alert['emailSubject']?.toString() ?? '',
                    waitDuration: const Duration(milliseconds: 500),
                    showDuration: const Duration(seconds: 2),
                    child: Text((alert['emailSubject']?.toString() ?? '').length > 25 ? '${(alert['emailSubject']?.toString() ?? '').substring(0, 25)}...' : (alert['emailSubject']?.toString() ?? '')),
                  ),
                ),
                DataCell(Text(alert['category']?.toString() ?? 'Sin categoría')),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: alert['levelBgColor'] ?? Colors.grey.shade200, borderRadius: BorderRadius.circular(30)),
                    child: Text(alert['level']?.toString() ?? 'N/A', style: TextStyle(color: alert['levelColor'] ?? Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
                if (widget.showProjectContext) DataCell(Text(alert['phaseName']?.toString() ?? '-')),
                if (widget.showProjectContext) DataCell(Text(alert['taskName']?.toString() ?? '-')),
                if (AccessControl.isAdmin) DataCell(Text(alert['bpName']?.toString() ?? '')),
                if (AccessControl.isAdmin) DataCell(Text(alert['userName']?.toString() ?? '')),
                if (AccessControl.isAdmin) DataCell(Text(alert['salesRepName']?.toString() ?? '')),
                DataCell(
                  Tooltip(
                    message: alert['descriptionClean'] ?? '',
                    waitDuration: const Duration(milliseconds: 500),
                    child: Text(
                      (alert['descriptionClean'] ?? '').length > 50 
                        ? '${(alert['descriptionClean'] ?? '').substring(0, 50)}...' 
                        : (alert['descriptionClean'] ?? '')
                    ),
                  ),
                ),
                DataCell(Text(DurationFormatter.format((alert['qtySpent'] as num?)?.toDouble() ?? 0.0))),
                if (!widget.showProjectContext) DataCell(Text(alert['productChipName'] ?? 'N/A')),
              ],
              mobileCardBuilder: (item) => _RequestCard(
                request: item,
                onEdit: widget.onEdit,
                onGoToUpdates: () {},
                onShowAttachments: () {},
              ),
            ),

            // BARRA DE EDICIÓN MASIVA (Flotante)
            if (_selectedIds.isNotEmpty && AccessControl.canManageRequests)
              Positioned(
                bottom: widget.serverSidePagination ? 60 : 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${_selectedIds.length} seleccionadas',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (context) => BulkEditRequestDialog(
                            selectedIds: _selectedIds,
                            onSaved: () => setState(() => _selectedIds.clear()),
                          ),
                        ),
                        icon: const Icon(Icons.edit),
                        label: const Text('Edición Masiva'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
  }
}

// Fin del archivo

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