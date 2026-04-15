import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/pages/Projects/Projects_Widgets/phase_item.dart';
import 'package:primhub/ui/pages/Projects/Projects_Widgets/task_item.dart';
import 'package:primhub/ui/pages/Projects/dialogs/item_edit_dialog.dart';
import 'package:primhub/ui/pages/Projects/dialogs/phase_create_dialog.dart';
import 'package:primhub/ui/pages/Projects/dialogs/project_calendar_dialog.dart';
import 'package:primhub/ui/pages/Projects/dialogs/project_info_dialog.dart';

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
  final bool isArchived;
  final Map<String, dynamic>? stats; // Nuevo parámetro para indicadores

  const ProjectItem({super.key, required this.project, required this.isExpanded, required this.statusIdMap, required this.priorityMap, required this.onRefresh, required this.onEdit, required this.onCreatePhase, required this.onCreateTask, required this.onShowFiles, this.isArchived = false, this.stats});

  @override
  Widget build(BuildContext context) {
    // Ordenar Fases por ID Ascendente (Las nuevas van al fondo)
    final phases = (project['C_ProjectPhase'] as List? ?? []).map((e) {
      if (e is Map) return Map<String, dynamic>.from(e);
      return <String, dynamic>{};
    }).toList();
    phases.sort((a, b) {
      final idA = a['id'] is int ? a['id'] : int.tryParse(a['id']?.toString() ?? '0') ?? 0;
      final idB = b['id'] is int ? b['id'] : int.tryParse(b['id']?.toString() ?? '0') ?? 0;
      return idA.compareTo(idB);
    });

    // Ordenar Tareas Directas por ID Ascendente
    final directTasks = (project['C_ProjectTask'] as List? ?? []).map((e) {
      if (e is Map) return Map<String, dynamic>.from(e);
      return <String, dynamic>{};
    }).toList();
    directTasks.sort((a, b) {
      final idA = a['id'] is int ? a['id'] : int.tryParse(a['id']?.toString() ?? '0') ?? 0;
      final idB = b['id'] is int ? b['id'] : int.tryParse(b['id']?.toString() ?? '0') ?? 0;
      return idA.compareTo(idB);
    });

    final int projId = project['id'] is int ? project['id'] as int : int.tryParse(project['id'].toString()) ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        key: Key('project-$projId'),
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
            Wrap(
              spacing: 16.0,
              runSpacing: 8.0,
              children: [
                _buildActionButton(Icons.folder_open, 'Entregables', Colors.orange, () => onShowFiles(project, 'Entregables') /*, hasPending: stats?['pendingEt'] ?? false*/),
                _buildActionButton(Icons.assignment, 'Seguimiento', Colors.blue, () => onShowFiles(project, 'Seguimiento') /*, hasPending: stats?['pendingSg'] ?? false*/),
                _buildActionButton(Icons.assignment_add, 'General', Colors.grey, () => onShowFiles(project, 'General') /*, hasPending: stats?['pendingGn'] ?? false*/),
                if (AccessControl.isAdmin)
                  _buildActionButton(Icons.calendar_today, 'Calendario', Colors.purple, () {
                    showDialog(
                      context: context,
                      builder: (context) => ProjectCalendarDialog(project: project),
                    );
                  }),
                if (AccessControl.isAdmin)
                  _buildActionButton(Icons.list_alt, 'Solicitudes', Colors.indigo, () {
                    context.push('/project-requests', extra: {'projectId': projId, 'showAllGroups': true});
                  }),
                if (AccessControl.isAdmin)
                  _buildActionButton(Icons.info_outline, 'Información', Colors.teal, () {
                    showDialog(
                      context: context,
                      builder: (context) => ProjectInfoDialog(project: project),
                    );
                  }),
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
                if (AccessControl.canCreateProjectItems && !isArchived)
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva Fase'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => PhaseCreateDialog(onSave: (name, desc) => onCreatePhase(projId, name, desc)),
                      );
                    },
                  ),
                if (AccessControl.canEditProject)
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    tooltip: isArchived ? 'Reactivar Proyecto' : 'Editar Proyecto',
                    onPressed: () {
                      onEdit('project', projId, project['Name'] ?? '', project['Description'] ?? '');
                    },
                  ),
              ],
            ),
          ),
          const Divider(),
          if (phases.isEmpty && directTasks.isEmpty) const Padding(padding: EdgeInsets.all(16.0), child: Text('No hay fases ni tareas registradas.')),
          ...phases.map((phase) => PhaseItem(phase: phase, initiallyExpanded: isExpanded, statusIdMap: statusIdMap, priorityMap: priorityMap, onRefresh: onRefresh, onEdit: onEdit, onCreateTask: onCreateTask, isArchived: isArchived, projectId: projId)),
          ...directTasks.map((task) => TaskItem(task: task, initiallyExpanded: isExpanded, statusIdMap: statusIdMap, priorityMap: priorityMap, onRefresh: onRefresh, onEdit: onEdit, isArchived: isArchived, projectId: projId)),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onPressed /*, {bool hasPending = false}*/) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        child: Column(
          children: [
            Stack(
              children: [
                Icon(icon, color: color, size: 24),
                // if (hasPending)
                //   Positioned(
                //     right: 0,
                //     top: 0,
                //     child: Container(
                //       width: 8,
                //       height: 8,
                //       decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                //     ),
                //   )
                // else
                //   Positioned(
                //     right: 0,
                //     top: 0,
                //     child: Container(
                //       width: 8,
                //       height: 8,
                //       decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                //     ),
                //   ),
              ],
            ),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }
}
