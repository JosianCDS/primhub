import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/Shared_Custom/custom_container.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/ui/Shared_Custom/custom_table.dart';

class RecentRequestsTable extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final bool isLoading;
  final Function(Map<String, dynamic>) onEdit;

  const RecentRequestsTable({super.key, required this.requests, required this.isLoading, required this.onEdit});

  void _editRequest(BuildContext context, Map<String, dynamic> req) {
    String currentPriority = req['level'];
    String currentStatus = req['status'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return CustomModal(
            title: 'Editar Solicitud ${req['code']}',
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomDropdown<String>(
                  label: 'Nivel de Prioridad',
                  value: currentPriority,
                  items: ['Urgente', 'Alta', 'Media', 'Baja', 'Menor'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) {
                    if (val != null) setStateDialog(() => currentPriority = val);
                  },
                ),
                const SizedBox(height: 16),
                CustomDropdown<String>(
                  label: 'Estado',
                  value: currentStatus,
                  items: ['1_Open', '2_Waiting on customer', '3_Closed', '9_Final Close'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) {
                    if (val != null) setStateDialog(() => currentStatus = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              CustomButton(
                text: 'Guardar',
                onPressed: () {
                  // Update local map to reflect changes immediately in UI
                  req['level'] = currentPriority;
                  req['status'] = currentStatus;
                  if (currentPriority == 'Urgente') {
                    req['levelColor'] = Colors.purple;
                  } else if (currentPriority == 'Alta') {
                    req['levelColor'] = Colors.red;
                  } else if (currentPriority == 'Media') {
                    req['levelColor'] = Colors.amber.shade800;
                  } else if (currentPriority == 'Menor') {
                    req['levelColor'] = Colors.grey;
                  } else {
                    req['levelColor'] = Colors.green;
                  }
                  req['levelBgColor'] = (req['levelColor'] as Color).withOpacity(0.2);

                  onEdit(req);
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }

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
                        onSelectChanged: (value) => _editRequest(context, req),
                        cells: [
                          DataCell(Text(req['code'])),
                          DataCell(Text(req['situation'])),
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
                          DataCell(SizedBox(width: 300, child: Text(req['description'].length > 70 ? '${req['description'].substring(0, 70)}...' : req['description']))),
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
