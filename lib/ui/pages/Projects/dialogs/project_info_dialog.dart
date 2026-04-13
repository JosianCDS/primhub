import 'package:flutter/material.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';

/// Dialogo de solo lectura para visualizar toda la información de un Proyecto (Exclusivo para Administradores)
class ProjectInfoDialog extends StatelessWidget {
  final Map<String, dynamic> project;

  const ProjectInfoDialog({super.key, required this.project});

  String _getIdentifier(dynamic value) {
    if (value == null) return 'N/A';
    if (value is Map) return value['identifier']?.toString() ?? value['Name']?.toString() ?? 'N/A';
    return value.toString();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return dateStr.split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomModal(
      title: 'Información del Proyecto',
      width: 700,
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Información General', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    label: 'Nombre',
                    controller: TextEditingController(text: project['Name'] ?? 'N/A'),
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
                    label: 'Código (Value)',
                    controller: TextEditingController(text: project['Value'] ?? 'N/A'),
                    readOnly: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Descripción',
              controller: TextEditingController(text: project['Description'] ?? 'N/A'),
              maxLines: 3,
              readOnly: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    label: 'Fecha Contrato',
                    controller: TextEditingController(text: _formatDate(project['DateContract'])),
                    readOnly: true,
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
                    label: 'Fecha Fin',
                    controller: TextEditingController(text: _formatDate(project['DateFinish'])),
                    readOnly: true,
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Maestros y Responsables', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    label: 'Tercero (Cliente)',
                    controller: TextEditingController(text: _getIdentifier(project['C_BPartner_ID'])),
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
                    label: 'Representante Comercial',
                    controller: TextEditingController(text: _getIdentifier(project['SalesRep_ID'] ?? project['C_BPartnerSR_ID'])),
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
                    label: 'Moneda',
                    controller: TextEditingController(text: _getIdentifier(project['C_Currency_ID'])),
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
                    label: 'Regla de Factura',
                    controller: TextEditingController(text: _getIdentifier(project['ProjInvoiceRule'])),
                    readOnly: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Detalles Financieros', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    label: 'Importe Planeado',
                    controller: TextEditingController(text: project['PlannedAmt']?.toString() ?? '0.0'),
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
                    label: 'Cantidad Planeada',
                    controller: TextEditingController(text: project['PlannedQty']?.toString() ?? '0.0'),
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
                    label: 'Importe Comprometido',
                    controller: TextEditingController(text: project['CommittedAmt']?.toString() ?? '0.0'),
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
                    label: 'Cantidad Comprometida',
                    controller: TextEditingController(text: project['CommittedQty']?.toString() ?? '0.0'),
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
                    label: 'Margen Planeado',
                    controller: TextEditingController(text: project['PlannedMarginAmt']?.toString() ?? '0.0'),
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
                    label: 'Balance del Proyecto',
                    controller: TextEditingController(text: project['ProjectBalanceAmt']?.toString() ?? '0.0'),
                    readOnly: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
    );
  }
}
