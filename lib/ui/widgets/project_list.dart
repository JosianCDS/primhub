import 'package:flutter/material.dart';
import 'package:primhub/ui/pages/request/request_functions.dart';
import 'package:primhub/ui/shared/custom_inputs.dart';

class ProjectListView extends StatefulWidget {
  final List<dynamic> projects;
  final bool isLoading;
  final String? errorMessage;
  final int? targetExpandedProjectId;
  final Function(Map<String, dynamic> project, String viewType) onShowFiles;
  final Function(String type, int id, String currentName, String currentDesc)
  onEditItem;
  final Function(int projectId) onAddPhase;
  final Function(int phaseId) onAddTask;
  final Function(
    String type,
    int id,
    bool currentStatus,
    Map<String, dynamic>? parent,
  )
  onToggleComplete;

  const ProjectListView({
    super.key,
    required this.projects,
    required this.isLoading,
    this.errorMessage,
    this.targetExpandedProjectId,
    required this.onShowFiles,
    required this.onEditItem,
    required this.onAddPhase,
    required this.onAddTask,
    required this.onToggleComplete,
  });

  @override
  State<ProjectListView> createState() => _ProjectListViewState();
}

class _ProjectListViewState extends State<ProjectListView> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _requests = [];
  bool _expandAll = false;
  int _expansionKey = 0;

  @override
  void initState() {
    super.initState();
    _fetchRequestsData();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRequestsData() async {
    try {
      final reqs = await fetchRequest();
      if (mounted) setState(() => _requests = reqs);
    } catch (e) {
      debugPrint('Error fetching requests for projects: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading)
      return const Center(child: CircularProgressIndicator());
    if (widget.errorMessage != null)
      return Center(
        child: Text(
          widget.errorMessage!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    if (widget.projects.isEmpty)
      return const Center(child: Text('No tienes proyectos activos.'));

    final filteredProjects = widget.projects.where((project) {
      final name = (project['Name'] ?? '').toString().toLowerCase();
      final search = _searchController.text.toLowerCase();
      return name.contains(search);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: CustomTextField(
            controller: _searchController,
            hintText: 'Buscar proyecto...',
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filteredProjects.length,
            itemBuilder: (context, index) => ProjectCard(
              project: filteredProjects[index],
              requests: _requests,
              expansionKey: _expansionKey,
              initiallyExpanded:
                  _expandAll ||
                  (filteredProjects[index]['id'] ==
                      widget.targetExpandedProjectId),
              onShowFiles: widget.onShowFiles,
              onEditItem: widget.onEditItem,
              onAddPhase: widget.onAddPhase,
              onAddTask: widget.onAddTask,
              onToggleComplete: widget.onToggleComplete,
            ),
          ),
        ),
      ],
    );
  }
}

class ProjectCard extends StatelessWidget {
  final Map<String, dynamic> project;
  final List<Map<String, dynamic>> requests;
  final int expansionKey;
  final bool initiallyExpanded;
  final Function(Map<String, dynamic> project, String viewType) onShowFiles;
  final Function(String type, int id, String currentName, String currentDesc)
  onEditItem;
  final Function(int projectId) onAddPhase;
  final Function(int phaseId) onAddTask;
  final Function(
    String type,
    int id,
    bool currentStatus,
    Map<String, dynamic>? parent,
  )
  onToggleComplete;

  const ProjectCard({
    super.key,
    required this.project,
    required this.requests,
    required this.expansionKey,
    required this.initiallyExpanded,
    required this.onShowFiles,
    required this.onEditItem,
    required this.onAddPhase,
    required this.onAddTask,
    required this.onToggleComplete,
  });

  @override
  Widget build(BuildContext context) {
    final phases = project['C_ProjectPhase'] as List? ?? [];
    final directTasks = project['C_ProjectTask'] as List? ?? [];
    final String name = project['Name'] ?? 'Proyecto sin nombre';
    final String description = project['Description'] ?? '';
    final bool isComplete = project['IsComplete'] == true;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        key: Key('${project['id']}-$expansionKey'),
        initiallyExpanded: initiallyExpanded,
        leading: GestureDetector(
          onTap: () =>
              onToggleComplete('project', project['id'], isComplete, null),
          child: CircleAvatar(
            backgroundColor: isComplete
                ? Colors.green
                : Theme.of(context).colorScheme.primary,
            child: Icon(
              isComplete ? Icons.check : Icons.assignment,
              color: Colors.white,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.folder, size: 20),
              onPressed: () => onShowFiles(project, 'Entregables'),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () =>
                  onEditItem('project', project['id'], name, description),
            ),
          ],
        ),
        children: [
          ...phases.map(
            (phase) => PhaseItem(
              phase: phase,
              requests: requests,
              onEditItem: onEditItem,
              onAddTask: onAddTask,
              onToggleComplete: onToggleComplete, // CORREGIDO
            ),
          ),
          ...directTasks.map(
            (task) => TaskItem(
              task: task,
              phase: null,
              requests: requests,
              onEditItem: onEditItem,
              onToggleComplete: onToggleComplete, // CORREGIDO
            ),
          ),
        ],
      ),
    );
  }
}

