import 'package:flutter/material.dart';

class CustomContainer extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? action;
  final double? width; // Cambiado a opcional para mejor flexibilidad
  final double? height;
  final EdgeInsetsGeometry padding;
  final double elevation;
  final Color? backgroundColor;

  const CustomContainer({super.key, required this.child, this.title, this.action, this.width, this.height, this.padding = const EdgeInsets.all(20), this.elevation = 4, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    // Usamos el esquema de colores del tema para coherencia visual
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: elevation,
      clipBehavior: Clip.antiAlias, // Asegura que el contenido no se salga de los bordes
      color: backgroundColor ?? colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // Bordes un poco más modernos
      ),
      child: Container(
        width: width ?? double.infinity,
        height: height,
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // Si hay una altura fija, permitimos que la columna se expanda
          mainAxisSize: height != null ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (title != null || action != null) ...[
              Row(
                // Row es más eficiente que Wrap para encabezados simples
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        style: TextStyle(
                          fontSize: 18, // 24 era demasiado grande para secciones de formulario
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary, // Color acorde al tema
                        ),
                      ),
                    ),
                  ?action,
                ],
              ),
              const Divider(height: 32), // Una línea divisoria suave queda mejor que solo espacio
            ],
            // Corrección del error de Expanded
            if (height != null) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }
}
