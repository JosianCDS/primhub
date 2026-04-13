import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

class BreadcrumbNavigator extends StatelessWidget {
  final List<String> currentPath;
  final Function(int index) onNavigate;
  final Function(Map data)? onDropToRoot;

  const BreadcrumbNavigator({super.key, required this.currentPath, required this.onNavigate, this.onDropToRoot});

  IconData _getIconForCrumb(int index, String name) {
    if (index == 0) return Icons.layers_outlined; // Mis Proyectos
    if (index == 1) return Icons.work_outline; // Nombre del Proyecto
    if (index == 2) {
      // Tipos de vista
      if (name == 'Entregables') return Icons.folder_special;
      if (name == 'Seguimiento') return Icons.topic;
      return Icons.snippet_folder; // General
    }
    return Icons.folder_open; // Subcarpetas
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> crumbs = [];
    for (int i = 0; i < currentPath.length; i++) {
      final isLast = i == currentPath.length - 1;
      final color = isLast ? Theme.of(context).textTheme.bodyLarge?.color : Theme.of(context).colorScheme.primary;

      Widget crumb = InkWell(
        onTap: isLast ? null : () => onNavigate(i),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getIconForCrumb(i, currentPath[i]), size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                currentPath[i].split('.').first,
                style: TextStyle(color: color, fontWeight: isLast ? FontWeight.bold : FontWeight.normal),
              ),
            ],
          ),
        ),
      );

      // El nivel 2 es "Entregables", "Seguimiento", etc (La Raíz real de los archivos). Convertirlo en zona de Drop.
      if (!isLast && i <= 2 && onDropToRoot != null) {
        crumb = DropRegion(
          formats: Formats.standardFormats,
          onDropOver: (event) {
            if (event.session.items.isEmpty) return DropOperation.none;
            final item = event.session.items.first;
            if (item.localData != null && item.localData is Map && (item.localData as Map)['type'] == 'file') {
              return DropOperation.copy; // Compatible con Linux y Desktop
            }
            return DropOperation.none;
          },
          onPerformDrop: (event) async {
            final item = event.session.items.first;
            if (item.localData is Map) onDropToRoot!(item.localData as Map);
          },
          child: crumb,
        );
      }

      crumbs.add(crumb);
      if (!isLast) {
        crumbs.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Icon(Icons.chevron_right, color: Colors.grey, size: 16),
          ),
        );
      }
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: crumbs),
    );
  }
}
