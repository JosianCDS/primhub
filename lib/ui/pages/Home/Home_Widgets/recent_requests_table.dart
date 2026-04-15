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
                ? const SkeletonTable()
                : CustomTable(
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
