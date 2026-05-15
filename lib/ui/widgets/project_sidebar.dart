import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/api_utils.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';

class ProjectSideBar extends StatelessWidget {
  final String currentRoute;

  const ProjectSideBar({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    List<Map<String, dynamic>> items = [
      {'route': '/', 'icon': Icons.dashboard_outlined, 'selectedIcon': Icons.dashboard, 'label': 'Dashboard'},
    ];

    if (AccessControl.isSupport) {
      items.add({'route': '/my-requests', 'icon': Icons.help_outline, 'selectedIcon': Icons.help, 'label': 'Mis Solicitudes'});
      items.add({'route': '/support', 'icon': Icons.schedule_outlined, 'selectedIcon': Icons.schedule, 'label': 'Horas'});
    }

    if (AccessControl.isProject) {
      items.add({'route': '/deliverables', 'icon': Icons.folder_outlined, 'selectedIcon': Icons.folder, 'label': 'Proyectos'});
    }

    items.add({'route': '/metrics', 'icon': Icons.bar_chart_outlined, 'selectedIcon': Icons.bar_chart, 'label': 'Métricas'});

    int selectedIndex = items.indexWhere((item) => item['route'] == currentRoute);
    if (selectedIndex == -1) selectedIndex = 0;

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          right: BorderSide(color: colorScheme.outline.withOpacity(0.1)),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Logo o Título opcional aquí
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = selectedIndex == index;

                return InkWell(
                  onTap: () {
                    if (!isSelected) context.go(item['route']);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? colorScheme.primary.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? item['selectedIcon'] : item['icon'],
                          color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          item['label'],
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
