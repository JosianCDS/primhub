import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AnimatedCopyWidget extends StatefulWidget {
  final String textToCopy;
  final Widget? leadingText; // Opcional: texto a la izquierda que también será clickeable
  final double iconSize;
  final Color iconColor;
  final EdgeInsetsGeometry padding;
  final String snackBarMessage; // Opcional, si queremos mostrar snackbar (por defecto no, ya que la animación sirve de feedback)

  const AnimatedCopyWidget({
    super.key,
    required this.textToCopy,
    this.leadingText,
    this.iconSize = 14,
    this.iconColor = Colors.grey,
    this.padding = const EdgeInsets.all(4.0),
    this.snackBarMessage = '',
  });

  @override
  State<AnimatedCopyWidget> createState() => _AnimatedCopyWidgetState();
}

class _AnimatedCopyWidgetState extends State<AnimatedCopyWidget> with SingleTickerProviderStateMixin {
  bool _isCopied = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleCopy() async {
    if (_isCopied) return;

    await Clipboard.setData(ClipboardData(text: widget.textToCopy));
    if (!mounted) return;

    if (widget.snackBarMessage.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.snackBarMessage), duration: const Duration(seconds: 1)),
      );
    }

    setState(() {
      _isCopied = true;
    });

    await _controller.forward();
    await _controller.reverse();

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isCopied = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = Padding(
      padding: widget.padding,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Icon(
            _isCopied ? Icons.check : Icons.copy,
            key: ValueKey<bool>(_isCopied),
            size: widget.iconSize,
            color: _isCopied ? Colors.green : widget.iconColor,
          ),
        ),
      ),
    );

    if (widget.leadingText != null) {
      return InkWell(
        onTap: _handleCopy,
        borderRadius: BorderRadius.circular(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.leadingText!,
            const SizedBox(width: 4),
            icon,
          ],
        ),
      );
    }

    return InkWell(
      onTap: _handleCopy,
      borderRadius: BorderRadius.circular(20),
      child: icon,
    );
  }
}
