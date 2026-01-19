import 'dart:math';
import 'package:flutter/material.dart';

class AreaChartPainter extends CustomPainter {
  final List<List<double>> data;
  final List<Color> colors;
  final List<String> labels;

  AreaChartPainter({
    required this.data,
    required this.colors,
    required this.labels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final axisPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final double padding = 30;
    final double chartWidth = size.width - padding * 2;
    final double chartHeight = size.height - padding * 2;
    final double bottomY = size.height - padding;

    // Draw Grid/Axis
    canvas.drawLine(
      Offset(padding, bottomY),
      Offset(size.width - padding, bottomY),
      axisPaint,
    );

    // Max value
    double maxValue = 0;
    for (var list in data) {
      for (var val in list) {
        if (val > maxValue) maxValue = val;
      }
    }
    if (maxValue == 0) maxValue = 1;
    maxValue *= 1.2; // padding top

    for (int i = 0; i < data.length; i++) {
      final dataset = data[i];
      final color = colors[i % colors.length];

      if (dataset.isEmpty) continue;

      final path = Path();
      final fillPath = Path();

      final double stepX = chartWidth / (dataset.length - 1);

      for (int j = 0; j < dataset.length; j++) {
        final x = padding + (j * stepX);
        final y = bottomY - ((dataset[j] / maxValue) * chartHeight);

        if (j == 0) {
          path.moveTo(x, y);
          fillPath.moveTo(x, bottomY);
          fillPath.lineTo(x, y);
        } else {
          path.lineTo(x, y);
          fillPath.lineTo(x, y);
        }
      }

      fillPath.lineTo(padding + ((dataset.length - 1) * stepX), bottomY);
      fillPath.close();

      // Draw Fill
      paint.style = PaintingStyle.fill;
      paint.color = color.withOpacity(0.2);
      canvas.drawPath(fillPath, paint);

      // Draw Line
      paint.style = PaintingStyle.stroke;
      paint.color = color;
      paint.strokeWidth = 3;
      canvas.drawPath(path, paint);
    }

    // Labels
    for (int i = 0; i < labels.length; i++) {
      final x = padding + (i * (chartWidth / (labels.length - 1)));
      textPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(color: Colors.black54, fontSize: 12),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, bottomY + 8));
    }
  }

  @override
  bool shouldRepaint(covariant AreaChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.colors != colors;
  }
}

class LineChartPainter extends CustomPainter {
  final List<List<double>> data;
  final List<Color> colors;
  final List<String> labels;

  LineChartPainter({
    required this.data,
    required this.colors,
    required this.labels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final axisPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final double padding = 30;
    final double chartWidth = size.width - padding * 2;
    final double chartHeight = size.height - padding * 2;
    final double bottomY = size.height - padding;

    // Draw Grid/Axis
    canvas.drawLine(
      Offset(padding, bottomY),
      Offset(size.width - padding, bottomY),
      axisPaint,
    );

    // Max value
    double maxValue = 0;
    for (var list in data) {
      for (var val in list) {
        if (val > maxValue) maxValue = val;
      }
    }
    if (maxValue == 0) maxValue = 1;
    maxValue *= 1.2;

    for (int i = 0; i < data.length; i++) {
      final dataset = data[i];
      final color = colors[i % colors.length];
      if (dataset.isEmpty) continue;

      final path = Path();
      final double stepX = chartWidth / (dataset.length - 1);

      for (int j = 0; j < dataset.length; j++) {
        final x = padding + (j * stepX);
        final y = bottomY - ((dataset[j] / maxValue) * chartHeight);
        if (j == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      // Draw Line Only
      paint.style = PaintingStyle.stroke;
      paint.color = color;
      paint.strokeWidth = 3;
      canvas.drawPath(path, paint);
    }

    // Labels
    for (int i = 0; i < labels.length; i++) {
      final x = padding + (i * (chartWidth / (labels.length - 1)));
      textPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(color: Colors.black54, fontSize: 12),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, bottomY + 8));
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.colors != colors;
}

class BarChartPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;
  final List<Color> colors;
  final Color axisColor;
  final Color gridColor;
  final Color textColor;

  BarChartPainter({
    required this.labels,
    required this.values,
    required this.colors,
    this.axisColor = Colors.black,
    this.gridColor = Colors.grey,
    this.textColor = Colors.black,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final double bottomMargin = 30;
    final double leftMargin = 30;
    final double chartWidth = size.width - leftMargin;
    final double chartHeight = size.height - bottomMargin;

    canvas.drawLine(
      Offset(leftMargin, 0),
      Offset(leftMargin, chartHeight),
      axisPaint,
    );
    canvas.drawLine(
      Offset(leftMargin, chartHeight),
      Offset(size.width, chartHeight),
      axisPaint,
    );

    double maxValue = values.reduce(max);
    if (maxValue == 0) maxValue = 10;
    double maxY =
        (maxValue / 5).ceil() * 5.0 + 5; // Round up to nearest 5 + padding

    for (int i = 0; i <= 5; i++) {
      double val = (maxY / 5) * i;
      double y = chartHeight - (val / maxY) * chartHeight;
      if (i > 0)
        canvas.drawLine(
          Offset(leftMargin, y),
          Offset(size.width, y),
          gridPaint,
        );
      textPainter.text = TextSpan(
        text: val.toInt().toString(),
        style: TextStyle(color: textColor, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(leftMargin - textPainter.width - 5, y - textPainter.height / 2),
      );
    }

    final double barWidth = (chartWidth / labels.length) * 0.5;
    final double spacing = chartWidth / labels.length;

    for (int i = 0; i < labels.length; i++) {
      double x = leftMargin + spacing * i + (spacing - barWidth) / 2;
      double barHeight = (values[i] / maxY) * chartHeight;
      double y = chartHeight - barHeight;

      paint.color = colors[i % colors.length];
      canvas.drawRect(Rect.fromLTWH(x, y, barWidth, barHeight), paint);

      textPainter.text = TextSpan(
        text: labels[i],
        style: TextStyle(color: textColor, fontSize: 11),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + barWidth / 2 - textPainter.width / 2, chartHeight + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant BarChartPainter oldDelegate) =>
      oldDelegate.values != values;
}

class DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  DonutChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final strokeWidth = radius * 0.4;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    double total = values.fold(0, (a, b) => a + b);
    double startAngle = -pi / 2;

    for (int i = 0; i < values.length; i++) {
      final sweepAngle = (values[i] / total) * 2 * pi;
      paint.color = colors[i % colors.length];
      canvas.drawArc(rect, startAngle + 0.02, sweepAngle - 0.04, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) =>
      oldDelegate.values != values;
}
