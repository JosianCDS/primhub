import 'dart:math';
import 'package:flutter/material.dart';
import 'duration_formatter.dart';

class AreaChartPainter extends CustomPainter {
  final List<List<double>> data;
  final List<Color> colors;
  final List<String> labels;

  AreaChartPainter({required this.data, required this.colors, required this.labels});

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
    canvas.drawLine(Offset(padding, bottomY), Offset(size.width - padding, bottomY), axisPaint);

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
  final Offset? touchPosition;

  LineChartPainter({required this.data, required this.colors, required this.labels, this.touchPosition});

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
    canvas.drawLine(Offset(padding, bottomY), Offset(size.width - padding, bottomY), axisPaint);

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

    // Tooltip Interactivo
    if (touchPosition != null && data.isNotEmpty && data[0].isNotEmpty) {
      final double stepX = chartWidth / (data[0].length - 1);
      // Encontrar el índice más cercano al toque
      final int index = ((touchPosition!.dx - padding + stepX / 2) / stepX).clamp(0, data[0].length - 1).toInt();
      final double x = padding + (index * stepX);

      // Dibujar línea vertical indicadora
      paint.color = Colors.grey.withOpacity(0.5);
      paint.strokeWidth = 1;
      canvas.drawLine(Offset(x, padding), Offset(x, bottomY), paint);

      // Preparar texto del tooltip
      String tooltipText = labels[index];
      for (int i = 0; i < data.length; i++) {
        if (data[i].length > index) {
          tooltipText += '\n${data[i][index].toStringAsFixed(1)}';
        }
      }

      textPainter.text = TextSpan(
        text: tooltipText,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      );
      textPainter.layout();

      // Dibujar caja del tooltip
      final tooltipRect = Rect.fromLTWH(x - textPainter.width / 2 - 5, padding, textPainter.width + 10, textPainter.height + 10);

      paint.color = Colors.black87;
      paint.style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(tooltipRect, const Radius.circular(4)), paint);

      textPainter.paint(canvas, Offset(tooltipRect.left + 5, tooltipRect.top + 5));
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) => oldDelegate.data != data || oldDelegate.colors != colors || oldDelegate.touchPosition != touchPosition;
}

class BarChartPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;
  final List<Color> colors;
  final Color axisColor;
  final Color gridColor;
  final Color textColor;
  final Offset? touchPosition;
  final double animationValue;

  BarChartPainter({required this.labels, required this.values, required this.colors, this.axisColor = Colors.black, this.gridColor = Colors.grey, this.textColor = Colors.black, this.touchPosition, this.animationValue = 1.0});

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

    canvas.drawLine(Offset(leftMargin, 0), Offset(leftMargin, chartHeight), axisPaint);
    canvas.drawLine(Offset(leftMargin, chartHeight), Offset(size.width, chartHeight), axisPaint);

    double maxValue = values.reduce(max);
    if (maxValue == 0) maxValue = 10;
    double maxY = (maxValue / 5).ceil() * 5.0 + 5; // Round up to nearest 5 + padding

    for (int i = 0; i <= 5; i++) {
      double val = (maxY / 5) * i;
      double y = chartHeight - (val / maxY) * chartHeight;
      if (i > 0) canvas.drawLine(Offset(leftMargin, y), Offset(size.width, y), gridPaint);
      textPainter.text = TextSpan(
        // Usamos un formato simple para el eje
        text: '${val.toInt()}h',
        style: TextStyle(color: textColor, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(leftMargin - textPainter.width - 5, y - textPainter.height / 2));
    }

    final double barWidth = (chartWidth / labels.length) * 0.5;
    final double spacing = chartWidth / labels.length;

    for (int i = 0; i < labels.length; i++) {
      double x = leftMargin + spacing * i + (spacing - barWidth) / 2;
      double barHeight = (values[i] / maxY) * chartHeight * animationValue;
      double y = chartHeight - barHeight;

      paint.color = colors[i % colors.length];
      canvas.drawRect(Rect.fromLTWH(x, y, barWidth, barHeight), paint);

      textPainter.text = TextSpan(
        text: labels[i],
        style: TextStyle(color: textColor, fontSize: 11),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + barWidth / 2 - textPainter.width / 2, chartHeight + 8));

      // Tooltip Interactivo
      if (touchPosition != null) {
        // Verificar si el toque está dentro del área horizontal de la barra
        if (touchPosition!.dx >= x - 5 && touchPosition!.dx <= x + barWidth + 5) {
          final tooltipText = '${labels[i]}: ${DurationFormatter.format(values[i])}';
          textPainter.text = TextSpan(
            text: tooltipText,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          );
          textPainter.layout();

          final tooltipRect = Rect.fromLTWH(
            x + barWidth / 2 - textPainter.width / 2 - 5,
            y - textPainter.height - 15, // Arriba de la barra
            textPainter.width + 10,
            textPainter.height + 10,
          );

          paint.color = Colors.black87;
          canvas.drawRRect(RRect.fromRectAndRadius(tooltipRect, const Radius.circular(4)), paint);
          textPainter.paint(canvas, Offset(tooltipRect.left + 5, tooltipRect.top + 5));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant BarChartPainter oldDelegate) => oldDelegate.values != values || oldDelegate.touchPosition != touchPosition || oldDelegate.animationValue != animationValue;
}

class DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final Offset? touchPosition;
  final double animationValue;

  DonutChartPainter({required this.values, required this.colors, this.touchPosition, this.animationValue = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final strokeWidth = radius * 0.4;
    final paint = Paint()..style = PaintingStyle.stroke;

    double total = values.fold(0, (a, b) => a + b);
    if (total <= 0) return; // Evitar división por cero
    double startAngle = -pi / 2;

    // Identificar índice tocado
    int touchedIndex = -1;
    if (touchPosition != null) {
      final dx = touchPosition!.dx - center.dx;
      final dy = touchPosition!.dy - center.dy;
      final distance = sqrt(dx * dx + dy * dy);

      // Verificar si el toque está en el anillo (con margen de tolerancia)
      if (distance >= radius - strokeWidth - 10 && distance <= radius + 10) {
        double angle = atan2(dy, dx);
        angle -= (-pi / 2); // Ajustar al ángulo de inicio
        if (angle < 0) angle += 2 * pi;

        double currentSweep = 0.0;
        for (int j = 0; j < values.length; j++) {
          final sweep = (values[j] / total) * 2 * pi;
          if (angle >= currentSweep && angle < currentSweep + sweep) {
            touchedIndex = j;
            break;
          }
          currentSweep += sweep;
        }
      }
    }

    // Dibujar segmentos
    for (int i = 0; i < values.length; i++) {
      // Animación de barrido
      final sweepAngle = (values[i] / total) * 2 * pi * animationValue;

      // Lógica de resaltado (Zoom)
      final isTouched = i == touchedIndex;
      final currentStrokeWidth = isTouched ? strokeWidth * 1.15 : strokeWidth;
      final currentRadius = isTouched ? radius * 1.05 : radius;

      final rect = Rect.fromCircle(center: center, radius: currentRadius - currentStrokeWidth / 2);

      paint.color = colors[i % colors.length];
      paint.strokeWidth = currentStrokeWidth;

      if (sweepAngle > 0) {
        canvas.drawArc(rect, startAngle + 0.02, sweepAngle - 0.04, false, paint);
      }
      startAngle += sweepAngle;
    }

    // Dibujar Tooltip en el centro si hay selección
    if (touchedIndex != -1) {
      final val = values[touchedIndex];
      final textPainter = TextPainter(textDirection: TextDirection.ltr);
      textPainter.text = TextSpan(
        text: '${val.toInt()}',
        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
      );
      textPainter.layout();

      final textOffset = Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2);
      final bgRect = Rect.fromLTWH(textOffset.dx - 8, textOffset.dy - 4, textPainter.width + 16, textPainter.height + 8);
      final bgPaint = Paint()..color = Colors.black87;
      canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(8)), bgPaint);

      textPainter.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) => oldDelegate.values != values || oldDelegate.touchPosition != touchPosition || oldDelegate.animationValue != animationValue;
}
