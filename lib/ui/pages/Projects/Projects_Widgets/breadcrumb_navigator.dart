import 'package:flutter/material.dart';

class BreadcrumbNavigator extends StatelessWidget {
  final List<String> currentPath;
  final Function(int index) onNavigate;

  const BreadcrumbNavigator({super.key, required this.currentPath, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    List<Widget> crumbs = [];
    for (int i = 0; i < currentPath.length; i++) {
      final isLast = i == currentPath.length - 1;
      crumbs.add(
        InkWell(
          onTap: isLast ? null : () => onNavigate(i),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            child: Text(
              currentPath[i].split('.').first,
              style: TextStyle(color: isLast ? Theme.of(context).textTheme.bodyLarge?.color : Theme.of(context).colorScheme.primary, fontWeight: isLast ? FontWeight.bold : FontWeight.normal),
            ),
          ),
        ),
      );
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
