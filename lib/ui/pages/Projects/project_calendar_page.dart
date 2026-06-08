import 'package:flutter/material.dart';
import 'package:primhub/ui/pages/Projects/dialogs/project_calendar_dialog.dart';

class ProjectCalendarPage extends StatelessWidget {
  final Map<String, dynamic> project;

  const ProjectCalendarPage({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(project['Name'] ?? 'Calendario de Proyecto'),
      ),
      body: SafeArea(
        child: ProjectCalendarDialog(project: project),
      ),
    );
  }
}
