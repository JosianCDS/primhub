import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/Shared_Custom/custom_container.dart';
import 'package:primhub/ui/Shared_Custom/custom_table.dart';

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
                ? const Padding(
                    padding: EdgeInsets.all(50.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : CustomTable(
                    columns: const [
                      DataColumn(label: Text('Ticket')),
                      DataColumn(label: Text('Tipo de Solicitud')),
                      DataColumn(label: Text('Asunto')),
                      DataColumn(label: Text('Tercero')),
                      DataColumn(label: Text('Usuario')),
                      DataColumn(label: Text('Nivel')),
                      DataColumn(label: Text('Ultima Actualización')),
                      DataColumn(label: Text('Descripción')),
                      DataColumn(label: Text('Estado')),
                    ],
                    rows: requests.map((req) {
                      return DataRow(
                        onSelectChanged: (value) => onEdit(req),
                        cells: [
                          DataCell(Text(req['code'])),
                          DataCell(Text(req['situation'])),
                          DataCell(Tooltip(message: req['emailSubject']?.toString() ?? '', child: Text((req['emailSubject']?.toString() ?? '').length > 25 ? '${(req['emailSubject']?.toString() ?? '').substring(0, 25)}...' : (req['emailSubject']?.toString() ?? '')))),
                          DataCell(Text(req['bpName'])),
                          DataCell(Text(req['userName'])),
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
                              message: req['description'] ?? '',
                              child: SizedBox(width: 300, child: Text((req['description'] ?? '').length > 70 ? '${(req['description'] ?? '').substring(0, 70)}...' : (req['description'] ?? ''))),
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
