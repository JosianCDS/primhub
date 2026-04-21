import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/Shared_Custom/custom_container.dart';
import 'package:primhub/ui/Shared_Custom/custom_table.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/Shared_Custom/custom_skeleton.dart';

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
    return CustomTable(
      columns: [
        const DataColumn(label: Text('Ticket')),
        const DataColumn(label: Text('Tipo de Solicitud')),
        const DataColumn(label: Text('Asunto')),
        if (AccessControl.isAdmin) const DataColumn(label: Text('Tercero')),
        if (AccessControl.isAdmin) const DataColumn(label: Text('Usuario')),
        if (AccessControl.isAdmin) const DataColumn(label: Text('Representante Comercial')),
        const DataColumn(label: Text('Nivel')),
        const DataColumn(label: Text('Ultima Actualización')),
        const DataColumn(label: Text('Descripción')),
        const DataColumn(label: Text('Estado')),
      ],
      rows: requests.map((req) {
        return DataRow(
          onSelectChanged: (value) => onEdit(req),
          cells: [
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(req['code']),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: req['code'].toString()));
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
            DataCell(Text(req['situation'])),
            DataCell(Tooltip(message: req['emailSubject']?.toString() ?? '', child: Text((req['emailSubject']?.toString() ?? '').length > 25 ? '${(req['emailSubject']?.toString() ?? '').substring(0, 25)}...' : (req['emailSubject']?.toString() ?? '')))),
            if (AccessControl.isAdmin) DataCell(Text(req['bpName'])),
            if (AccessControl.isAdmin) DataCell(Text(req['userName'])),
            if (AccessControl.isAdmin) DataCell(Text(req['salesRepName'] ?? '')),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: req['levelBgColor'], borderRadius: BorderRadius.circular(30)),
                child: Text(
                  req['level'],
                  style: TextStyle(color: req['levelColor'], fontWeight: FontWeight.bold),
                ),
              ),
            ),
            DataCell(Text(req['time'])),
            DataCell(
              Tooltip(
                message: req['descriptionClean'] ?? '',
                child: SizedBox(width: 300, child: Text((req['descriptionClean'] ?? '').length > 70 ? '${(req['descriptionClean'] ?? '').substring(0, 70)}...' : (req['descriptionClean'] ?? ''))),
              ),
            ),
            DataCell(Text(req['status'])),
          ],
        );
      }).toList(),
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
                            Text(
                              'Ticket #${request['code']}',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary),
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
                  IconButton(
                    icon: const Icon(Icons.visibility, color: Colors.grey),
                    tooltip: 'Ver Detalles',
                    onPressed: () => onEdit(request),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
