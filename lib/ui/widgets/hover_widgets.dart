import 'package:flutter/material.dart';

class HoverScaleCard extends StatefulWidget {
  final Widget child;
  const HoverScaleCard({super.key, required this.child});

  @override
  State<HoverScaleCard> createState() => _HoverScaleCardState();
}

class _HoverScaleCardState extends State<HoverScaleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(scale: _isHovered ? 1.05 : 1.0, duration: const Duration(milliseconds: 200), curve: Curves.easeInOut, child: widget.child),
    );
  }
}

class HoverListTile extends StatefulWidget {
  final Widget Function(bool isHovered) builder;

  const HoverListTile({super.key, required this.builder});

  @override
  State<HoverListTile> createState() => _HoverListTileState();
}

class _HoverListTileState extends State<HoverListTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(duration: const Duration(milliseconds: 200), color: _isHovered ? Colors.blue.withOpacity(0.1) : Colors.transparent, child: widget.builder(_isHovered)),
    );
  }
}
