import 'package:flutter/material.dart';
import 'package:primhub/ui/Shared_Custom/custom_table.dart';
import 'package:primhub/api/access_control.dart';

class RequestsDataTable extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final Function(Map<String, dynamic>) onEdit;

  const RequestsDataTable({super.key, required this.requests, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: CustomTable(
        columns: [
          const DataColumn(label: Text('Ticket')),
          const DataColumn(label: Text('Asunto')),
          const DataColumn(label: Text('Tercero')),
          const DataColumn(label: Text('Usuario')),
          const DataColumn(label: Text('Nivel')),
          const DataColumn(label: Text('Ultima Actualización')),
          const DataColumn(label: Text('Descripción')),
          const DataColumn(label: Text('Estado')),
        ],
        rows: requests.map((alert) {
          return DataRow(
            onSelectChanged: (value) => AccessControl.canManageRequests ? onEdit(alert) : null,
            cells: [
              DataCell(Text(alert['id'])),
              DataCell(Text(alert['situation'])),
              DataCell(Text(alert['bpName']?.toString() ?? '')),
              DataCell(Text(alert['userName']?.toString() ?? '')),
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
              DataCell(Text(alert['time'] ?? '')),
              DataCell(
                SizedBox(
                  width: 300,
                  child: Text(() {
                    final text = alert['description']?.toString() ?? '';
                    return text.length > 70 ? '${text.substring(0, 70)}...' : text;
                  }()),
                ),
              ),
              DataCell(Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 8), Text(alert['status'])])),
            ],
          );
        }).toList(),
      ),
    );
  }
}
