import 'package:flutter/material.dart';
import '../widgets/charts.dart';
import 'dart:math';

class CustomAreaChart extends StatelessWidget {
  final List<List<double>> data;
  final List<Color> colors;
  final List<String> labels;
  final double maxWidth;

  const CustomAreaChart({super.key, required this.data, required this.colors, required this.labels, this.maxWidth = 1000.0});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double chartWidth = constraints.maxWidth < 600 ? 600 : constraints.maxWidth;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: chartWidth,
                height: constraints.maxHeight,
                child: CustomPaint(
                  painter: AreaChartPainter(data: data, colors: colors, labels: labels),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class CustomLineChart extends StatefulWidget {
  final List<List<double>> data;
  final List<Color> colors;
  final List<String> labels;
  final double maxWidth;

  const CustomLineChart({super.key, required this.data, required this.colors, required this.labels, this.maxWidth = 1000.0});

  @override
  State<CustomLineChart> createState() => _CustomLineChartState();
}

class _CustomLineChartState extends State<CustomLineChart> {
  Offset? _touchPosition;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double chartWidth = constraints.maxWidth < 600 ? 600 : constraints.maxWidth;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: MouseRegion(
                onHover: (event) => setState(() => _touchPosition = event.localPosition),
                onExit: (event) => setState(() => _touchPosition = null),
                child: GestureDetector(
                  onPanUpdate: (details) => setState(() => _touchPosition = details.localPosition),
                  onPanEnd: (_) => setState(() => _touchPosition = null),
                  onTapUp: (details) => setState(() => _touchPosition = details.localPosition),
                  onTapDown: (details) => setState(() => _touchPosition = details.localPosition),
                  child: SizedBox(
                    width: chartWidth,
                    height: constraints.maxHeight,
                    child: CustomPaint(
                      painter: LineChartPainter(data: widget.data, colors: widget.colors, labels: widget.labels, touchPosition: _touchPosition),
                    ),
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

class CustomBarChart extends StatefulWidget {
  final List<String> labels;
  final List<String>? fullLabels; // Etiquetas completas para el Tooltip
  final List<double> values;
  final List<Color> colors;
  final double maxWidth;

  const CustomBarChart({super.key, required this.labels, required this.values, required this.colors, this.maxWidth = 1000.0, this.fullLabels});

  @override
  State<CustomBarChart> createState() => _CustomBarChartState();
}

class _CustomBarChartState extends State<CustomBarChart> with SingleTickerProviderStateMixin {
  Offset? _touchPosition;
  AnimationController? _controller;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _animation = CurvedAnimation(parent: _controller!, curve: Curves.easeOutQuart);
    _controller!.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) _initController();
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        child: MouseRegion(
          onHover: (event) => setState(() => _touchPosition = event.localPosition),
          onExit: (event) => setState(() => _touchPosition = null),
          child: GestureDetector(
            onPanUpdate: (details) => setState(() => _touchPosition = details.localPosition),
            onPanEnd: (_) => setState(() => _touchPosition = null),
            onTapUp: (details) => setState(() => _touchPosition = details.localPosition),
            onTapDown: (details) => setState(() => _touchPosition = details.localPosition),
            child: SizedBox.expand(
              child: AnimatedBuilder(
                animation: _animation!,
                builder: (context, child) {
                  return CustomPaint(
                    painter: BarChartPainter(
                      labels: widget.labels,
                      fullLabels: widget.fullLabels, // Se envía al Painter
                      values: widget.values,
                      colors: widget.colors,
                      axisColor: Theme.of(context).colorScheme.onSurface,
                      gridColor: Theme.of(context).colorScheme.outlineVariant,
                      textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                      touchPosition: _touchPosition,
                      animationValue: _animation!.value,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CustomDonutChart extends StatefulWidget {
  final List<double> values;
  final List<String>? labels;
  final List<Color> colors;
  final double maxWidth;
  final Function(int index)? onDoubleTap;

  const CustomDonutChart({super.key, required this.values, required this.colors, this.maxWidth = 300.0, this.labels, this.onDoubleTap});

  @override
  State<CustomDonutChart> createState() => _CustomDonutChartState();
}

class _CustomDonutChartState extends State<CustomDonutChart> with SingleTickerProviderStateMixin {
  Offset? _touchPosition;
  AnimationController? _controller;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _animation = CurvedAnimation(parent: _controller!, curve: Curves.easeOutCirc);
    _controller!.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) _initController();
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        child: MouseRegion(
          onHover: (event) => setState(() => _touchPosition = event.localPosition),
          onExit: (event) => setState(() => _touchPosition = null),
          child: GestureDetector(
            onTapUp: (details) => setState(() => _touchPosition = details.localPosition),
            onPanEnd: (_) => setState(() => _touchPosition = null),
            onDoubleTapDown: (details) {
              if (widget.onDoubleTap != null) {
                // Necesitamos calcular el índice aquí o pasarlo desde el painter.
                // Para simplificar, usaremos la misma lógica de detección que el painter o delegaremos.
                // Como el painter no devuelve eventos, recalculamos el índice tocado.
                _handleDoubleTap(details.localPosition, context.size ?? Size.zero);
              }
            },
            child: SizedBox.expand(
              child: AnimatedBuilder(
                animation: _animation!,
                builder: (context, child) {
                  return CustomPaint(
                    painter: DonutChartPainter(values: widget.values, labels: widget.labels, colors: widget.colors, touchPosition: _touchPosition, animationValue: _animation!.value),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleDoubleTap(Offset position, Size size) {
    if (size.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final strokeWidth = radius * 0.4;

    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    final distance = sqrt(dx * dx + dy * dy);

    if (distance >= radius - strokeWidth - 15 && distance <= radius + 15) {
      double angle = atan2(dy, dx);
      angle -= (-pi / 2);
      if (angle < 0) angle += 2 * pi;

      double total = widget.values.fold(0, (a, b) => a + b);
      double currentSweep = 0.0;
      for (int j = 0; j < widget.values.length; j++) {
        final sweep = (widget.values[j] / total) * 2 * pi;
        if (angle >= currentSweep && angle < currentSweep + sweep) {
          widget.onDoubleTap!(j);
          break;
        }
        currentSweep += sweep;
      }
    }
  }
}
