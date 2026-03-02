import 'package:flutter/material.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/pages/Projects/Documents/projects_logic.dart';
import 'package:primhub/ui/pages/Projects/Projects_Widgets/requests_data_table.dart';
import 'package:primhub/ui/pages/Projects/dialogs/item_edit_dialog.dart';
import 'package:primhub/ui/pages/Support/Requests/create_request_dialog.dart';

class TaskItem extends StatefulWidget {
  final Map<String, dynamic> task;
  final bool initiallyExpanded;
  final Map<String, int> statusIdMap;
  final Map<String, String> priorityMap;
  final VoidCallback onRefresh;
  final Function(String type, int id, String name, String desc) onEdit;

  const TaskItem({super.key, required this.task, required this.initiallyExpanded, required this.statusIdMap, required this.priorityMap, required this.onRefresh, required this.onEdit});

  @override
  State<TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends State<TaskItem> {
  final ProjectsLogic _logic = ProjectsLogic();

  @override
  Widget build(BuildContext context) {
    final taskId = widget.task['id'];
    final taskName = widget.task['Name'] ?? 'Tarea sin nombre';
    final rawUU = widget.task['UUID'] ?? widget.task['uuid'] ?? widget.task['Record_UU'] ?? widget.task['uid'];
    String? taskUU;
    if (rawUU is String) taskUU = rawUU;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _logic.fetchRequestsForTask(taskUU),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? [];
        final countText = snapshot.connectionState == ConnectionState.waiting ? '...' : '${requests.length}';

        return ExpansionTile(
          key: Key('task-'),
          initiallyExpanded: widget.initiallyExpanded,
          leading: const Icon(Icons.task_alt_outlined, size: 20),
          title: Row(
            children: [
              Expanded(
                child: Text(taskName, style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
              if (requests.isNotEmpty) ...[const Icon(Icons.description_outlined, size: 16, color: Colors.grey), const SizedBox(width: 4), Text(countText, style: const TextStyle(fontSize: 13, color: Colors.grey))],
            ],
          ),
          subtitle: widget.task['Description'] != null ? Text(widget.task['Description'], maxLines: 2, overflow: TextOverflow.ellipsis) : null,
          trailing: (AccessControl.canCreateRequests || AccessControl.canEditProject)
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (AccessControl.canCreateRequests)
                      IconButton(
                        icon: const Icon(Icons.add_comment_outlined, size: 20),
                        tooltip: 'Crear Solicitud',
                        onPressed: () async {
                          final result = await showDialog(
                            context: context,
                            builder: (context) => CreateRequestDialog(linkedRecordUU: taskUU),
                          );
                          if (result == true) {
                            widget.onRefresh();
                          }
                        },
                      ),
                    if (AccessControl.canEditProject)
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => ItemEditDialog(type: 'task', currentName: taskName, currentDesc: widget.task['Description'] ?? '', onSave: (name, desc) => widget.onEdit('task', taskId, name, desc)),
                          );
                        },
                      ),
                  ],
                )
              : null,
          children: [
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (requests.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: RequestsDataTable(
                  requests: requests,
                  statusIdMap: widget.statusIdMap,
                  priorityMap: widget.priorityMap,
                  onRefresh: () {
                    setState(() {}); // Refresh local future builder
                    widget.onRefresh(); // Refresh parent if needed
                  },
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No hay solicitudes relacionadas.', style: TextStyle(color: Colors.grey)),
              ),
          ],
        );
      },
    );
  }
}
