import 'package:flutter/material.dart';
import '../widgets/charts.dart';
import 'dart:math';

class CustomBarChart extends StatefulWidget {
  final List<String> labels;
  final List<String>? fullLabels;
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
    return MouseRegion(
      onHover: (e) => setState(() => _touchPosition = e.localPosition),
      onExit: (e) => setState(() => _touchPosition = null),
      child: AnimatedBuilder(
        animation: _animation!,
        builder: (context, child) => CustomPaint(
          painter: BarChartPainter(labels: widget.labels, fullLabels: widget.fullLabels, values: widget.values, colors: widget.colors, textColor: Theme.of(context).colorScheme.onSurfaceVariant, touchPosition: _touchPosition, animationValue: _animation!.value),
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

  const CustomDonutChart({super.key, required this.values, required this.colors, this.maxWidth = 300.0, this.labels});

  @override
  State<CustomDonutChart> createState() => _CustomDonutChartState();
}

class _CustomDonutChartState extends State<CustomDonutChart> with SingleTickerProviderStateMixin {
  Offset? _touchPosition;
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (e) => setState(() => _touchPosition = e.localPosition),
      onExit: (e) => setState(() => _touchPosition = null),
      child: AnimatedBuilder(
        animation: _controller!,
        builder: (context, child) => CustomPaint(
          painter: DonutChartPainter(values: widget.values, labels: widget.labels, colors: widget.colors, touchPosition: _touchPosition, animationValue: _controller!.value),
        ),
      ),
    );
  }
}
