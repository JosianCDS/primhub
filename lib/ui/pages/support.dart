import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/shared/cardcustom.dart';
import 'package:primhub/ui/shared/custom_container.dart';
import 'package:primhub/ui/shared/custom_table.dart';
import '../widgets/custom_drawer.dart';
import 'request/request_functions.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  List<Map<String, dynamic>> _supportRecords = [];
  bool _isLoading = true;
  double _totalConsumedHours = 0.0;
  double? _contractedHours;
  DateTime? _lastContractDate;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _loadContractedHours();
    await _loadSupportData();
  }

  Future<void> _loadSupportData() async {
    final requests = await fetchRequest();

    double total = 0.0;
    List<Map<String, dynamic>> validRequests = [];

    for (var req in requests) {
      // Solo mostrar y sumar si está cerrado (Final Close)
      if (req['R_Status_Name'] != '9_Final Close' && req['R_Status_ID'] != 103)
        continue;

      // Filtrar por fecha del último contrato
      if (_lastContractDate != null) {
        final reqDate = DateTime.tryParse(req['Created'] ?? '');
        if (reqDate != null && reqDate.isBefore(_lastContractDate!)) {
          continue;
        }
      }

      // El consumo es la cantidad planeada (QtyPlan) una vez cerrado
      double hours = (req['QtyPlan'] as num?)?.toDouble() ?? 0.0;

      if (hours > 0) {
        total += hours;
        validRequests.add(req);
      }
    }

    if (mounted) {
      setState(() {
        _supportRecords = validRequests;
        _totalConsumedHours = total;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadContractedHours() async {
    final payload = Token.decodePayload(Token.token);
    final int userId = payload['AD_User_ID'] ?? 101;

    final String queryUrl =
        "${Endpoint.baseUrl}/api/v1/models/C_Invoice?\$filter=IsSOTrx eq true and C_DocTypeTarget_ID eq 116 and AD_User_ID eq $userId and (DocStatus eq 'CO' or DocStatus eq 'DR')&\$expand=C_InvoiceLine(\$select=M_Product_ID,QtyEntered;\$filter=M_Product_ID eq 1000850)&\$select=DocumentNo";

    try {
      final response = await http.get(
        Uri.parse(queryUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final records = jsonResponse['records'] as List;

        // Ordenar para encontrar el último contrato
        records.sort(
          (a, b) => (b['Created'] ?? '').compareTo(a['Created'] ?? ''),
        );

        double total = 0.0;

        if (records.isNotEmpty) {
          final latest = records.first;
          _lastContractDate = DateTime.tryParse(latest['Created'] ?? '');

          final lines = latest['C_InvoiceLine'] as List?;
          if (lines != null && lines.isNotEmpty) {
            for (var line in lines) {
              total += (line['QtyEntered'] as num?)?.toDouble() ?? 0.0;
            }
          }
        }

        if (mounted) {
          setState(() {
            _contractedHours = total;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading contracted hours: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestión de Horas de Soporte',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      drawer: const CustomDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              color: isDark ? colorScheme.surface : const Color(0xFFFEFEFE),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resumen del contrato',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final card1 = CardCustom(
                          height: 150,
                          width: null,
                          elevation: 0,
                          color: isDark
                              ? colorScheme.surfaceContainerHighest
                              : const Color(0xFFF6F8FA),
                          hover: true,
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Horas Contratadas',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? colorScheme.onSurfaceVariant
                                        : const Color(0xff777D8A),
                                  ),
                                ),
                                Text(
                                  _contractedHours == null
                                      ? '...'
                                      : _contractedHours!.toStringAsFixed(0),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? colorScheme.onSurface
                                        : const Color(0xFF1C2430),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        final card2 = CardCustom(
                          height: 150,
                          width: null,
                          elevation: 0,
                          color: isDark
                              ? colorScheme.surfaceContainerHighest
                              : const Color(0xFFF6F8FA),
                          hover: true,
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Horas Consumidas',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? colorScheme.onSurfaceVariant
                                        : const Color(0xff777D8A),
                                  ),
                                ),
                                Text(
                                  _isLoading
                                      ? '...'
                                      : _totalConsumedHours.toStringAsFixed(1),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? colorScheme.error
                                        : const Color(0xFFD12324),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        final card3 = CardCustom(
                          height: 150,
                          width: null,
                          elevation: 0,
                          color: isDark
                              ? colorScheme.surfaceContainerHighest
                              : const Color(0xFFE9EFFD),
                          hover: true,
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Horas Disponibles',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? colorScheme.primary
                                        : const Color(0xFF463EE2),
                                  ),
                                ),
                                Text(
                                  _isLoading || _contractedHours == null
                                      ? '...'
                                      : (_contractedHours! -
                                                _totalConsumedHours)
                                            .toStringAsFixed(1),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? colorScheme.primary
                                        : const Color(0xFF463EE2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );

                        if (constraints.maxWidth < 800) {
                          return Column(
                            children: [
                              SizedBox(width: double.infinity, child: card1),
                              const SizedBox(height: 10),
                              SizedBox(width: double.infinity, child: card2),
                              const SizedBox(height: 10),
                              SizedBox(width: double.infinity, child: card3),
                            ],
                          );
                        } else {
                          return Row(
                            children: [
                              Expanded(child: card1),
                              const SizedBox(width: 10),
                              Expanded(child: card2),
                              const SizedBox(width: 10),
                              Expanded(child: card3),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            CustomContainer(
              title: 'Registro de Horas Consumidas',
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : CustomTable(
                      columns: const [
                        DataColumn(label: Text('Ticket Relacionado')),
                        DataColumn(label: Text('Actividad/Tarea')),
                        DataColumn(label: Text('Fecha de inicio Planeada')),
                        DataColumn(
                          label: Text('Fecha de Terminacion Planeada'),
                        ),
                        DataColumn(label: Text('Horas Consumidas')),
                      ],
                      rows: _supportRecords.map((record) {
                        final hours = record['QtyPlan']?.toString() ?? '0';
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                record['DocumentNo'] ?? record['id'].toString(),
                              ),
                            ),
                            DataCell(Text(record['Summary'] ?? '')),
                            DataCell(Text(record['DateStartPlan'] ?? '')),
                            DataCell(Text(record['DateCompletePlan'] ?? '')),
                            DataCell(Text(hours)),
                          ],
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
