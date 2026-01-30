import 'package:flutter/material.dart';
import 'package:primhub/api/contract_api.dart';
import 'package:primhub/ui/shared/cardcustom.dart';
import 'package:primhub/ui/shared/custom_container.dart';
import 'package:primhub/ui/shared/custom_table.dart';
import 'package:primhub/ui/shared/custom_inputs.dart';
import 'package:primhub/ui/shared/custom_modal.dart';
import '../widgets/custom_drawer.dart';
import 'package:primhub/ui/shared/duration_formatter.dart';
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
    final total = await ContractApi.getContractedHours();
    if (mounted && total != null) {
      setState(() {
        _contractedHours = total;
      });
    }
  }

  void _showRequestDetails(Map<String, dynamic> record) {
    final TextEditingController summaryController = TextEditingController(
      text: record['Summary'] ?? '',
    );
    final TextEditingController dateStartController = TextEditingController(
      text: record['DateStartPlan'] ?? '',
    );
    final TextEditingController dateCompleteController = TextEditingController(
      text: record['DateCompletePlan'] ?? '',
    );

    String extractTime(String? val) {
      if (val == null || val.isEmpty) return '';
      String t = val;
      if (t.contains('T')) {
        t = t.split('T')[1];
      }
      return t.replaceAll('Z', '');
    }

    final TextEditingController startTimeController = TextEditingController(
      text: extractTime(record['StartTime']),
    );
    final TextEditingController endTimeController = TextEditingController(
      text: extractTime(record['EndTime']),
    );

    final double h = (record['QtyPlan'] as num?)?.toDouble() ?? 0.0;
    final TextEditingController qtyPlanController = TextEditingController(
      text: DurationFormatter.format(h),
    );

    showDialog(
      context: context,
      builder: (context) => CustomModal(
        title: 'Detalle del Ticket ${record['DocumentNo'] ?? record['id']}',
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: summaryController,
                label: 'Descripción / Resumen',
                readOnly: true,
                maxLines: 10,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: dateStartController,
                      label: 'Inicio Plan',
                      readOnly: true,
                      prefixIcon: const Icon(Icons.calendar_today),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      controller: dateCompleteController,
                      label: 'Fin Plan',
                      readOnly: true,
                      prefixIcon: const Icon(Icons.calendar_today),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: startTimeController,
                      label: 'Hora Inicio',
                      readOnly: true,
                      prefixIcon: const Icon(Icons.access_time),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      controller: endTimeController,
                      label: 'Hora Fin',
                      readOnly: true,
                      prefixIcon: const Icon(Icons.access_time),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: qtyPlanController,
                label: 'Horas Consumidas',
                readOnly: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
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
      body: SafeArea(
        child: SingleChildScrollView(
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
                                        : DurationFormatter.format(
                                            _contractedHours!,
                                          ),
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
                                        : DurationFormatter.format(
                                            _totalConsumedHours,
                                          ),
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
                                        : DurationFormatter.format(
                                            _contractedHours! -
                                                _totalConsumedHours,
                                          ),
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
                          final double h =
                              (record['QtyPlan'] as num?)?.toDouble() ?? 0.0;
                          final hours = DurationFormatter.format(h);
                          return DataRow(
                            onSelectChanged: (value) =>
                                _showRequestDetails(record),
                            cells: [
                              DataCell(
                                Text(
                                  record['DocumentNo'] ??
                                      record['id'].toString(),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 300,
                                  child: Text(
                                    (record['Summary'] != null &&
                                            record['Summary'].length > 80)
                                        ? '${record['Summary'].substring(0, 80)}...'
                                        : record['Summary'] ?? '',
                                  ),
                                ),
                              ),
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
      ),
    );
  }
}
