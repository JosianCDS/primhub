import 'package:flutter/material.dart';
import 'package:primhub/ui/shared/custom_chart.dart';
import 'package:primhub/ui/shared/custom_container.dart';
import '../../theme/colors.dart';
import '../widgets/custom_drawer.dart';

class MetricsPage extends StatelessWidget {
  const MetricsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Indicadores de Negocio (BI)')),
      drawer: const CustomDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // Gráfica de Barras
            CustomContainer(
              title: 'Tiempo de Resolución por Prioridad',
              child: SizedBox(
                height: 300,
                width: double.infinity,
                child: CustomBarChart(
                  labels: const ['Urgente', 'Alta', 'Media', 'Baja'],
                  values: const [8, 15, 12, 28],
                  colors: [
                    ColorTheme.error,
                    ColorTheme.atention,
                    const Color(0xFFFDD835),
                    ColorTheme.success,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Gráfica de Anillo
            CustomContainer(
              title: 'Volumen de Solicitudes por Categoría',
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 250,
                      child: CustomDonutChart(
                        values: const [25, 30, 20, 25],
                        colors: [
                          ColorTheme.error,
                          ColorTheme.info,
                          ColorTheme.atention,
                          const Color(0xFFBA68C8),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLegendItem(
                          ColorTheme.error,
                          'Reporte de Bug',
                          textTheme,
                        ),
                        _buildLegendItem(
                          ColorTheme.info,
                          'Consulta General',
                          textTheme,
                        ),
                        _buildLegendItem(
                          ColorTheme.atention,
                          'Solicitud de Cambio',
                          textTheme,
                        ),
                        _buildLegendItem(
                          const Color(0xFFBA68C8),
                          'Facturación',
                          textTheme,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Gráfica de Líneas (Tendencia)
            CustomContainer(
              title: 'Tendencia de Tickets (Semestral)',
              child: Column(
                children: [
                  SizedBox(
                    height: 300,
                    width: double.infinity,
                    child: CustomLineChart(
                      labels: const ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun'],
                      data: const [
                        [15, 22, 18, 40, 35, 55], // Tickets Recibidos
                        [12, 18, 15, 35, 30, 50], // Tickets Resueltos
                      ],
                      colors: const [
                        Color(0xFF4F47E5), // Indigo
                        Color(0xFF10B981), // Emerald
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
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
            ),
          ],
        ),
      ),
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
}
