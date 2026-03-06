import 'package:flutter/material.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/ui/pages/Projects/dialogs/request_details_dialog.dart';
import 'package:primhub/ui/pages/Support/Requests/edit_request_dialog.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';

class RequestsDataTable extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final Map<String, int> statusIdMap;
  final Map<String, String> priorityMap;
  final Function(Map<String, dynamic>) onEdit;

  const RequestsDataTable({super.key, required this.requests, required this.statusIdMap, required this.priorityMap, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        headingRowHeight: 30,
        dataRowMinHeight: 30,
        dataRowMaxHeight: 40,
        columns: const [
          DataColumn(label: Text('Solicitud')),
          DataColumn(label: Text('Resumen')),
          DataColumn(label: Text('Tipo')),
          DataColumn(label: Text('Categoría')),
          DataColumn(label: Text('Grupo')),
          DataColumn(label: Text('Estado')),
          DataColumn(label: Text('Prioridad')),
          DataColumn(label: Text('Fecha Fin Plan')),
        ],
        rows: requests.map((req) {
          return DataRow(
            onSelectChanged: (selected) {
              if (selected == true) {
                if (AccessControl.canManageRequests) {
                  onEdit(req);
                } else if (AccessControl.canViewRequestDetails) {
                  showDialog(
                    context: context,
                    builder: (context) => RequestDetailsDialog(req: req),
                  );
                }
              }
            },
            cells: [
              DataCell(Text(req['id'].toString())),
              DataCell(
                Text(() {
                  final text = DocumentsLogic.extractValue(req['Summary']);
                  return text.length > 35 ? '${text.substring(0, 35)}...' : text;
                }()),
              ),
              DataCell(Text(DocumentsLogic.extractValue(req['R_RequestType_ID']))),
              DataCell(Text(DocumentsLogic.extractValue(req['R_Category_ID']))),
              DataCell(Text(DocumentsLogic.extractValue(req['R_Group_ID']))),
              DataCell(Text(DocumentsLogic.extractValue(req['Status']))),
              DataCell(Text(DocumentsLogic.extractValue(req['Priority']))),
              DataCell(Text(req['DateCompletePlan']?.toString().split('T')[0] ?? '')),
            ],
          );
        }).toList(),
      ),
    );
  }
}
