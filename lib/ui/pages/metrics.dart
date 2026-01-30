import 'package:flutter/material.dart';
import 'package:primhub/ui/shared/custom_chart.dart';
import 'package:primhub/ui/shared/custom_container.dart';
import '../../theme/colors.dart';
import '../widgets/custom_drawer.dart';
import 'package:primhub/ui/pages/request/request_functions.dart';
import 'package:primhub/ui/shared/custom_inputs.dart';

class MetricsPage extends StatefulWidget {
  const MetricsPage({super.key});

  @override
  State<MetricsPage> createState() => _MetricsPageState();
}

class _MetricsPageState extends State<MetricsPage> {
  bool _isLoading = true;
  List<double> _consumedByPriority = [0, 0, 0, 0, 0];
  List<double> _typeValues = [];
  List<String> _typeLabels = [];
  List<Color> _typeColors = [];
  List<String> _lineLabels = [];
  List<List<double>> _lineData = [[], []];

  // Filtros
  int _selectedYear = DateTime.now().year;
  String? _selectedPriority;
  bool _showResolved = true;
  bool _showUnresolved = true;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    try {
      final requests = await fetchRequest();
      final Map<String, double> totals = {
        'Urgente': 0.0,
        'Alta': 0.0,
        'Media': 0.0,
        'Baja': 0.0,
        'Menor': 0.0,
      };

      // Mapa para contar tipos de solicitud
      final Map<String, double> typeCounts = {};

      for (var req in requests) {
        // 1. Filtro de Fecha (Created)
        if (req['Created'] == null) continue;
        final created = DateTime.parse(req['Created']);
        if (created.year != _selectedYear) continue;

        // 2. Filtro de Prioridad
        final priority = req['Priority_Name'] ?? 'Media';
        if (_selectedPriority != null && priority != _selectedPriority) {
          continue;
        }

        // 3. Filtro de Estado (Resuelto / No Resuelto)
        final isResolved =
            req['R_Status_Name'] == '9_Final Close' ||
            req['R_Status_ID'] == 103;

        if (isResolved && !_showResolved) continue;
        if (!isResolved && !_showUnresolved) continue;

        // --- Procesamiento de Datos ---

        // Acumular Horas (QtyPlan) por Prioridad
        // Nota: Si se filtra "No Resueltos", mostrará las horas planeadas de los abiertos.
        // Si se filtra "Resueltos", mostrará las consumidas (que son QtyPlan al cerrar).
        // Para mantener consistencia con la gráfica anterior que era "Consumidas",
        // sumamos QtyPlan de lo que pase el filtro.
        if (true) {
          final qty = (req['QtyPlan'] as num?)?.toDouble() ?? 0.0;
          if (totals.containsKey(priority)) {
            totals[priority] = totals[priority]! + qty;
          }
        }

        // Contar tipos de solicitud (todas)
        final typeName = req['R_RequestType_Name'] ?? 'Otros';
        typeCounts[typeName] = (typeCounts[typeName] ?? 0) + 1;
      }

      // Preparar datos para el gráfico de anillo
      final List<String> labels = [];
      final List<double> values = [];
      final List<Color> colors = [];
      final List<Color> palette = [
        ColorTheme.info,
        ColorTheme.atention,
        ColorTheme.success,
        ColorTheme.error,
        const Color(0xFFBA68C8),
        const Color(0xFF795548),
        const Color(0xFF607D8B),
      ];

      int colorIndex = 0;
      typeCounts.forEach((key, value) {
        labels.add(key);
        values.add(value);
        colors.add(palette[colorIndex % palette.length]);
        colorIndex++;
      });

      // Lógica para Gráfico de Líneas (Meses del año seleccionado)
      final List<DateTime> months = [];
      for (int i = 1; i <= 12; i++) {
        months.add(DateTime(_selectedYear, i, 1));
      }

      final Map<String, int> receivedCounts = {};
      final Map<String, int> resolvedCounts = {};
      final List<String> monthLabels = [];

      for (var d in months) {
        String key = "${d.year}-${d.month.toString().padLeft(2, '0')}";
        receivedCounts[key] = 0;
        resolvedCounts[key] = 0;
        monthLabels.add(_getMonthNameShort(d.month));
      }

      // Para la tendencia, volvemos a iterar sobre los filtrados o sobre todos?
      // Lo ideal es que la tendencia respete los filtros de Prioridad,
      // pero el rango de fechas es el eje X.
      for (var req in requests) {
        // Aplicar filtro de Prioridad también a la tendencia
        final priority = req['Priority_Name'] ?? 'Media';
        if (_selectedPriority != null && priority != _selectedPriority) {
          continue;
        }

        // Recibidos (Created)
        if (req['Created'] != null) {
          try {
            final created = DateTime.parse(req['Created']);
            String key =
                "${created.year}-${created.month.toString().padLeft(2, '0')}";
            if (receivedCounts.containsKey(key)) {
              receivedCounts[key] = (receivedCounts[key] ?? 0) + 1;
            }
          } catch (_) {}
        }

        // Resueltos (CloseDate + Status Closed)
        if (req['R_Status_Name'] == '9_Final Close' ||
            req['R_Status_ID'] == 103) {
          if (req['CloseDate'] != null &&
              req['CloseDate'].toString().isNotEmpty) {
            try {
              final closed = DateTime.parse(req['CloseDate']);
              String key =
                  "${closed.year}-${closed.month.toString().padLeft(2, '0')}";
              if (resolvedCounts.containsKey(key)) {
                resolvedCounts[key] = (resolvedCounts[key] ?? 0) + 1;
              }
            } catch (_) {}
          }
        }
      }

      final List<double> receivedList = [];
      final List<double> resolvedList = [];

      for (var d in months) {
        String key = "${d.year}-${d.month.toString().padLeft(2, '0')}";
        receivedList.add((receivedCounts[key] ?? 0).toDouble());
        resolvedList.add((resolvedCounts[key] ?? 0).toDouble());
      }

      if (mounted) {
        setState(() {
          _consumedByPriority = [
            totals['Urgente']!,
            totals['Alta']!,
            totals['Media']!,
            totals['Baja']!,
            totals['Menor']!,
          ];
          _typeLabels = labels;
          _typeValues = values;
          _typeColors = colors;
          _lineLabels = monthLabels;
          _lineData = [receivedList, resolvedList];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLargeScreen = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(title: const Text('Indicadores de Negocio (BI)')),
      drawer: const CustomDrawer(),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Barra Lateral de Filtros (Dashboard) ---
            if (isLargeScreen)
              Container(
                width: 280,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  border: Border(right: BorderSide(color: theme.dividerColor)),
                ),
                child: _buildFilters(context),
              ),

            // --- Contenido Principal (Mosaico) ---
            Expanded(
              child: Column(
                children: [
                  if (!isLargeScreen)
                    ExpansionTile(
                      title: const Text("Filtros"),
                      children: [_buildFilters(context)],
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildDashboardGrid(context, isLargeScreen),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      children: [
        const Text(
          "Filtros del Dashboard",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        const Text("Año", style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        CustomDropdown<int>(
          value: _selectedYear,
          items: List.generate(5, (index) {
            final year = DateTime.now().year - index;
            return DropdownMenuItem(value: year, child: Text(year.toString()));
          }),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedYear = val);
              _loadMetrics();
            }
          },
        ),
        const SizedBox(height: 20),
        const Text("Prioridad", style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        CustomDropdown<String?>(
          value: _selectedPriority,
          hintText: "Todas",
          items: [
            const DropdownMenuItem(value: null, child: Text("Todas")),
            ...[
              'Urgente',
              'Alta',
              'Media',
              'Baja',
              'Menor',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))),
          ],
          onChanged: (val) {
            setState(() => _selectedPriority = val);
            _loadMetrics();
          },
        ),
        const SizedBox(height: 20),
        const Text("Estado", style: TextStyle(fontWeight: FontWeight.w600)),
        CheckboxListTile(
          title: const Text("Resueltos"),
          value: _showResolved,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            setState(() => _showResolved = val ?? true);
            _loadMetrics();
          },
        ),
        CheckboxListTile(
          title: const Text("No Resueltos"),
          value: _showUnresolved,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            setState(() => _showUnresolved = val ?? true);
            _loadMetrics();
          },
        ),
      ],
    );
  }

  Widget _buildDashboardGrid(BuildContext context, bool isLargeScreen) {
    final textTheme = Theme.of(context).textTheme;

    // Definimos los widgets de las gráficas
    final barChart = CustomContainer(
      title: 'Horas (Plan/Consumo) por Prioridad',
      child: _isLoading
          ? const SizedBox(
              height: 250,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              height: 250,
              width: double.infinity,
              child: CustomBarChart(
                labels: const ['Urgente', 'Alta', 'Media', 'Baja', 'Menor'],
                values: _consumedByPriority,
                colors: [
                  ColorTheme.error,
                  ColorTheme.atention,
                  const Color(0xFFFDD835),
                  ColorTheme.success,
                  Colors.grey,
                ],
              ),
            ),
    );

    final donutChart = CustomContainer(
      title: 'Volumen por Categoría',
      child: _isLoading
          ? const SizedBox(
              height: 250,
              child: Center(child: CircularProgressIndicator()),
            )
          : _typeValues.isEmpty
          ? const SizedBox(
              height: 250,
              child: Center(child: Text("No hay datos")),
            )
          : Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 250,
                    child: CustomDonutChart(
                      values: _typeValues,
                      colors: _typeColors,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(_typeLabels.length, (index) {
                        return _buildLegendItem(
                          _typeColors[index],
                          '${_typeLabels[index]} (${_typeValues[index].toInt()})',
                          textTheme,
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
    );

    final lineChart = CustomContainer(
      title: 'Tendencia (Recibidos vs Resueltos)',
      child: _isLoading
          ? const SizedBox(
              height: 250,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              children: [
                SizedBox(
                  height: 230,
                  width: double.infinity,
                  child: CustomLineChart(
                    labels: _lineLabels,
                    data: _lineData,
                    colors: const [Color(0xFF4F47E5), Color(0xFF10B981)],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSimpleLegendItem(
                      const Color(0xFF4F47E5),
                      'Recibidos',
                    ),
                    const SizedBox(width: 24),
                    _buildSimpleLegendItem(
                      const Color(0xFF10B981),
                      'Resueltos',
                    ),
                  ],
                ),
              ],
            ),
    );

    if (!isLargeScreen) {
      return Column(
        children: [
          barChart,
          const SizedBox(height: 16),
          donutChart,
          const SizedBox(height: 16),
          lineChart,
        ],
      );
    }

    // Mosaico 2x2 para pantallas grandes
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        // Fila 1: Barras y Donas (50% ancho cada una aprox)
        FractionallySizedBox(widthFactor: 0.48, child: barChart),
        FractionallySizedBox(widthFactor: 0.48, child: donutChart),
        // Fila 2: Líneas (Ancho completo o 50% si se prefiere, aquí full para ver detalle)
        SizedBox(width: double.infinity, child: lineChart),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  String _getMonthNameShort(int month) {
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return months[(month - 1) % 12];
  }
}
