import 'package:flutter/material.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/ui/pages/Projects/dialogs/request_details_dialog.dart';
import 'package:primhub/ui/pages/Support/Requests/edit_request_dialog.dart';
import 'package:primhub/ui/shared/custom_modal.dart';
import 'package:primhub/ui/shared/custom_button.dart';

class RequestsDataTable extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final Map<String, int> statusIdMap;
  final Map<String, String> priorityMap;
  final VoidCallback onRefresh;

  const RequestsDataTable({super.key, required this.requests, required this.statusIdMap, required this.priorityMap, required this.onRefresh});

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
          DataColumn(label: Text('Ticket')),
          DataColumn(label: Text('Resumen')),
          DataColumn(label: Text('Estado')),
          DataColumn(label: Text('Prioridad')),
          DataColumn(label: Text('Fecha Fin Plan')),
        ],
        rows: requests.map((req) {
          return DataRow(
            onSelectChanged: (selected) {
              if (selected == true) {
                if (AccessControl.canManageRequests) {
                  _editRequest(context, req);
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
              DataCell(Text(DocumentsLogic.extractValue(req['Status']))),
              DataCell(Text(DocumentsLogic.extractValue(req['Priority']))),
              DataCell(Text(req['DateCompletePlan']?.toString().split('T')[0] ?? '')),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _editRequest(BuildContext context, Map<String, dynamic> req) {
    String level = DocumentsLogic.extractValue(req['Priority']);
    if (level == 'N/A') level = 'Media';
    String status = DocumentsLogic.extractValue(req['Status']);
    if (status == 'N/A') status = '1_Open';

    int? statusId;
    if (req['Status'] is Map) statusId = req['Status']['id'];

    Color baseColor = Colors.green;
    if (level == 'Urgente') {
      baseColor = Colors.purple;
    } else if (level == 'Alta') {
      baseColor = Colors.red;
    } else if (level == 'Media') {
      baseColor = Colors.amber.shade800;
    } else if (level == 'Menor') {
      baseColor = Colors.grey;
    }

    final mappedReq = {
      'id': req['DocumentNo'] ?? req['id'].toString(),
      'realId': req['id'],
      'situation': DocumentsLogic.extractValue(req['R_RequestType_ID']),
      'description': req['Summary'] ?? '',
      'level': level,
      'status': status,
      'statusId': statusId,
      'time': req['Created'] ?? '',
      'levelColor': baseColor,
      'levelBgColor': baseColor.withOpacity(0.2),
      'statusColor': Colors.grey,
      'dateStartPlan': req['DateStartPlan'] ?? '',
      'dateCompletePlan': req['DateCompletePlan'] ?? '',
      'startTime': req['StartTime'] ?? '',
      'endTime': req['EndTime'] ?? '',
      'qtyPlan': req['QtyPlan']?.toString() ?? '',
      'startDate': req['StartDate'],
      'closeDate': req['CloseDate'],
      'userName': DocumentsLogic.extractValue(req['AD_User_ID']),
      'bpName': DocumentsLogic.extractValue(req['C_BPartner_ID']),
    };

    showDialog(
      context: context,
      builder: (context) => EditRequestDialog(request: mappedReq, statusIdMap: statusIdMap, priorityMap: priorityMap, onSave: onRefresh, onDelete: () => _deleteRequest(context, req['id'])),
    );
  }

  Future<void> _deleteRequest(BuildContext context, dynamic id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => CustomModal(
        title: 'Confirmar Eliminación',
        content: const Text('¿Está seguro de que desea eliminar esta solicitud?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          CustomButton(text: 'Eliminar', backgroundColor: Colors.red, onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirm == true) {
      final success = await DocumentsLogic.deleteRequest(id);
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud eliminada correctamente')));
          onRefresh();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al eliminar la solicitud')));
        }
      }
    }
  }
}