class PhaseItem extends StatelessWidget {
  final Map<String, dynamic> phase;
  final List<Map<String, dynamic>> requests;
  final Function(String type, int id, String currentName, String currentDesc)
  onEditItem;
  final Function(int phaseId) onAddTask;
  final Function(
    String type,
    int id,
    bool currentStatus,
    Map<String, dynamic>? parent,
  )
  onToggleComplete;

  const PhaseItem({
    super.key,
    required this.phase,
    required this.requests,
    required this.onEditItem,
    required this.onAddTask,
    required this.onToggleComplete, // CORREGIDO
  });

  @override
  Widget build(BuildContext context) {
    final tasks = phase['C_ProjectTask'] as List? ?? [];
    final bool isComplete = phase['IsComplete'] == true;

    return ExpansionTile(
      leading: IconButton(
        icon: Icon(
          isComplete ? Icons.check_circle : Icons.flag,
          color: isComplete ? Colors.green : Colors.grey,
        ),
        onPressed: () =>
            onToggleComplete('phase', phase['id'], isComplete, null),
      ),
      title: Text(phase['Name'] ?? 'Fase'),
      children: tasks
          .map(
            (task) => TaskItem(
              task: task,
              phase: phase,
              requests: requests,
              onEditItem: onEditItem,
              onToggleComplete: onToggleComplete, // CORREGIDO
              isNested: true,
            ),
          )
          .toList(),
    );
  }
}

class TaskItem extends StatelessWidget {
  final Map<String, dynamic> task;
  final Map<String, dynamic>? phase;
  final List<Map<String, dynamic>> requests;
  final Function(String type, int id, String currentName, String currentDesc)
  onEditItem;
  final Function(
    String type,
    int id,
    bool currentStatus,
    Map<String, dynamic>? parent,
  )
  onToggleComplete;
  final bool isNested;

  const TaskItem({
    super.key,
    required this.task,
    this.phase,
    required this.requests,
    required this.onEditItem,
    required this.onToggleComplete, // CORREGIDO
    this.isNested = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isComplete = task['IsComplete'] == true;
    return ListTile(
      leading: IconButton(
        icon: Icon(
          isComplete ? Icons.check_circle : Icons.circle_outlined,
          color: isComplete ? Colors.green : Colors.blueGrey,
        ),
        onPressed: () =>
            onToggleComplete('task', task['id'], isComplete, phase),
      ),
      title: Text(task['Name'] ?? 'Tarea'),
      trailing: IconButton(
        icon: const Icon(Icons.edit, size: 16),
        onPressed: () => onEditItem(
          'task',
          task['id'],
          task['Name'] ?? '',
          task['Description'] ?? '',
        ),
      ),
    );
  }
}
