import 'package:flutter/material.dart';
import '../widgets/charts.dart';

class CustomAreaChart extends StatelessWidget {
  final List<List<double>> data;
  final List<Color> colors;
  final List<String> labels;
  final double maxWidth;

  const CustomAreaChart({
    super.key,
    required this.data,
    required this.colors,
    required this.labels,
    this.maxWidth = 1000.0, // Límite de ancho por defecto
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Mantenemos la lógica de scroll horizontal para pantallas muy pequeñas
            final double chartWidth = constraints.maxWidth < 600
                ? 600
                : constraints.maxWidth;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: chartWidth,
                // Usamos la altura disponible del padre
                height: constraints.maxHeight,
                child: CustomPaint(
                  painter: AreaChartPainter(
                    data: data,
                    colors: colors,
                    labels: labels,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class CustomLineChart extends StatelessWidget {
  final List<List<double>> data;
  final List<Color> colors;
  final List<String> labels;
  final double maxWidth;

  const CustomLineChart({
    super.key,
    required this.data,
    required this.colors,
    required this.labels,
    this.maxWidth = 1000.0,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double chartWidth = constraints.maxWidth < 600
                ? 600
                : constraints.maxWidth;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: chartWidth,
                height: constraints.maxHeight,
                child: CustomPaint(
                  painter: LineChartPainter(
                    data: data,
                    colors: colors,
                    labels: labels,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class CustomBarChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final List<Color> colors;
  final double maxWidth;

  const CustomBarChart({
    super.key,
    required this.labels,
    required this.values,
    required this.colors,
    this.maxWidth = 1000.0,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox.expand(
          child: CustomPaint(
            painter: BarChartPainter(
              labels: labels,
              values: values,
              colors: colors,
              axisColor: Theme.of(context).colorScheme.onSurface,
              gridColor: Theme.of(context).colorScheme.outlineVariant,
              textColor: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class CustomDonutChart extends StatelessWidget {
  final List<double> values;
  final List<Color> colors;
  final double maxWidth;

  const CustomDonutChart({
    super.key,
    required this.values,
    required this.colors,
    this.maxWidth = 300.0,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox.expand(
          child: CustomPaint(
            painter: DonutChartPainter(values: values, colors: colors),
          ),
        ),
      ),
    );
  }
}
