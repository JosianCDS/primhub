import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/api/access_control.dart';

class ProjectBottomNav extends StatelessWidget {
  final String currentRoute;

  const ProjectBottomNav({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    List<String> routes = ['/'];
    List<NavigationDestination> destinations = [const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Dashboard')];

    if (AccessControl.isSupport) {
      routes.add('/my-requests');
      destinations.add(const NavigationDestination(icon: Icon(Icons.help_outline), selectedIcon: Icon(Icons.help), label: 'Mis Solicitudes'));

      routes.add('/support');
      destinations.add(const NavigationDestination(icon: Icon(Icons.schedule_outlined), selectedIcon: Icon(Icons.schedule), label: 'Dashboard de Horas'));
    }

    if (AccessControl.isProject) {
      routes.add('/deliverables');
      destinations.add(const NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'Proyectos'));
    }

    routes.add('/metrics');
    destinations.add(const NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Métricas'));

    int selectedIndex = routes.indexOf(currentRoute);
    if (selectedIndex == -1) selectedIndex = 0;

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        if (index != selectedIndex) {
          context.go(routes[index]);
        }
      },
      destinations: destinations,
    );
  }
}
