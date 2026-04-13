import 'package:flutter/material.dart';
import 'charts.dart';
import 'dart:math';

class CustomBarChart extends StatefulWidget {
  final List<String> labels;
  final List<String>? fullLabels;
  final List<double> values;
  final List<Color> colors;
  final double maxWidth;
  final String leftAxisSuffix;
  final String tooltipSuffix;
  final Function(String label)? onBarTapped;

  const CustomBarChart({super.key, required this.labels, required this.values, required this.colors, this.maxWidth = 1000.0, this.fullLabels, this.leftAxisSuffix = '', this.tooltipSuffix = '', this.onBarTapped});

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
    return GestureDetector(
      onTapUp: (details) {
        if (widget.onBarTapped != null) {
          final painter = BarChartPainter(labels: widget.labels, fullLabels: widget.fullLabels, values: widget.values, colors: widget.colors, textColor: Theme.of(context).colorScheme.onSurfaceVariant, animationValue: 1.0, leftAxisSuffix: widget.leftAxisSuffix, tooltipSuffix: widget.tooltipSuffix);
          final tappedLabel = painter.getLabelForTap(details.localPosition, context.size ?? Size.zero);
          if (tappedLabel != null) {
            widget.onBarTapped!(tappedLabel);
          }
        }
      },
      child: MouseRegion(
        onHover: (e) => setState(() => _touchPosition = e.localPosition),
        onExit: (e) => setState(() => _touchPosition = null),
        child: AnimatedBuilder(
          animation: _animation!,
          builder: (context, child) => CustomPaint(
            size: Size.infinite,
            painter: BarChartPainter(labels: widget.labels, fullLabels: widget.fullLabels, values: widget.values, colors: widget.colors, textColor: Theme.of(context).colorScheme.onSurfaceVariant, touchPosition: _touchPosition, animationValue: _animation!.value, leftAxisSuffix: widget.leftAxisSuffix, tooltipSuffix: widget.tooltipSuffix),
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
  final Function(String label)? onSliceTapped;

  const CustomDonutChart({super.key, required this.values, required this.colors, this.maxWidth = 300.0, this.labels, this.onSliceTapped});

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
    return GestureDetector(
      onTapUp: (details) {
        if (widget.onSliceTapped != null) {
          final painter = DonutChartPainter(values: widget.values, labels: widget.labels, colors: widget.colors, animationValue: 1.0);
          final tappedLabel = painter.getLabelForTap(details.localPosition, context.size ?? Size.zero);
          if (tappedLabel != null) {
            widget.onSliceTapped!(tappedLabel);
          }
        }
      },
      child: MouseRegion(
        onHover: (e) => setState(() => _touchPosition = e.localPosition),
        onExit: (e) => setState(() => _touchPosition = null),
        child: AnimatedBuilder(
          animation: _controller!,
          builder: (context, child) => CustomPaint(
            size: Size.infinite,
            painter: DonutChartPainter(values: widget.values, labels: widget.labels, colors: widget.colors, touchPosition: _touchPosition, animationValue: _controller!.value),
          ),
        ),
      ),
    );
  }
}

class CustomStackedBarChart extends StatefulWidget {
  final List<String> labels;
  final List<String>? fullLabels;
  final List<List<double>> seriesValues;
  final List<String> seriesNames;
  final List<Color> colors;
  final Function(String category, String series)? onBarTapped;

  const CustomStackedBarChart({super.key, required this.labels, this.fullLabels, required this.seriesValues, required this.seriesNames, required this.colors, this.onBarTapped});

  @override
  State<CustomStackedBarChart> createState() => _CustomStackedBarChartState();
}

class _CustomStackedBarChartState extends State<CustomStackedBarChart> with SingleTickerProviderStateMixin {
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
    return GestureDetector(
      onTapUp: (details) {
        if (widget.onBarTapped != null) {
          final painter = StackedBarChartPainter(labels: widget.labels, fullLabels: widget.fullLabels, seriesValues: widget.seriesValues, seriesNames: widget.seriesNames, colors: widget.colors, textColor: Theme.of(context).colorScheme.onSurfaceVariant, animationValue: 1.0);
          final tapDetails = painter.getTapDetails(details.localPosition, context.size ?? Size.zero);
          if (tapDetails != null) {
            widget.onBarTapped!(tapDetails.category, tapDetails.series);
          }
        }
      },
      child: MouseRegion(
        onHover: (e) => setState(() => _touchPosition = e.localPosition),
        onExit: (e) => setState(() => _touchPosition = null),
        child: AnimatedBuilder(
          animation: _animation!,
          builder: (context, child) => CustomPaint(
            size: Size.infinite,
            painter: StackedBarChartPainter(labels: widget.labels, fullLabels: widget.fullLabels, seriesValues: widget.seriesValues, seriesNames: widget.seriesNames, colors: widget.colors, textColor: Theme.of(context).colorScheme.onSurfaceVariant, touchPosition: _touchPosition, animationValue: _animation!.value),
          ),
        ),
      ),
    );
  }
}
