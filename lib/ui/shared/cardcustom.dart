import 'package:flutter/material.dart';

class CardCustom extends StatefulWidget {
  const CardCustom({super.key, required this.child, this.height = 350, this.width = 280, this.elevation = 4, this.color, this.hover = false});
  final Widget child;
  final double? height;
  final double? width;
  final double elevation;
  final Color? color;
  final bool hover;

  @override
  State<CardCustom> createState() => _CardCustomState();
}

class _CardCustomState extends State<CardCustom> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: MouseRegion(
        onEnter: widget.hover ? (_) => setState(() => _isHovered = true) : null,
        onExit: widget.hover ? (_) => setState(() => _isHovered = false) : null,
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: Card(elevation: widget.elevation, color: widget.color, child: widget.child),
        ),
      ),
    );
  }
}
