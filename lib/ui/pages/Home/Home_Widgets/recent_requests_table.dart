import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:go_router/go_router.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/Shared_Custom/custom_container.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/Shared_Custom/custom_skeleton.dart';
import 'package:primhub/ui/Shared_Custom/responsive_data_table.dart';
import 'package:primhub/api/global_cache.dart';
import 'package:primhub/ui/widgets/duration_formatter.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart' as DocumentsLogic;

class RecentRequestsTable extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final bool isLoading;
  final Function(Map<String, dynamic>) onEdit;

  const RecentRequestsTable({super.key, required this.requests, required this.isLoading, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return CustomContainer(
      title: 'Solicitudes Recientes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 1000),
            child: isLoading
                ? const SkeletonTable() // Muestra el esqueleto mientras carga
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // Punto de quiebre para cambiar a vista de tarjetas
                      if (constraints.maxWidth < 800) {
                        return _MobileRequestList(requests: requests, onEdit: onEdit);
                      } else {
                        return _DesktopRequestTable(requests: requests, onEdit: onEdit);
                      }
                    },
                  ),
          ),
          const SizedBox(height: 20),
          Center(
            child: CustomButton(text: 'Ver todas las solicitudes', onPressed: () => context.push('/my-requests')),
          ),
        ],
      ),
    );
  }
}

/// Vista de tabla para Escritorio
class _DesktopRequestTable extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final Function(Map<String, dynamic>) onEdit;

  const _DesktopRequestTable({required this.requests, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final List<ResponsiveDataColumn> fixedColumns = [
      const ResponsiveDataColumn(label: 'Acciones'),
      const ResponsiveDataColumn(label: 'Ticket'),
      const ResponsiveDataColumn(label: 'Estado'),
      if (AccessControl.isAdmin || AccessControl.isSupport) const ResponsiveDataColumn(label: 'Tipo de Solicitud'),
    ];

    final List<ResponsiveDataColumn> scrollableColumns = [
      const ResponsiveDataColumn(label: 'Categoría'),
      const ResponsiveDataColumn(label: 'Asunto'),
      const ResponsiveDataColumn(label: 'Prioridad'),
      const ResponsiveDataColumn(label: 'Tercero'),
      const ResponsiveDataColumn(label: 'Usuario'),
      if (AccessControl.isAdmin || AccessControl.isSupport) const ResponsiveDataColumn(label: 'Rep. Comercial'),
      const ResponsiveDataColumn(label: 'Descripción'),
      const ResponsiveDataColumn(label: 'Horas'),
      const ResponsiveDataColumn(label: 'Ficha de Producto'),
    ];

    return ResponsiveDataTable<Map<String, dynamic>>(
      items: requests,
      fixedColumns: fixedColumns,
      scrollableColumns: scrollableColumns,
      getId: (item) => item['original']['id'],
      onRowTap: onEdit,
      fixedCellBuilder: (alert) => [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Ir a Mis Solicitudes',
                icon: const Icon(Icons.arrow_forward),
                onPressed: () => context.push('/my-requests', extra: {'search': alert['code']}),
              ),
              IconButton(
                icon: Icon(AccessControl.canAddUpdates ? Icons.reply : Icons.forum),
                onPressed: () => GoRouter.of(context).push('/request-updates/${Uri.encodeComponent((alert['realId'] ?? alert['original']['id']).toString())}', extra: {'docNo': alert['code']}),
              ),
              IconButton(
                icon: const Icon(Icons.attach_file),
                onPressed: () => showDialog(
                  context: context,
                  builder: (context) => DocumentsLogic.RequestAttachmentsDialog(requestId: alert['realId'] ?? alert['original']['id'], documentNo: alert['code'] ?? ''),
                ),
              ),
              IconButton(
                icon: Icon(AccessControl.canManageRequests ? Icons.edit : Icons.visibility),
                onPressed: () => onEdit(alert),
              ),
            ],
          ),
        ),
        DataCell(
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: alert['code']?.toString() ?? ''));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ticket copiado'), duration: Duration(seconds: 1))
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(alert['code']?.toString() ?? ''),
                const SizedBox(width: 4),
                const Icon(Icons.copy, size: 14, color: Colors.grey),
              ],
            ),
          ),
        ),
        DataCell(Text(DocumentsLogic.cleanStatusName(alert['status']?.toString() ?? 'Sin Estado'))),
        if (AccessControl.isAdmin || AccessControl.isSupport) DataCell(Text(alert['situation']?.toString() ?? 'Sin tipo')),
      ],
      scrollableCellBuilder: (alert) {
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
            catName = catInCache['Name']?.toString() ?? catInCache['identifier']?.toString() ?? '';
          }
        }
        
        final String finalCatName = catName.isNotEmpty ? catName : 'Sin Categoría';
        final asunto = alert['emailSubject']?.toString() ?? original['Summary']?.toString() ?? '';

        final repData = original['SalesRep_ID'];
        final repName = repData is Map ? (repData['Name'] ?? repData['identifier'] ?? '') : '';

        final chipId = alert['productChipId'];
        String chipDesc = 'N/A';
        if (chipId != null) {
          final found = GlobalCache.productChips.firstWhere(
            (c) {
              final cId = int.tryParse(c['id']?.toString() ?? '') ?? int.tryParse(c['C_BPartner_Product_Chip_ID']?.toString() ?? '');
              return cId == chipId;
            },
            orElse: () => <String, dynamic>{},
          );
          if (found.isNotEmpty) {
            chipDesc = found['Description']?.toString() ?? found['Name']?.toString() ?? 'Ficha $chipId';
          }
        }

        return [
          DataCell(Text(catName.toString())),
          DataCell(Text(asunto.toString())),
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
          DataCell(Text(alert['bpName']?.toString() ?? '')),
          DataCell(Text(alert['userName']?.toString() ?? '')),
          if (AccessControl.isAdmin || AccessControl.isSupport) DataCell(Text(repName.toString())),
          DataCell(Text(DocumentsLogic.stripHtmlTags(alert['descriptionClean'] ?? alert['description'] ?? '').length > 50 ? '${DocumentsLogic.stripHtmlTags(alert['descriptionClean'] ?? alert['description'] ?? '').substring(0, 50)}...' : DocumentsLogic.stripHtmlTags(alert['descriptionClean'] ?? alert['description'] ?? ''))),
          DataCell(Text(DurationFormatter.format((alert['qtySpent'] as num?)?.toDouble() ?? 0.0))),
          DataCell(Text(chipDesc)),
        ];
      },
      mobileCardBuilder: (req) => _RecentRequestCard(request: req, onEdit: onEdit),
    );
  }
}

