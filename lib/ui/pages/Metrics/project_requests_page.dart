import 'package:flutter/material.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';
import 'package:primhub/ui/Shared_Custom/custom_table.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/token.dart';

class ProjectRequestsPage extends StatefulWidget {
  final String? filterType;
  final String? filterStatus;
  final int? projectId;
  final List<String>? taskUUIDs; // UUIDs de tareas para filtro avanzado

  const ProjectRequestsPage({super.key, this.filterType, this.filterStatus, this.projectId, this.taskUUIDs});

  @override
  State<ProjectRequestsPage> createState() => _ProjectRequestsPageState();
}

class _ProjectRequestsPageState extends State<ProjectRequestsPage> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  Map<int, String> _statusNameMap = {};

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _fetchStatusesMap();
    _loadRequests();
  }

  Future<void> _fetchStatusesMap() async {
    final statuses = await fetchStatuses();
    if (mounted) {
      setState(() {
        _statusNameMap = statuses.map((key, value) => MapEntry(value, key));
      });
    }
  }

  Future<void> _loadRequests() async {
    // Construir filtro
    List<String> filters = ["IsActive eq true"];

    // Filtro por proyecto
    if (widget.projectId != null && widget.taskUUIDs != null && widget.taskUUIDs!.isNotEmpty) {
      // Filtro estricto: Solo Tareas (para coincidir con dashboard y pantalla de proyectos)
      // Eliminamos C_Project_ID de aquí si hay tareas.
      final uuidsCondition = widget.taskUUIDs!.map((uuid) => "Record_UU eq $uuid").join(' or ');
      filters.add("($uuidsCondition)");
    } else if (widget.projectId != null) {
      filters.add("C_Project_ID eq ${widget.projectId}");
    } else if (AccessControl.isProject && User.cBPartnerID != null) {
      filters.add("C_BPartner_ID eq ${User.cBPartnerID}");
    }

    String filter = filters.join(" and ");

    // Filtro por tipo (nombre)
    // Nota: R_RequestType_ID es una referencia, filtrar por nombre requiere join o saber el ID.
    // Como tenemos el nombre del gráfico, intentaremos filtrar localmente si la API no soporta join fácil.
    // Para optimizar, traemos las del proyecto y filtramos en memoria.

    final rawRequests = await fetchRequest(filter: filter);

    final filtered = rawRequests.where((req) {
      bool matchesType = true;
      if (widget.filterType != null) {
        String typeName = req['R_RequestType_Name'] ?? '';
        if (typeName.isEmpty) {
          final typeObj = req['R_RequestType_ID'];
          if (typeObj is Map) typeName = typeObj['identifier'] ?? typeObj['name'] ?? '';
        }
        if (typeName.isEmpty) typeName = 'Otros';
        matchesType = typeName == widget.filterType;
      }

      bool matchesStatus = true;
      if (widget.filterStatus != null) {
        String statusName = req['R_Status_Name'] ?? '';
        if (statusName.isEmpty) {
          final statusObj = req['R_Status_ID'];
          if (statusObj is Map) {
            statusName = statusObj['identifier'] ?? statusObj['name'] ?? '';
          } else if (statusObj is int) {
            statusName = _statusNameMap[statusObj] ?? '';
          }
        }
        if (statusName.isEmpty) statusName = 'Sin Estado';
        matchesStatus = statusName == widget.filterStatus;
      }

      return matchesType && matchesStatus;
    }).toList();

    // Procesar para tabla
    final processed = await processRequests(filtered, {}); // Pasamos mapa vacío de estados por ahora

    if (mounted) {
      setState(() {
        _requests = processed['requests'];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Solicitudes: ${widget.filterType ?? widget.filterStatus ?? "Detalle"}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? const Center(child: Text('No se encontraron solicitudes para este tipo.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: CustomTable(
                columns: const [
                  DataColumn(label: Text('Ticket')),
                  DataColumn(label: Text('Resumen')),
                  DataColumn(label: Text('Estado')),
                  DataColumn(label: Text('Prioridad')),
                  DataColumn(label: Text('Fecha')),
                ],
                rows: _requests.map((req) {
                  return DataRow(
                    cells: [
                      DataCell(Text(req['id'].toString())),
                      DataCell(SizedBox(width: 300, child: Text(req['description'] ?? ''))),
                      DataCell(Text(req['status'] ?? '')),
                      DataCell(Text(req['level'] ?? '')),
                      DataCell(Text(req['time'] ?? '')),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }
}
