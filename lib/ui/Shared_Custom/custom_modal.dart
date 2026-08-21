import 'package:flutter/material.dart';

class CustomModal extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget? content;
  final List<Widget>? actions;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final bool scrollable;

  const CustomModal({super.key, this.title, this.titleWidget, this.content, this.actions, this.width, this.height, this.padding = const EdgeInsets.all(24.0), this.scrollable = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      elevation: 8,
      insetAnimationDuration: Duration.zero, // Elimina la animación costosa de layout al abrir el teclado
      backgroundColor: Colors.transparent, // El fondo lo maneja el Container con decoración
      child: Material(
        type: MaterialType.card,
        color: theme.dialogBackgroundColor,
        borderRadius: BorderRadius.circular(12.0),
        clipBehavior: Clip.hardEdge, // hardEdge es mucho más eficiente que antiAlias durante redibujados
        child: Container(
          width: width ?? 400,
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width - 32,
          ),
          height: height,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Título fijo arriba
            if (titleWidget != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: titleWidget!,
              )
            else if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text(title!, style: theme.textTheme.titleLarge),
              ),
            
            // Contenido (Scrollable o no)
            if (content != null)
              Flexible(
                child: scrollable
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.only(left: 24, right: 24, top: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            content!,
                            if (isMobile && actions != null && actions!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 16.0, bottom: 24.0),
                                child: Wrap(
                                  alignment: WrapAlignment.end,
                                  spacing: 10.0,
                                  runSpacing: 10.0,
                                  children: actions!,
                                ),
                              ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(left: 24, right: 24, top: 16),
                        child: content!,
                      ),
              ),

            // Acciones fijas abajo (en Escritorio o si no es scrollable)
            if ((!isMobile || !scrollable) && actions != null && actions!.isNotEmpty)
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
    ));
  }
}
