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

class CustomLineChart extends StatefulWidget {
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
            final double chartWidth = constraints.maxWidth < 600
                ? 600
                : constraints.maxWidth;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: GestureDetector(
                onPanUpdate: (details) =>
                    setState(() => _touchPosition = details.localPosition),
                onPanEnd: (_) => setState(() => _touchPosition = null),
                onTapUp: (details) =>
                    setState(() => _touchPosition = details.localPosition),
                onTapDown: (details) =>
                    setState(() => _touchPosition = details.localPosition),
                child: SizedBox(
                  width: chartWidth,
                  height: constraints.maxHeight,
                  child: CustomPaint(
                    painter: LineChartPainter(
                      data: widget.data,
                      colors: widget.colors,
                      labels: widget.labels,
                      touchPosition: _touchPosition,
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
  State<CustomBarChart> createState() => _CustomBarChartState();
}

class _CustomBarChartState extends State<CustomBarChart>
    with SingleTickerProviderStateMixin {
  Offset? _touchPosition;
  AnimationController? _controller;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(
      parent: _controller!,
      curve: Curves.easeOutQuart,
    );
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
        child: GestureDetector(
          onPanUpdate: (details) =>
              setState(() => _touchPosition = details.localPosition),
          onPanEnd: (_) => setState(() => _touchPosition = null),
          onTapUp: (details) =>
              setState(() => _touchPosition = details.localPosition),
          onTapDown: (details) =>
              setState(() => _touchPosition = details.localPosition),
          child: SizedBox.expand(
            child: AnimatedBuilder(
              animation: _animation!,
              builder: (context, child) {
                return CustomPaint(
                  painter: BarChartPainter(
                    labels: widget.labels,
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
    );
  }
}

class CustomDonutChart extends StatefulWidget {
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
  State<CustomDonutChart> createState() => _CustomDonutChartState();
}

class _CustomDonutChartState extends State<CustomDonutChart>
    with SingleTickerProviderStateMixin {
  Offset? _touchPosition;
  AnimationController? _controller;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = CurvedAnimation(
      parent: _controller!,
      curve: Curves.easeOutCirc,
    );
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
        child: GestureDetector(
          onTapUp: (details) =>
              setState(() => _touchPosition = details.localPosition),
          onPanEnd: (_) => setState(() => _touchPosition = null),
          child: SizedBox.expand(
            child: AnimatedBuilder(
              animation: _animation!,
              builder: (context, child) {
                return CustomPaint(
                  painter: DonutChartPainter(
                    values: widget.values,
                    colors: widget.colors,
                    touchPosition: _touchPosition,
                    animationValue: _animation!.value,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
