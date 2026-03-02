import 'package:flutter/material.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/pages/Projects/Projects_Widgets/phase_item.dart';
import 'package:primhub/ui/pages/Projects/Projects_Widgets/task_item.dart';
import 'package:primhub/ui/pages/Projects/dialogs/item_edit_dialog.dart';
import 'package:primhub/ui/pages/Projects/dialogs/phase_create_dialog.dart';

class ProjectItem extends StatelessWidget {
  final Map<String, dynamic> project;
  final bool isExpanded;
  final Map<String, int> statusIdMap;
  final Map<String, String> priorityMap;
  final VoidCallback onRefresh;
  final Function(String type, int id, String name, String desc) onEdit;
  final Function(int projectId, String name, String desc) onCreatePhase;
  final Function(int phaseId, String name, String desc) onCreateTask;
  final Function(Map<String, dynamic> project, String viewType) onShowFiles;

  const ProjectItem({super.key, required this.project, required this.isExpanded, required this.statusIdMap, required this.priorityMap, required this.onRefresh, required this.onEdit, required this.onCreatePhase, required this.onCreateTask, required this.onShowFiles});

  @override
  Widget build(BuildContext context) {
    final phases = project['C_ProjectPhase'] as List? ?? [];
    final directTasks = project['C_ProjectTask'] as List? ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        key: Key('project-${project['id']}'),
        initiallyExpanded: isExpanded,
        leading: const Icon(Icons.folder, color: Color(0xFF4F47E5)),
        title: Row(
          children: [
            Expanded(
              child: Text(project['Name'] ?? 'Sin Nombre', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            if (phases.isNotEmpty) ...[const Icon(Icons.layers_outlined, size: 16, color: Colors.grey), const SizedBox(width: 4), Text('${phases.length}', style: const TextStyle(fontSize: 14, color: Colors.grey)), const SizedBox(width: 8)],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (project['Description'] != null) Text(project['Description'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildActionButton(Icons.folder_open, 'Entregables', Colors.orange, () => onShowFiles(project, 'Entregables')),
                const SizedBox(width: 16),
                _buildActionButton(Icons.assignment, 'Seguimiento', Colors.blue, () => onShowFiles(project, 'Seguimiento')),
                const SizedBox(width: 16),
                _buildActionButton(Icons.assignment_add, 'General', Colors.grey, () => onShowFiles(project, 'General')),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (AccessControl.canCreateProjectItems)
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva Fase'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => PhaseCreateDialog(onSave: (name, desc) => onCreatePhase(project['id'], name, desc)),
                      );
                    },
                  ),
                if (AccessControl.canEditProject)
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    tooltip: 'Editar Proyecto',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => ItemEditDialog(type: 'project', currentName: project['Name'], currentDesc: project['Description'] ?? '', onSave: (name, desc) => onEdit('project', project['id'], name, desc)),
                      );
                    },
                  ),
              ],
            ),
          ),
          const Divider(),
          if (phases.isEmpty && directTasks.isEmpty) const Padding(padding: EdgeInsets.all(16.0), child: Text('No hay fases ni tareas registradas.')),
          ...phases.map((phase) => PhaseItem(phase: phase, initiallyExpanded: isExpanded, statusIdMap: statusIdMap, priorityMap: priorityMap, onRefresh: onRefresh, onEdit: onEdit, onCreateTask: onCreateTask)),
          ...directTasks.map((task) => TaskItem(task: task, initiallyExpanded: isExpanded, statusIdMap: statusIdMap, priorityMap: priorityMap, onRefresh: onRefresh, onEdit: onEdit)),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }
}