/// Vista de lista de tarjetas para Móvil
class _MobileRequestList extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final Function(Map<String, dynamic>) onEdit;

  const _MobileRequestList({required this.requests, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32.0),
        child: Center(
          child: Text('No hay solicitudes recientes.', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        return _RecentRequestCard(request: req, onEdit: onEdit);
      },
    );
  }
}

/// Tarjeta individual para la vista móvil de solicitudes recientes.
class _RecentRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final Function(Map<String, dynamic>) onEdit;

  const _RecentRequestCard({required this.request, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final String subject = request['emailSubject']?.toString() ?? 'Sin asunto';
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
                            Flexible(
                              child: Text(
                                'Ticket #${request['code']}',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: request['code'].toString()));
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
                      if (value == 'updates') {
                        GoRouter.of(context).push('/request-updates/${Uri.encodeComponent((request['realId'] ?? request['original']['id']).toString())}', extra: {'docNo': request['code']});
                      }
                      if (value == 'attachments') {
                        showDialog(
                          context: context,
                          builder: (context) => DocumentsLogic.RequestAttachmentsDialog(requestId: request['realId'] ?? request['original']['id'], documentNo: request['code'] ?? ''),
                        );
                      }
                      if (value == 'go') {
                        GoRouter.of(context).push('/my-requests', extra: {'search': request['code']});
                      }
                      if (value == 'edit') onEdit(request);
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'go',
                        child: ListTile(leading: Icon(Icons.arrow_forward), title: Text('Ir a Mis Solicitudes')),
                      ),
                      PopupMenuItem<String>(
                        value: 'updates',
                        child: ListTile(leading: Icon(AccessControl.canAddUpdates ? Icons.reply : Icons.forum), title: Text(AccessControl.canAddUpdates ? 'Responder' : 'Ver Actualizaciones')),
                      ),
                      const PopupMenuItem<String>(
                        value: 'attachments',
                        child: ListTile(leading: Icon(Icons.attach_file), title: Text('Adjuntos')),
                      ),
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: ListTile(leading: Icon(AccessControl.canManageRequests ? Icons.edit : Icons.visibility), title: Text(AccessControl.canManageRequests ? 'Editar' : 'Ver Detalles')),
                      ),
                    ],
                  ),
                ],
              ),
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
                  () {
                    final chipId = request['productChipId'];
                    if (chipId == null) return const SizedBox.shrink();
                    final found = GlobalCache.productChips.firstWhere(
                      (c) => c['id'] == chipId,
                      orElse: () => {},
                    );
                    final chipName = found.isEmpty ? '#$chipId' : (found['Description'] ?? found['Name'] ?? '#$chipId');
                    return Chip(
                      avatar: Icon(Icons.inventory_2_outlined, size: 14, color: colorScheme.primary),
                      label: Text(chipName),
                      labelStyle: theme.textTheme.bodySmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
                      backgroundColor: colorScheme.primaryContainer.withOpacity(0.3),
                      shape: StadiumBorder(side: BorderSide(color: colorScheme.primary.withOpacity(0.2))),
                      visualDensity: VisualDensity.compact,
                    );
                  }(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
