import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/pages/Projects/dialogs/item_edit_dialog.dart';
import 'package:primhub/ui/pages/Projects/dialogs/phase_create_dialog.dart';
import 'package:primhub/ui/pages/Projects/dialogs/project_calendar_dialog.dart';
import 'package:primhub/ui/pages/Projects/dialogs/project_info_dialog.dart';
import 'package:primhub/ui/pages/Projects/Projects_Widgets/phase_item.dart';
import 'package:primhub/ui/pages/Projects/Projects_Widgets/task_item.dart';

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
  final VoidCallback? onToggleExpansion; // Nueva callback
  final bool isArchived;
  final Map<String, dynamic>? stats;

  const ProjectItem({
    super.key,
    required this.project,
    required this.isExpanded,
    required this.statusIdMap,
    required this.priorityMap,
    required this.onRefresh,
    required this.onEdit,
    required this.onCreatePhase,
    required this.onCreateTask,
    required this.onShowFiles,
    this.onToggleExpansion,
    this.isArchived = false,
    this.stats,
  });

  @override
  Widget build(BuildContext context) {
    // ... (sorting logic stays same)
    final phases = (project['C_ProjectPhase'] as List? ?? []).map((e) {
      if (e is Map) return Map<String, dynamic>.from(e);
      return <String, dynamic>{};
    }).toList();
    phases.sort((a, b) {
      final idA = a['id'] is int ? a['id'] : int.tryParse(a['id']?.toString() ?? '0') ?? 0;
      final idB = b['id'] is int ? b['id'] : int.tryParse(b['id']?.toString() ?? '0') ?? 0;
      return idA.compareTo(idB);
    });

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
      margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: Color(0xFF4F47E5), width: 6),
          ),
        ),
        child: ExpansionTile(
          key: Key('project-$projId-$isExpanded'), // Forzamos reconstrucción al cambiar estado
          initiallyExpanded: isExpanded,
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white,
          iconColor: const Color(0xFF4F47E5),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.indigo[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.folder, color: Color(0xFF4F47E5), size: 24),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  project['Name'] ?? 'Sin Nombre',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              if (onToggleExpansion != null)
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.unfold_less : Icons.unfold_more,
                    size: 20,
                    color: const Color(0xFF4F47E5),
                  ),
                  tooltip: isExpanded ? 'Contraer' : 'Expandir por completo',
                  onPressed: onToggleExpansion,
                ),
              if (phases.isNotEmpty) ...[
                const Icon(Icons.layers_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('${phases.length}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(width: 8)
              ],
              if (AccessControl.canEditProject)
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: Colors.blueGrey),
                  tooltip: isArchived ? 'Reactivar Proyecto' : 'Editar Proyecto',
                  onPressed: () {
                    onEdit('project', projId, project['Name'] ?? '', project['Description'] ?? '');
                  },
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (project['Description'] != null)
                Text(
                  project['Description'],
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildActionButton(Icons.folder_open, 'Entregables', Colors.orange, () => onShowFiles(project, 'Entregables')),
                    const SizedBox(width: 8),
                    _buildActionButton(Icons.assignment, 'Seguimiento', Colors.blue, () => onShowFiles(project, 'Seguimiento')),
                    const SizedBox(width: 8),
                    _buildActionButton(Icons.assignment_add, 'General', Colors.grey, () => onShowFiles(project, 'General')),
                    const SizedBox(width: 8),
                    if (AccessControl.isAdmin)
                      _buildActionButton(Icons.calendar_today, 'Calendario', Colors.purple, () {
                        showDialog(
                          context: context,
                          builder: (context) => ProjectCalendarDialog(project: project),
                        );
                      }),
                    const SizedBox(width: 8),
                    if (AccessControl.isAdmin)
                      _buildActionButton(Icons.list_alt, 'Solicitudes', Colors.indigo, () {
                        context.push('/project-requests', extra: {'projectId': projId, 'showAllGroups': true});
                      }),
                    const SizedBox(width: 8),
                    if (AccessControl.isAdmin)
                      _buildActionButton(Icons.info_outline, 'Información', Colors.teal, () {
                        showDialog(
                          context: context,
                          builder: (context) => ProjectInfoDialog(project: project),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
          children: [
            Container(
              color: Colors.grey[50]?.withOpacity(0.5),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Estructura del Proyecto',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        Row(
                          children: [
                            if (AccessControl.canCreateProjectItems && !isArchived)
                              TextButton.icon(
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Nueva Fase', style: TextStyle(fontSize: 13)),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => PhaseCreateDialog(onSave: (name, desc) => onCreatePhase(projId, name, desc)),
                                  );
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (phases.isEmpty && directTasks.isEmpty)
                    const Padding(padding: EdgeInsets.all(24.0), child: Text('No hay fases ni tareas registradas.', style: TextStyle(color: Colors.grey))),
                  const SizedBox(height: 8),
                  ...phases.map((phase) => PhaseItem(phase: phase, initiallyExpanded: isExpanded, statusIdMap: statusIdMap, priorityMap: priorityMap, onRefresh: onRefresh, onEdit: onEdit, onCreateTask: onCreateTask, isArchived: isArchived, projectId: projId)),
                  ...directTasks.map((task) => TaskItem(task: task, initiallyExpanded: isExpanded, statusIdMap: statusIdMap, priorityMap: priorityMap, onRefresh: onRefresh, onEdit: onEdit, isArchived: isArchived, projectId: projId)),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      hoverColor: color.withOpacity(0.1), // Sombreado sutil al pasar el mouse
      splashColor: color.withOpacity(0.2),
      highlightColor: color.withOpacity(0.05),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          // Se puede añadir un borde sutil si se desea más definición
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
