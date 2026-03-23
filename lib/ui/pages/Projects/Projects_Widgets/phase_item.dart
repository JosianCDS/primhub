import 'package:flutter/material.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/pages/Projects/Projects_Widgets/task_item.dart';
import 'package:primhub/ui/pages/Projects/dialogs/item_edit_dialog.dart';
import 'package:primhub/ui/pages/Projects/dialogs/task_create_dialog.dart';

class PhaseItem extends StatelessWidget {
  final Map<String, dynamic> phase;
  final bool initiallyExpanded;
  final Map<String, int> statusIdMap;
  final Map<String, String> priorityMap;
  final VoidCallback onRefresh;
  final Function(String type, int id, String name, String desc) onEdit;
  final Function(int phaseId, String name, String desc) onCreateTask;
  final bool isArchived;
  final int projectId;

  const PhaseItem({super.key, required this.phase, required this.initiallyExpanded, required this.statusIdMap, required this.priorityMap, required this.onRefresh, required this.onEdit, required this.onCreateTask, this.isArchived = false, required this.projectId});

  @override
  Widget build(BuildContext context) {
    final tasks = phase['C_ProjectTask'] as List? ?? [];
    return ExpansionTile(
      key: Key('phase-${phase['id']}'),
      initiallyExpanded: initiallyExpanded,
      title: Row(
        children: [
          Expanded(
            child: Text(phase['Name'] ?? 'Fase', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (tasks.isNotEmpty) ...[const Icon(Icons.task_outlined, size: 16, color: Colors.grey), const SizedBox(width: 4), Text('${tasks.length}', style: const TextStyle(color: Colors.grey))],
        ],
      ),
      subtitle: Text(phase['Description'] ?? '', style: const TextStyle(fontSize: 12)),
      leading: const Icon(Icons.flag_outlined),
      trailing: AccessControl.canEditProject && !isArchived
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_task, size: 20),
                  tooltip: 'Nueva Tarea',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => TaskCreateDialog(onSave: (name, desc) => onCreateTask(phase['id'], name, desc)),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => ItemEditDialog(type: 'phase', currentName: phase['Name'], currentDesc: phase['Description'] ?? '', onSave: (name, desc) => onEdit('phase', phase['id'], name, desc)),
                    );
                  },
                ),
              ],
            )
          : null,
      children: tasks.map((task) => TaskItem(task: task, phase: phase, initiallyExpanded: initiallyExpanded, statusIdMap: statusIdMap, priorityMap: priorityMap, onRefresh: onRefresh, onEdit: onEdit, isArchived: isArchived, projectId: projectId)).toList(),
    );
  }
}
