import 'package:flutter/material.dart';
import 'package:primhub/ui/Shared_Custom/cardcustom.dart';

class DottedCreateCard extends StatelessWidget {
  final VoidCallback onTap;
  final String title;
  final double height;

  const DottedCreateCard({super.key, required this.onTap, required this.title, this.height = 250});

  @override
  Widget build(BuildContext context) {
    return CardCustom(
      hover: true, // to match hover animation if desired, or false
      height: height,
      elevation: 0,
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: _DottedBorderPainter(color: Theme.of(context).colorScheme.primary),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  final Color color;
  _DottedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(16),
    );

    Path path = Path()..addRRect(rrect);
    Path dashPath = _dashPath(path, dashArray: [8.0, 6.0]);
    canvas.drawPath(dashPath, paint);
  }

  Path _dashPath(Path source, {required List<double> dashArray}) {
    Path dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      int dashIndex = 0;
      while (distance < metric.length) {
        final double len = dashArray[dashIndex];
        if (draw) {
          dest.addPath(metric.extractPath(distance, distance + len), Offset.zero);
        }
        distance += len;
        draw = !draw;
        dashIndex = (dashIndex + 1) % dashArray.length;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
