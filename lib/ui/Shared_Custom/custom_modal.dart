import 'package:flutter/material.dart';

class CustomModal extends StatelessWidget {
  final String? title;
  final Widget? content;
  final List<Widget>? actions;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;

  const CustomModal({super.key, this.title, this.content, this.actions, this.width, this.height, this.padding = const EdgeInsets.all(24.0)});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      elevation: 8,
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      child: Container(
        width: width ?? 400,
        height: height,
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[Text(title!, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 20)],
            if (content != null) Flexible(child: SingleChildScrollView(child: content!)),
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: Wrap(alignment: WrapAlignment.end, spacing: 10.0, runSpacing: 10.0, children: actions!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
