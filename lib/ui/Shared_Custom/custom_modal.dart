import 'package:flutter/material.dart';

class CustomModal extends StatelessWidget {
  final String? title;
  final Widget? content;
  final List<Widget>? actions;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final bool scrollable;

  const CustomModal({super.key, this.title, this.content, this.actions, this.width, this.height, this.padding = const EdgeInsets.all(24.0), this.scrollable = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      elevation: 8,
      backgroundColor: Colors.transparent, // El fondo lo maneja el Container con decoración
      child: Container(
        width: width ?? 400,
        height: height,
        decoration: BoxDecoration(
          color: theme.dialogBackgroundColor,
          borderRadius: BorderRadius.circular(12.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Título fijo arriba
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text(title!, style: theme.textTheme.titleLarge),
              ),
            
            // Contenido (Scrollable o no)
            if (content != null)
              Flexible(
                child: scrollable
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: content!,
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: content!,
                      ),
              ),

            // Acciones fijas abajo
            if (actions != null && actions!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10.0,
                  runSpacing: 10.0,
                  children: actions!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
