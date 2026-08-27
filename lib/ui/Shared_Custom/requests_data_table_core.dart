
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_html/flutter_html.dart';

import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart'
    as request_functions;
import 'package:primhub/api/global_cache.dart';
import 'package:primhub/ui/widgets/duration_formatter.dart';
import 'package:primhub/ui/pages/Support/Requests/bulk_edit_request_dialog.dart';
import 'dart:math';
import 'package:primhub/ui/Shared_Custom/responsive_data_table.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';
import 'package:primhub/ui/Shared_Custom/animated_copy_widget.dart';

class RequestsDataTableCore extends StatefulWidget {
  final List<Map<String, dynamic>>
  requests; // Aquí MyRequests pasará 'paginatedAlerts'
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

  String? _sortKey;
  bool _sortAscending = true;
  late List<Map<String, dynamic>> _sortedRequests;

  @override
  void initState() {
    super.initState();
    _sortedRequests = List.from(widget.requests);
  }

  @override
  void didUpdateWidget(covariant RequestsDataTableCore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requests != widget.requests) {
      _sortedRequests = List.from(widget.requests);
      _applySort();
    }
  }

  void _applySort() {
    if (_sortKey == null) return;
    _sortedRequests.sort((a, b) {
      dynamic valA;
      dynamic valB;

      if (_sortKey == 'id') {
        valA = int.tryParse(a['id']?.toString() ?? '0') ?? 0;
        valB = int.tryParse(b['id']?.toString() ?? '0') ?? 0;
      } else if (_sortKey == 'status') {
        valA = request_functions.cleanStatusName(a['status']?.toString() ?? '');
        valB = request_functions.cleanStatusName(b['status']?.toString() ?? '');
      } else if (_sortKey == 'situation') {
        valA = a['situation']?.toString() ?? '';
        valB = b['situation']?.toString() ?? '';
      } else if (_sortKey == 'category') {
        final catA = (a['original'] as Map?)?['R_Category_ID'];
        valA = catA is Map ? (catA['Name'] ?? catA['identifier'] ?? '') : '';
        final catB = (b['original'] as Map?)?['R_Category_ID'];
        valB = catB is Map ? (catB['Name'] ?? catB['identifier'] ?? '') : '';
      } else if (_sortKey == 'subject') {
        valA =
            a['emailSubject']?.toString() ??
            (a['original'] as Map?)?['Summary']?.toString() ??
            '';
        valB =
            b['emailSubject']?.toString() ??
            (b['original'] as Map?)?['Summary']?.toString() ??
            '';
      } else if (_sortKey == 'priority') {
        valA = a['level']?.toString() ?? '';
        valB = b['level']?.toString() ?? '';
      } else if (_sortKey == 'bp') {
        valA = a['bpName']?.toString() ?? '';
        valB = b['bpName']?.toString() ?? '';
      } else if (_sortKey == 'user') {
        valA = a['userName']?.toString() ?? '';
        valB = b['userName']?.toString() ?? '';
      } else if (_sortKey == 'salesRep') {
        valA = a['salesRepName']?.toString() ?? '';
        valB = b['salesRepName']?.toString() ?? '';
      } else if (_sortKey == 'description') {
        valA = a['descriptionClean']?.toString() ?? '';
        valB = b['descriptionClean']?.toString() ?? '';
      } else if (_sortKey == 'qtySpent') {
        valA = (a['qtySpent'] as num?)?.toDouble() ?? 0.0;
        valB = (b['qtySpent'] as num?)?.toDouble() ?? 0.0;
      } else if (_sortKey == 'productChip') {
        valA = a['productChipName']?.toString() ?? '';
        valB = b['productChipName']?.toString() ?? '';
      } else if (_sortKey == 'phase') {
        valA = a['phaseName']?.toString() ?? '';
        valB = b['phaseName']?.toString() ?? '';
      } else if (_sortKey == 'task') {
        valA = a['taskName']?.toString() ?? '';
        valB = b['taskName']?.toString() ?? '';
      } else if (_sortKey == 'created') {
        valA = (a['original'] as Map?)?['Created']?.toString() ?? a['created']?.toString() ?? '';
        valB = (b['original'] as Map?)?['Created']?.toString() ?? b['created']?.toString() ?? '';
      }

      int cmp = 0;
      if (valA is num && valB is num) {
        cmp = valA.compareTo(valB);
      } else {
        cmp = valA.toString().compareTo(valB.toString());
      }
      return _sortAscending ? cmp : -cmp;
    });
  }

  void _onSort(String key) {
    setState(() {
      if (_sortKey == key) {
        _sortAscending = !_sortAscending;
      } else {
        _sortKey = key;
        _sortAscending = true;
      }
      _applySort();
    });
  }

  int _getRealId(Map<String, dynamic> req) =>
      req['realId'] ??
      req['_rawId'] ??
      int.tryParse(req['id']?.toString() ?? '0') ??
      0;

  void _handleRowSelection(bool? selected, int index, int realId) {
    final isShiftPressed =
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.shiftLeft,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.shiftRight,
        );
    setState(() {
      if (isShiftPressed && _lastSelectedIndex != null) {
        int start = min(_lastSelectedIndex!, index);
        int end = max(_lastSelectedIndex!, index);
        for (int i = start; i <= end; i++) {
          final id = _getRealId(_sortedRequests[i]);
          selected == true ? _selectedIds.add(id) : _selectedIds.remove(id);
        }
      } else {
        selected == true
            ? _selectedIds.add(realId)
            : _selectedIds.remove(realId);
        _lastSelectedIndex = index;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bool isLaptop = MediaQuery.of(context).size.width < 1600;

    final fixedCols = [
      ResponsiveDataColumn(
        label: 'Acciones',
        suffixIcon: Tooltip(
          message: 'Haz clic en el título de las columnas con el ícono de flechas para ordenar los datos de forma ascendente o descendente.',
          child: Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Icon(Icons.info_outline, size: 16, color: theme.colorScheme.primary),
          ),
        ),
      ),
      const ResponsiveDataColumn(label: 'Ticket', sortKey: 'id'),
      if (!isLaptop) ...[
        const ResponsiveDataColumn(label: 'Estado', sortKey: 'status'),
        if (AccessControl.isAdmin || AccessControl.isSupport)
          const ResponsiveDataColumn(
            label: 'Tipo de Solicitud',
            sortKey: 'situation',
          ),
      ],
    ];

    List<DataCell> buildFixedCells(Map<String, dynamic> alert) {
      return [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: AccessControl.canAddUpdates
                    ? 'Responder'
                    : 'Ver Actualizaciones',
                icon: Icon(
                  AccessControl.canAddUpdates ? Icons.reply : Icons.forum,
                ),
                onPressed: () => GoRouter.of(context).push(
                  '/request-updates/${Uri.encodeComponent(alert['realId'].toString())}',
                  extra: {'docNo': alert['id']},
                ),
              ),
              IconButton(
                tooltip: 'Ver Adjuntos',
                icon: const Icon(Icons.attach_file),
                onPressed: () => showDialog(
                  context: context,
                  builder: (context) => RequestAttachmentsDialog(
                    requestId: alert['realId'],
                    documentNo: alert['id'],
                  ),
                ),
              ),
              IconButton(
                tooltip: AccessControl.canManageRequests
                    ? 'Editar'
                    : 'Ver Detalles',
                icon: Icon(
                  AccessControl.canManageRequests
                      ? Icons.edit
                      : Icons.visibility,
                ),
                onPressed: () => widget.onEdit(alert),
              ),
            ],
          ),
        ),
        DataCell(
          AnimatedCopyWidget(
            textToCopy: alert['id']?.toString() ?? '',
            snackBarMessage: 'Ticket copiado',
            leadingText: Text(alert['id']?.toString() ?? ''),
          ),
        ),
        if (!isLaptop) ...[
          DataCell(
            Text(
              request_functions.cleanStatusName(
                alert['status']?.toString() ?? 'Sin Estado',
              ),
            ),
          ),
          if (AccessControl.isAdmin || AccessControl.isSupport)
            DataCell(Text(alert['situation']?.toString() ?? 'Sin tipo')),
        ],
      ];
    }

    final scrollableCols = [
      if (isLaptop) ...[
        const ResponsiveDataColumn(label: 'Estado', sortKey: 'status'),
        if (AccessControl.isAdmin || AccessControl.isSupport)
          const ResponsiveDataColumn(
            label: 'Tipo de Solicitud',
            sortKey: 'situation',
          ),
      ],
      const ResponsiveDataColumn(label: 'Categoría', sortKey: 'category'),
      const ResponsiveDataColumn(label: 'Asunto'),
      const ResponsiveDataColumn(label: 'Prioridad', sortKey: 'priority'),
      if (widget.showProjectContext)
        const ResponsiveDataColumn(label: 'Fase', sortKey: 'phase'),
      if (widget.showProjectContext)
        const ResponsiveDataColumn(label: 'Tarea', sortKey: 'task'),
      if (AccessControl.isAdmin)
        const ResponsiveDataColumn(label: 'Tercero', sortKey: 'bp'),
      if (AccessControl.isAdmin)
        const ResponsiveDataColumn(label: 'Usuario', sortKey: 'user'),
      if (AccessControl.isAdmin)
        const ResponsiveDataColumn(
          label: 'Rep. Comercial',
          sortKey: 'salesRep',
        ),
      const ResponsiveDataColumn(label: 'Descripción'),
      const ResponsiveDataColumn(
        label: 'Horas Consumidas',
        sortKey: 'qtySpent',
        numeric: true,
      ),
      if (!widget.showProjectContext)
        const ResponsiveDataColumn(
          label: 'Ficha de Producto',
          sortKey: 'productChip',
        ),
      if (AccessControl.isAdmin)
        const ResponsiveDataColumn(label: 'Creado', sortKey: 'created'),
    ];

    List<DataCell> buildScrollableCells(Map<String, dynamic> alert) {
      final original = alert['original'] as Map<String, dynamic>? ?? {};

      final catData = original['R_Category_ID'];
      String catName = '';
      int? catId;
      if (catData is Map) {
        catId = (catData['id'] as num?)?.toInt();
      } else if (catData is num) {
        catId = catData.toInt();
      }

      if (catId != null) {
        final catInCache = GlobalCache.rawCategories.firstWhere(
          (c) => (c['id'] as num?)?.toInt() == catId,
          orElse: () => <String, dynamic>{},
        );
        if (catInCache.isNotEmpty && catInCache['showinprimhub'] == true) {
          catName =
              catInCache['Name']?.toString() ??
              catInCache['identifier']?.toString() ??
              '';
        }
      }

      final String finalCatName = catName.isNotEmpty
          ? catName
          : 'Sin Categoría';



      final repData = original['SalesRep_ID'];
      final repName = repData is Map
          ? (repData['Name'] ?? repData['identifier'] ?? '')
          : '';

      final chipId =
          alert['productChipId'] ??
          (original['C_BPartner_Product_Chip_ID'] is Map
              ? original['C_BPartner_Product_Chip_ID']['id']
              : original['C_BPartner_Product_Chip_ID']);
      String chipDesc = 'N/A';
      if (chipId != null) {
        final cIdNum = (chipId as num?)?.toInt();
        if (cIdNum != null) {
          final found = GlobalCache.productChips.firstWhere((c) {
            final cId =
                int.tryParse(c['id']?.toString() ?? '') ??
                int.tryParse(c['C_BPartner_Product_Chip_ID']?.toString() ?? '');
            return cId == cIdNum;
          }, orElse: () => <String, dynamic>{});
          if (found.isNotEmpty) {
            chipDesc =
                found['Description']?.toString() ??
                found['Name']?.toString() ??
                'Ficha $cIdNum';
          } else {
            chipDesc = alert['productChipName']?.toString() ?? 'Ficha $cIdNum';
          }
        }
      }

      final createdRaw = original['Created']?.toString() ?? alert['created']?.toString() ?? '';
      String createdFormatted = createdRaw;
      if (createdRaw.isNotEmpty) {
        try {
          final dt = DateTime.parse(createdRaw);
          final day = dt.day.toString().padLeft(2, '0');
          final month = dt.month.toString().padLeft(2, '0');
          final year = dt.year.toString();
          final hour24 = dt.hour;
          final minute = dt.minute.toString().padLeft(2, '0');
          final ampm = hour24 >= 12 ? 'PM' : 'AM';
          final hour12 = hour24 > 12 ? hour24 - 12 : (hour24 == 0 ? 12 : hour24);
          final hourStr = hour12.toString().padLeft(2, '0');
          createdFormatted = '$day/$month/$year $hourStr:$minute $ampm';
        } catch (e) {
          createdFormatted = createdRaw.length >= 19 ? createdRaw.substring(0, 19) : createdRaw;
        }
      }

      return [
        if (isLaptop) ...[
          DataCell(
            Text(
              request_functions.cleanStatusName(
                alert['status']?.toString() ?? 'Sin Estado',
              ),
            ),
          ),
          if (AccessControl.isAdmin || AccessControl.isSupport)
            DataCell(Text(alert['situation']?.toString() ?? 'Sin tipo')),
        ],
        DataCell(Text(finalCatName)),
        DataCell(
          Tooltip(
            message: alert['emailSubject']?.toString() ?? '',
            waitDuration: const Duration(milliseconds: 500),
            showDuration: const Duration(seconds: 2),
            child: Text(
              (alert['emailSubject']?.toString() ?? '').length > 25
                  ? '${(alert['emailSubject']?.toString() ?? '').substring(0, 25)}...'
                  : (alert['emailSubject']?.toString() ?? ''),
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: alert['levelBgColor'] ?? Colors.grey.shade200,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              alert['level']?.toString() ?? 'N/A',
              style: TextStyle(
                color: alert['levelColor'] ?? Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        if (widget.showProjectContext)
          DataCell(Text(alert['phaseName']?.toString() ?? '-')),
        if (widget.showProjectContext)
          DataCell(Text(alert['taskName']?.toString() ?? '-')),
        if (AccessControl.isAdmin)
          DataCell(Text(alert['bpName']?.toString() ?? '')),
        if (AccessControl.isAdmin)
          DataCell(Text(alert['userName']?.toString() ?? '')),
        if (AccessControl.isAdmin)
          DataCell(
            Text(
              repName.toString().isEmpty
                  ? (alert['salesRepName']?.toString() ?? '')
                  : repName.toString(),
            ),
          ),
        DataCell(
          Tooltip(
            message: alert['descriptionClean'] ?? '',
            waitDuration: const Duration(milliseconds: 500),
            child: SizedBox(
              width: 250,
              child: Html(
                data: (alert['description'] ?? alert['descriptionClean'] ?? '')
                    .toString(),
                style: {
                  "body": Style(
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                    fontSize: FontSize(12),
                    maxLines: 2,
                    textOverflow: TextOverflow.ellipsis,
                  ),
                },
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            DurationFormatter.format(
              (alert['qtySpent'] as num?)?.toDouble() ?? 0.0,
            ),
          ),
        ),
        if (!widget.showProjectContext) DataCell(Text(chipDesc)),
        if (AccessControl.isAdmin) DataCell(Text(createdFormatted)),
      ];
    }

    return Column(
      children: [
        if (widget.serverSidePagination && widget.paginationControls != null)
          widget.paginationControls!,
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ResponsiveDataTable<Map<String, dynamic>>(
                items: _sortedRequests,
                sortKey: _sortKey,
                sortAscending: _sortAscending,
                onSort: _onSort,
                getId: (item) => _getRealId(item),
                onRowTap: (item) => widget.onEdit(item),
                showCheckboxColumn: AccessControl.canManageRequests,
                selectedIds: _selectedIds,
                onSelectAll: (selected) {
                  setState(() {
                    selected == true
                        ? _selectedIds.addAll(
                            _sortedRequests.map((r) => _getRealId(r)),
                          )
                        : _selectedIds.clear();
                  });
                },
                onSelectChanged: (id, isSelected) {
                  final index = _sortedRequests.indexWhere(
                    (r) => _getRealId(r) == id,
                  );
                  if (index != -1) _handleRowSelection(isSelected, index, id);
                },
                fixedColumns: fixedCols,
                fixedCellBuilder: buildFixedCells,
                scrollableColumns: scrollableCols,
                scrollableCellBuilder: buildScrollableCells,
                mobileCardBuilder: (item) => _RequestCard(
                  request: item,
                  onEdit: widget.onEdit,
                  onGoToUpdates: () {
                    GoRouter.of(context).push(
                      '/request-updates/${Uri.encodeComponent(_getRealId(item).toString())}',
                      extra: {'docNo': item['id']},
                    );
                  },
                  onShowAttachments: () {
                    showDialog(
                      context: context,
                      builder: (context) => RequestAttachmentsDialog(
                        requestId: _getRealId(item),
                        documentNo: item['id'],
                      ),
                    );
                  },
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
                              onSaved: () =>
                                  setState(() => _selectedIds.clear()),
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

  const _RequestCard({
    required this.request,
    required this.onEdit,
    required this.onGoToUpdates,
    required this.onShowAttachments,
  });

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
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            AnimatedCopyWidget(
                              textToCopy: request['id'].toString(),
                              snackBarMessage: 'Ticket copiado al portapapeles',
                              iconSize: 16,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subject,
                          style: theme.textTheme.bodyLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'updates') onGoToUpdates();
                      if (value == 'attachments') onShowAttachments();
                      if (value == 'edit') onEdit(request);
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'updates',
                            child: ListTile(
                              leading: Icon(
                                AccessControl.canAddUpdates
                                    ? Icons.reply
                                    : Icons.forum,
                              ),
                              title: Text(
                                AccessControl.canAddUpdates
                                    ? 'Responder'
                                    : 'Ver Actualizaciones',
                              ),
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'attachments',
                            child: ListTile(
                              leading: Icon(Icons.attach_file),
                              title: Text('Adjuntos'),
                            ),
                          ),
                          if (AccessControl.canManageRequests)
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: ListTile(
                                leading: Icon(Icons.edit),
                                title: Text('Editar'),
                              ),
                            ),
                        ],
                  ),
                ],
              ),
              if (AccessControl.isAdmin &&
                  (bpName.isNotEmpty || userName.isNotEmpty)) ...[
                const SizedBox(height: 4),
                Text(
                  '$bpName • $userName',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
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
                  Chip(
                    label: Text(status),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                  Chip(
                    label: Text(level),
                    labelStyle: TextStyle(
                      color: levelColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    backgroundColor: levelBgColor,
                    visualDensity: VisualDensity.compact,
                  ),
                  if (time.isNotEmpty)
                    Chip(
                      avatar: Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      label: Text(time),
                      labelStyle: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      backgroundColor: Colors.transparent,
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
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
