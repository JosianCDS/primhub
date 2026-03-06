import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:primhub/ImagesManagment/downloadAttachments.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class FilePreviewManager {
  static void showPreview(BuildContext context, Map<String, dynamic> details, String tableName, String name, VoidCallback onDelete, VoidCallback onStatusChanged) {
    final extension = name.split('.').last.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension);
    final isPdf = extension == 'pdf';
    final isCsv = extension == 'csv';
    final isText = ['txt', 'json', 'xml', 'md', 'log'].contains(extension);
    bool isDownloading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return CustomModal(
              title: name,
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isImage || isPdf || isText || isCsv)
                      FutureBuilder<Uint8List?>(
                        future: DocumentsLogic.fetchImagePreview(tableName, details['id'], name),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                          if (snapshot.hasData && snapshot.data != null) {
                            if (isImage)
                              return ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 400),
                                child: Image.memory(snapshot.data!, fit: BoxFit.contain),
                              );
                            if (isPdf) return SizedBox(height: 500, child: SfPdfViewer.memory(snapshot.data!));
                            if (isCsv) return _buildCsvPreview(snapshot.data!);
                            if (isText) return _buildTextPreview(snapshot.data!);
                          }
                          return const Text('No se pudo cargar la previsualización');
                        },
                      )
                    else
                      _buildNoPreviewWidget(extension),
                    const SizedBox(height: 20),
                    _buildPropertyRow('Estado', DocumentsLogic.extractStatus(details['Status'])),
                    _buildPropertyRow('Versión', DocumentsLogic.extractIdentifier(details['VersionNo'])),
                  ],
                ),
              ),
              actions: [
                if (AccessControl.canManageFiles)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      Navigator.pop(context);
                      onDelete();
                    },
                  ),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
                CustomButton(
                  text: 'Descargar',
                  icon: Icons.download,
                  isLoading: isDownloading,
                  onPressed: !AccessControl.canDownloadFiles
                      ? null
                      : () async {
                          setStateDialog(() => isDownloading = true);
                          await downloadAttachment(context: context, recordID: details['id'], tableName: tableName, fileName: name, onStatusChanged: onStatusChanged);
                          if (context.mounted) setStateDialog(() => isDownloading = false);
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Widget _buildCsvPreview(Uint8List data) {
    try {
      String content = utf8.decode(data, allowMalformed: true);
      List<String> lines = content.split('\n');
      if (lines.isEmpty) return const Text('Archivo vacío');
      List<List<String>> rows = lines.where((l) => l.trim().isNotEmpty).map((line) => line.split(',')).toList();
      if (rows.isEmpty) return const Text('Archivo vacío');
      return Container(
        height: 400,
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: rows.first.map((e) => DataColumn(label: Text(e.trim()))).toList(),
              rows: rows.skip(1).map((row) {
                final cells = row.take(rows.first.length).toList();
                while (cells.length < rows.first.length) cells.add('');
                return DataRow(cells: cells.map((cell) => DataCell(Text(cell.trim()))).toList());
              }).toList(),
            ),
          ),
        ),
      );
    } catch (e) {
      return const Text('Error al visualizar CSV');
    }
  }

  static Widget _buildTextPreview(Uint8List data) {
    String textContent = "Error al decodificar.";
    try {
      textContent = utf8.decode(data, allowMalformed: true);
    } catch (_) {}
    return Container(
      height: 400,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(child: SelectableText(textContent)),
    );
  }

  static Widget _buildNoPreviewWidget(String extension) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(DocumentsLogic.getFileIcon(extension), size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('Previsualización no disponible para .$extension', textAlign: TextAlign.center),
        ],
      ),
    );
  }

  static Widget _buildPropertyRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          const Divider(),
        ],
      ),
    );
  }
}
