import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:primhub/api/api_http.dart' as http;
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/api/global_cache.dart';
import 'package:primhub/ui/pages/Support/Requests/bulk_summary_view.dart';
import 'package:primhub/ui/pages/Support/Requests/bulk_edit_request_dialog.dart';

class BulkReopenRequestDialog extends StatefulWidget {
  final Set<int> selectedIds;
  final VoidCallback onSaved;

  const BulkReopenRequestDialog({
    super.key,
    required this.selectedIds,
    required this.onSaved,
  });

  @override
  State<BulkReopenRequestDialog> createState() => _BulkReopenRequestDialogState();
}

class _BulkReopenRequestDialogState extends State<BulkReopenRequestDialog> {
  bool _isSaving = false;
  bool _showSummary = false;
  final List<Map<String, dynamic>> _results = [];
  int? _processingId;
  int _successCount = 0;
  int _errorCount = 0;
  int _currentIndex = 0;

  Future<Map<String, dynamic>> _reopenRequest(int requestId) async {
    try {
      final response = await http.post(
        Uri.parse('${Endpoint.baseUrl}/api/v1/processes/r_request_reopen'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
        body: jsonEncode({
          'R_Request_ID': requestId,
        }),
      );

      // Algunos procesos de iDempiere retornan 200 o 201 si son exitosos
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': 'OK'};
      }
      
      String errorMsg = 'Error ${response.statusCode}';
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded['summary'] != null) {
          errorMsg = decoded['summary'];
        } else if (decoded['error'] != null) {
          errorMsg = decoded['error'];
        }
      } catch (_) {}
      
      return {'success': false, 'message': errorMsg};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<void> _handleReopen() async {
    setState(() {
      _isSaving = true;
      _showSummary = false;
      _results.clear();
      _successCount = 0;
      _errorCount = 0;
      _currentIndex = 0;
    });

    for (int i = 0; i < widget.selectedIds.length; i++) {
      final id = widget.selectedIds.elementAt(i);
      if (!mounted) break;
      
      setState(() {
        _processingId = id;
        _currentIndex = i + 1;
      });

      final request = GlobalCache.requests.firstWhere((r) => r['id'] == id, orElse: () => <String, dynamic>{});
      final documentNo = request['DocumentNo']?.toString() ?? request['documentNo']?.toString() ?? id.toString();
      final summary = request['Summary']?.toString() ?? '';

      final result = await _reopenRequest(id);
      final success = result['success'] == true;

      _results.add({
        'id': id,
        'documentNo': documentNo,
        'summary': summary,
        'success': success,
        'error': success ? null : result['message'],
      });

      if (success) {
        await GlobalCache.syncSingleRequest(id);
        if (mounted) setState(() => _successCount++);
      } else {
        if (mounted) setState(() => _errorCount++);
      }
    }

    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 600)); // Pequeña pausa
      if (!mounted) return;
      
      setState(() {
        _isSaving = false;
        _showSummary = true;
        _processingId = null;
      });
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSummary) {
      return CustomModal(
        title: 'Resumen de Reapertura',
        width: 600,
        content: BulkSummaryView(
          results: _results,
        ),
        actions: [
          CustomButton(
            text: 'Editar Reabiertas',
            backgroundColor: Colors.blue.shade700,
            onPressed: () {
              final successfulIds = _results
                  .where((r) => r['success'] == true)
                  .map((r) => r['id'] as int)
                  .toSet();

              if (successfulIds.isEmpty) {
                // Si por alguna razon le da click sin tener exitosas
                return;
              }

              Navigator.pop(context); // Cerrar resumen
              showDialog(
                context: context,
                builder: (context) => BulkEditRequestDialog(
                  selectedIds: successfulIds,
                  onSaved: widget.onSaved,
                ),
              );
            },
          ),
          CustomButton(
            text: 'Cerrar',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      );
    }

    if (_isSaving) {
      final request = _processingId != null 
          ? GlobalCache.requests.firstWhere((r) => r['id'] == _processingId, orElse: () => <String, dynamic>{}) 
          : <String, dynamic>{};
      final documentNo = request['DocumentNo']?.toString() ?? 'Cargando...';
      final summary = request['Summary']?.toString() ?? '';

      return CustomModal(
        title: 'Reabriendo Solicitudes...',
        width: 500,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Procesando solicitud $_currentIndex de ${widget.selectedIds.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: widget.selectedIds.isEmpty ? 0 : _currentIndex / widget.selectedIds.length),
            const SizedBox(height: 24),
            if (_processingId != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sync, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ticket #$documentNo', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(height: 4),
                    Text('$_successCount Exitosos'),
                  ],
                ),
                Column(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(height: 4),
                    Text('$_errorCount Errores'),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: const [], // Sin botones mientras se guarda
      );
    }

    return CustomModal(
      title: 'Confirmar Reapertura',
      width: 500,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Está seguro que desea reabrir masivamente las ${widget.selectedIds.length} solicitudes seleccionadas?',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          const Text(
            'Al hacer esto, se ejecutará el proceso de reabir solicitudes para cada una de las seleccionadas. Esta acción no se puede deshacer de forma masiva (tendría que cerrarlas manualmente o editar su estado).',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        CustomButton(
          text: 'Reabrir ${widget.selectedIds.length} solicitudes',
          onPressed: _handleReopen,
          isLoading: _isSaving,
        ),
      ],
    );
  }
}
