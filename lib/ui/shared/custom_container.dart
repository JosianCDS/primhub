import 'package:flutter/material.dart';

class CustomContainer extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? action;
  final double width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final double elevation;
  final Color? backgroundColor;

  const CustomContainer({super.key, required this.child, this.title, this.action, this.width = double.infinity, this.height, this.padding = const EdgeInsets.all(20), this.elevation = 4, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: elevation,
      color: backgroundColor,
      child: Container(
        width: width,
        height: height,
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null || action != null) ...[
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (title != null) Text(title!, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    if (action != null) action!,
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (height != null) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }
}
