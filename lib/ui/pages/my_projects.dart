import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';
import '../widgets/custom_drawer.dart';

class MyProjectsPage extends StatefulWidget {
  const MyProjectsPage({super.key});

  @override
  State<MyProjectsPage> createState() => _MyProjectsPageState();
}

class _MyProjectsPageState extends State<MyProjectsPage> {
  List<dynamic> _projects = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    if (User.cBPartnerID == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No se pudo identificar el socio de negocio.';
        });
      }
      return;
    }

    String baseUrl =
        '${Endpoint.project}?\$filter=C_BPartner_ID eq ${User.cBPartnerID}';
    // Intento inicial con expansión completa
    String url =
        '$baseUrl&\$expand=C_ProjectPhase(\$expand=C_ProjectTask),C_ProjectTask';

    try {
      var response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
      );

      // Fallback si falla la expansión de tareas directas (Error 500 específico)
      if (response.statusCode == 500 &&
          response.body.contains('C_ProjectTask')) {
        url = '$baseUrl&\$expand=C_ProjectPhase(\$expand=C_ProjectTask)';
        response = await http.get(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': Token.token,
          },
        );
      }

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _projects = data['records'];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Error al cargar proyectos: ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error de conexión. Verifique su internet.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Proyectos')),
      drawer: const CustomDrawer(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }
    if (_projects.isEmpty) {
      return const Center(child: Text('No tienes proyectos activos.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _projects.length,
      itemBuilder: (context, index) {
        return _buildProjectCard(_projects[index]);
      },
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    final phases = project['C_ProjectPhase'] as List? ?? [];
    final directTasks = project['C_ProjectTask'] as List? ?? [];
    final String name = project['Name'] ?? 'Proyecto sin nombre';
    final String description = project['Description'] ?? '';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.assignment, color: Colors.white),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: description.isNotEmpty
            ? Text(description, maxLines: 2, overflow: TextOverflow.ellipsis)
            : null,
        children: [
          if (phases.isNotEmpty)
            ...phases.map((phase) => _buildPhaseItem(phase)),
          if (directTasks.isNotEmpty)
            ...directTasks.map((task) => _buildTaskItem(task)),
          if (phases.isEmpty && directTasks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'No hay detalles de fases o tareas disponibles.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPhaseItem(Map<String, dynamic> phase) {
    final tasks = phase['C_ProjectTask'] as List? ?? [];
    final bool isComplete = phase['IsComplete'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: Card(
        elevation: 0,
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        child: ExpansionTile(
          leading: Icon(
            isComplete ? Icons.check_circle : Icons.flag,
            color: isComplete ? Colors.green : Colors.orange,
          ),
          title: Text(
            phase['Name'] ?? 'Fase',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text('${tasks.length} Tareas'),
          children: tasks
              .map((task) => _buildTaskItem(task, isNested: true))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task, {bool isNested = false}) {
    return ListTile(
      contentPadding: EdgeInsets.only(
        left: isNested ? 16.0 : 16.0,
        right: 16.0,
      ),
      leading: const Icon(Icons.task_alt, size: 18, color: Colors.blueGrey),
      title: Text(
        task['Name'] ?? 'Tarea',
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: task['Description'] != null
          ? Text(
              task['Description'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            )
          : null,
      dense: true,
    );
  }
}
