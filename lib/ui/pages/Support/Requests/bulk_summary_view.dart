import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:primhub/ui/Shared_Custom/custom_toast.dart';

class BulkSummaryView extends StatelessWidget {
  final List<Map<String, dynamic>> results;

  const BulkSummaryView({
    super.key,
    required this.results,
  });

  void _copyToClipboard(BuildContext context) {
    final buffer = StringBuffer();
    final successes = results.where((r) => r['success'] == true).toList();
    final errors = results.where((r) => r['success'] != true).toList();

    buffer.writeln('RESUMEN DE OPERACIÓN MASIVA');
    buffer.writeln('===========================');
    buffer.writeln('Exitosos: ${successes.length}');
    buffer.writeln('Errores: ${errors.length}');
    buffer.writeln();

    if (successes.isNotEmpty) {
      buffer.writeln('--- EXITOSOS ---');
      for (final r in successes) {
        buffer.writeln('Ticket #${r['documentNo']}: OK');
      }
      buffer.writeln();
    }

    if (errors.isNotEmpty) {
      buffer.writeln('--- ERRORES ---');
      for (final r in errors) {
        buffer.writeln('Ticket #${r['documentNo']}: FALLÓ - ${r['error'] ?? 'Error desconocido'}');
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ToastMessage.show(
      context: context,
      message: 'Resumen copiado al portapapeles',
      type: ToastType.success,
    );
  }

  void _showErrorDetails(BuildContext context, Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Detalles del Error - Ticket #${result['documentNo']}'),
        content: SingleChildScrollView(
          child: Text(result['error']?.toString() ?? 'Error desconocido'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final successes = results.where((r) => r['success'] == true).toList();
    final errors = results.where((r) => r['success'] != true).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Resultados: ${successes.length} Exitosos, ${errors.length} Errores',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copiar al portapapeles',
              onPressed: () => _copyToClipboard(context),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 300,
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          Text('Exitosos (${successes.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Text('Errores (${errors.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildList(context, successes, true),
                      _buildList(context, errors, false),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context, List<Map<String, dynamic>> items, bool isSuccess) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          isSuccess ? 'No hubo solicitudes exitosas' : 'No hubo errores',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final documentNo = item['documentNo'] ?? '';
        final summary = item['summary'] ?? '';
        final errorMsg = item['error'] ?? 'Error desconocido';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          leading: Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: isSuccess ? Colors.green : Colors.red,
          ),
          title: Text('Ticket #$documentNo', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            isSuccess ? summary : errorMsg,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: isSuccess ? Colors.grey : Colors.red.shade700),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.copy, size: 20, color: Colors.grey),
                onPressed: () {
                  final textToCopy = 'Ticket #$documentNo: ${isSuccess ? 'OK' : 'FALLÓ - $errorMsg'}';
                  Clipboard.setData(ClipboardData(text: textToCopy));
                  ToastMessage.show(
                    context: context,
                    message: 'Ticket #$documentNo copiado',
                    type: ToastType.success,
                  );
                },
                tooltip: 'Copiar este resultado',
              ),
              if (!isSuccess)
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.red, size: 20),
                  onPressed: () => _showErrorDetails(context, item),
                  tooltip: 'Ver error',
                ),
            ],
          ),
          onTap: !isSuccess ? () => _showErrorDetails(context, item) : null,
        );
      },
    );
  }
}
