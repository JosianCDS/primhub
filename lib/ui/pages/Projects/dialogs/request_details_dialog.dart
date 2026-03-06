import 'package:flutter/material.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';

class RequestDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> req;

  const RequestDetailsDialog({super.key, required this.req});

  @override
  Widget build(BuildContext context) {
    final summary = req['Summary'] ?? '';
    final status = DocumentsLogic.extractValue(req['Status'] ?? req['R_Status_ID']);
    final priority = DocumentsLogic.extractValue(req['Priority']);
    final dateStart = req['DateStartPlan']?.toString().split('T')[0] ?? '';
    final dateComplete = req['DateCompletePlan']?.toString().split('T')[0] ?? '';
    final qtyPlan = req['QtyPlan']?.toString() ?? '0';

    return CustomModal(
      title: 'Detalle Solicitud ${req['DocumentNo'] ?? req['id']}',
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              controller: TextEditingController(text: summary),
              label: 'Resumen',
              readOnly: true,
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: TextEditingController(text: status),
                    label: 'Estado',
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
                    controller: TextEditingController(text: priority),
                    label: 'Prioridad',
                    readOnly: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: TextEditingController(text: dateStart),
                    label: 'Fecha Inicio',
                    readOnly: true,
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
                    controller: TextEditingController(text: dateComplete),
                    label: 'Fecha Fin',
                    readOnly: true,
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: TextEditingController(text: qtyPlan),
              label: 'Horas Planificadas',
              readOnly: true,
              prefixIcon: const Icon(Icons.timer),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
    );
  }
}
