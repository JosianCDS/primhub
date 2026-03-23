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

  BarChartPainter({required this.labels, this.fullLabels, required this.values, required this.colors, required this.textColor, this.touchPosition, this.animationValue = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final double leftMargin = 40;
    final double bottomMargin = 30;
    final double chartWidth = size.width - leftMargin;
    final double chartHeight = size.height - bottomMargin;

    // --- Lógica de Eje Y Dinámico ---
    // Determina si el eje debe mostrar porcentajes o valores absolutos (horas).
    double maxValue = values.isEmpty ? 10 : values.reduce(max);
    // Si el valor máximo es <= 100, asumimos que es un porcentaje.
    bool isPercent = maxValue <= 100 && maxValue > 0;
    // El tope del eje Y se ajusta a 100 para porcentajes, o se redondea al siguiente múltiplo de 5 para horas.
    double maxY = isPercent ? 100 : max(10.0, (maxValue / 5).ceil() * 5.0);

    for (int i = 0; i <= 5; i++) {
      double val = (maxY / 5) * i;
      double y = chartHeight - (val / maxY) * chartHeight;
      textPainter.text = TextSpan(
        text: '${val.toInt()}${isPercent ? '%' : 'h'}',
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
    }
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
    final radius = min(size.width, size.height) / 2.5;
    double total = values.fold(0, (a, b) => a + b);
    if (total == 0) return;

    double startAngle = -pi / 2;
    for (int i = 0; i < values.length; i++) {
      final sweepAngle = (values[i] / total) * 2 * pi * animationValue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.4
        ..color = colors[i % colors.length];
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
