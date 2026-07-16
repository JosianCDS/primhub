import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:universal_html/html.dart' as html;
import 'package:primhub/ui/widgets/duration_formatter.dart';
import 'package:primhub/api/global_cache.dart';

import 'package:primhub/api/token.dart';

class ExportFunctions {
  static String _sanitizeText(String text) {
    return text
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('–', '-')
        .replaceAll('—', '-');
  }

  static List<List<String>> _prepareData(List<Map<String, dynamic>> requests) {
    final List<List<String>> rows = [];
    rows.add(['Ticket', 'Descripción', 'Estado', 'Horas Consumidas', 'Ficha de Producto']);

    for (var req in requests) {
      final double h = (req['qtySpent'] as num?)?.toDouble() ?? 0.0;
      final hours = DurationFormatter.format(h);
      
      String chipDesc = 'N/A';
      final chipId = req['productChipId'];
      if (chipId != null) {
        final found = GlobalCache.productChips.firstWhere(
          (c) => c['id'] == chipId,
          orElse: () => <String, dynamic>{},
        );
        if (found.isNotEmpty) {
          chipDesc = (found['Description'] ?? found['Name'] ?? '#$chipId').toString();
        } else {
          chipDesc = '#$chipId';
        }
      }

      String description = (req['descriptionClean'] ?? '').toString().replaceAll('\n', ' ').replaceAll('\r', '');
      description = _sanitizeText(description);

      rows.add([
        req['id']?.toString() ?? '',
        description,
        _sanitizeText((req['status'] ?? '').toString()),
        hours,
        _sanitizeText(chipDesc),
      ]);
    }

    return rows;
  }

  static Future<void> _saveFile(List<int> bytes, String fileName, BuildContext context, String mimeType) async {
    try {
      if (kIsWeb) {
        final blob = html.Blob([bytes], mimeType);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", fileName)
          ..click();
        var _ = anchor;
        html.Url.revokeObjectUrl(url);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Descarga iniciada en el navegador.')));
        }
      } else {
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Guardar como...',
          fileName: fileName,
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsBytes(bytes);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Archivo guardado exitosamente en: $outputFile')));
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar el archivo: $e'), backgroundColor: Colors.red));
      }
    }
  }

  static Future<void> exportToCsv(List<Map<String, dynamic>> requests, BuildContext context) async {
    try {
      final rows = _prepareData(requests);
      rows.add([]);
      rows.add(['Generado desde Primhub']);
      
      String csv = rows.map((r) => r.map((c) => '"${c.toString().replaceAll('"', '""')}"').join(',')).join('\n');
      // Añadir BOM para que excel detecte el UTF-8 correctamente
      final bytes = [0xEF, 0xBB, 0xBF] + utf8.encode(csv);
      final dateStr = DateTime.now().toString().split(' ')[0];
      await _saveFile(bytes, 'Horas de Soporte - $dateStr.csv', context, 'text/csv;charset=utf-8');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generando CSV: $e'), backgroundColor: Colors.red));
      }
    }
  }

  static Future<void> exportToExcel(List<Map<String, dynamic>> requests, BuildContext context) async {
    try {
      final rows = _prepareData(requests);
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Horas_Soporte'];
      excel.setDefaultSheet('Horas_Soporte');

      // Agregando las filas al sheet
      for (var row in rows) {
        sheetObject.appendRow(row.map((e) => TextCellValue(e)).toList());
      }
      
      sheetObject.appendRow([TextCellValue('')]);
      sheetObject.appendRow([TextCellValue('Generado desde Primhub')]);

      var bytes = excel.encode();
      if (bytes != null) {
        final dateStr = DateTime.now().toString().split(' ')[0];
        await _saveFile(bytes, 'Horas de Soporte - $dateStr.xlsx', context, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generando Excel: $e'), backgroundColor: Colors.red));
      }
    }
  }

  static Future<void> exportToPdf(List<Map<String, dynamic>> requests, BuildContext context) async {
    try {
      final rows = _prepareData(requests);
      final pdf = pw.Document(
        title: 'Reporte de Horas de Soporte',
        author: 'Primhub',
        creator: 'Primhub',
        producer: 'Primhub Export',
      );

      String userName = User.name ?? 'Usuario Desconocido';
      String bPartnerName = 'Sin Tercero';
      if (User.cBPartnerID != null) {
        final bp = GlobalCache.allBPartners.firstWhere(
          (b) => b['id'] == User.cBPartnerID,
          orElse: () => <String, dynamic>{},
        );
        if (bp.isNotEmpty) {
          bPartnerName = bp['Name'] ?? 'Tercero Desconocido';
        }
      }

      // Fuente predeterminada para evitar problemas con acentos en web/desktop
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context ctx) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Reporte de Horas de Soporte', textScaleFactor: 2),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Fecha: ${DateTime.now().toString().split(' ')[0]}'),
                        pw.Text('Generado por: $userName'),
                        pw.Text('Tercero: $bPartnerName'),
                      ]
                    )
                  ]
                ),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                context: ctx,
                data: rows,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey100, width: .5))),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  0: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.center,
                  4: pw.Alignment.center,
                },
                columnWidths: const {
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(4),
                  2: pw.FlexColumnWidth(1.5),
                  3: pw.FlexColumnWidth(1.5),
                  4: pw.FlexColumnWidth(2),
                },
                cellStyle: const pw.TextStyle(fontSize: 10),
                headerHeight: 25,
                cellHeight: 20,
              ),
            ];
          },
          footer: (pw.Context ctx) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 10),
              child: pw.Text(
                'Generado desde Primhub - Página ${ctx.pageNumber} de ${ctx.pagesCount}',
                style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10),
              ),
            );
          },
        ),
      );

      final bytes = await pdf.save();
      final dateStr = DateTime.now().toString().split(' ')[0];
      await _saveFile(bytes, 'Horas de Soporte - $dateStr.pdf', context, 'application/pdf');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generando PDF: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
