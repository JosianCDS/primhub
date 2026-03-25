import 'dart:math';
import 'package:flutter/material.dart';

class BarChartPainter extends CustomPainter {
  final List<String> labels;
  final List<String>? fullLabels;
  final List<double> values;
  final List<Color> colors;
  final Color textColor;
  final Offset? touchPosition;
  final double animationValue;
  final String leftAxisSuffix;
  final String tooltipSuffix;

  BarChartPainter({required this.labels, this.fullLabels, required this.values, required this.colors, required this.textColor, this.touchPosition, this.animationValue = 1.0, this.leftAxisSuffix = '', this.tooltipSuffix = ''});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final double leftMargin = 40;
    final double bottomMargin = 30;
    final double chartWidth = size.width - leftMargin;
    final double chartHeight = size.height - bottomMargin;

    // --- Lógica de Eje Y Dinámico ---
    double maxValue = values.isEmpty ? 10 : values.reduce(max);
    double maxY = leftAxisSuffix == '%' ? 100 : max(10.0, (maxValue / 5).ceil() * 5.0);

    for (int i = 0; i <= 5; i++) {
      double val = (maxY / 5) * i;
      double y = chartHeight - (val / maxY) * chartHeight;
      textPainter.text = TextSpan(
        text: '${val.toInt()}$leftAxisSuffix',
        style: TextStyle(color: textColor, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(leftMargin - textPainter.width - 5, y - textPainter.height / 2));
    }

    final double spacing = chartWidth / (labels.isEmpty ? 1 : labels.length);
    final double barWidth = spacing * 0.6;

    for (int i = 0; i < labels.length; i++) {
      double x = leftMargin + spacing * i + (spacing - barWidth) / 2;
      double barHeight = (values[i] / maxY) * chartHeight * animationValue;
      double y = chartHeight - barHeight;
      paint.color = colors[i % colors.length];
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barWidth, barHeight), const Radius.circular(4)), paint);

      // Dibujar etiqueta en el Eje X debajo de la barra
      if (animationValue == 1.0) {
        textPainter.text = TextSpan(
          text: labels[i],
          style: TextStyle(color: textColor, fontSize: 11),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x + (barWidth - textPainter.width) / 2, chartHeight + 8));
      }
    }

    // Dibujar Tooltip Flotante
    if (touchPosition != null && animationValue == 1.0) {
      for (int i = 0; i < labels.length; i++) {
        double x = leftMargin + spacing * i + (spacing - barWidth) / 2;
        double barHeight = (values[i] / maxY) * chartHeight;
        double y = chartHeight - barHeight;
        Rect barRect = Rect.fromLTWH(x, y, barWidth, barHeight);

        if (barRect.contains(touchPosition!)) {
          final label = fullLabels != null && fullLabels!.length > i ? fullLabels![i] : labels[i];
          _drawTooltip(canvas, size, touchPosition!, label, values[i]);
          break;
        }
      }
    }
  }

  void _drawTooltip(Canvas canvas, Size size, Offset pos, String label, double value) {
    final text = '$label\n${value.toInt()} $tooltipSuffix'.trim();
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    double tX = pos.dx - textPainter.width / 2;
    double tY = pos.dy - textPainter.height - 15;
    if (tX < 0) tX = 5;
    if (tX + textPainter.width + 10 > size.width) tX = size.width - textPainter.width - 10;
    if (tY < 0) tY = pos.dy + 15;

    final bgRect = Rect.fromLTWH(tX - 8, tY - 6, textPainter.width + 16, textPainter.height + 12);
    final paint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(6)), paint);
    textPainter.paint(canvas, Offset(tX, tY));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<String>? labels;
  final List<Color> colors;
  final Offset? touchPosition;
  final double animationValue;

  DonutChartPainter({required this.values, this.labels, required this.colors, this.touchPosition, this.animationValue = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2.2;
    double total = values.fold(0, (a, b) => a + b);
    if (total == 0) return;

    double startAngle = -pi / 2;
    for (int i = 0; i < values.length; i++) {
      final sweepAngle = (values[i] / total) * 2 * pi * animationValue;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = colors[i % colors.length];

      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, true, paint);

      if (animationValue == 1.0) {
        final percentage = (values[i] / total) * 100;
        if (percentage >= 5) {
          // Solo dibuja texto si el pedazo es mayor al 5%
          final double midAngle = startAngle + sweepAngle / 2;
          final double r = radius * 0.65;
          final double tx = center.dx + r * cos(midAngle);
          final double ty = center.dy + r * sin(midAngle);

          final textPainter = TextPainter(
            text: TextSpan(
              text: '${percentage.toStringAsFixed(1)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(canvas, Offset(tx - textPainter.width / 2, ty - textPainter.height / 2));
        }
      }
      startAngle += sweepAngle;
    }

    if (touchPosition != null && animationValue == 1.0) {
      final dx = touchPosition!.dx - center.dx;
      final dy = touchPosition!.dy - center.dy;
      final dist = sqrt(dx * dx + dy * dy);

      if (dist <= radius) {
        double touchAngle = atan2(dy, dx);
        touchAngle = touchAngle + pi / 2;
        if (touchAngle < 0) touchAngle += 2 * pi;

        double currentAngle = 0;
        for (int i = 0; i < values.length; i++) {
          final sweepAngle = (values[i] / total) * 2 * pi;
          if (touchAngle >= currentAngle && touchAngle < currentAngle + sweepAngle) {
            final pct = (values[i] / total) * 100;
            final label = labels != null && labels!.length > i ? labels![i] : 'Estado';
            _drawTooltip(canvas, size, touchPosition!, label, values[i], pct);
            break;
          }
          currentAngle += sweepAngle;
        }
      }
    }
  }

  void _drawTooltip(Canvas canvas, Size size, Offset pos, String label, double value, double pct) {
    final text = '$label\n${value.toInt()} sol. (${pct.toStringAsFixed(1)}%)';
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    double tX = pos.dx + 15;
    double tY = pos.dy + 15;
    if (tX + textPainter.width + 20 > size.width) tX = pos.dx - textPainter.width - 20;
    if (tY + textPainter.height + 16 > size.height) tY = pos.dy - textPainter.height - 20;

    final bgRect = Rect.fromLTWH(tX, tY, textPainter.width + 16, textPainter.height + 12);
    final paint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(6)), paint);
    textPainter.paint(canvas, Offset(tX + 8, tY + 6));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
