import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';
import 'package:primhub/ui/Shared_Custom/custom_table.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/ui/pages/Support/Requests/create_request_dialog.dart';
import 'package:primhub/ui/pages/Support/Requests/edit_request_dialog.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';

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
  Map<String, int> _statusIdMap = {};

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
        _statusIdMap = statuses;
        _statusNameMap = statuses.map((key, value) => MapEntry(value, key));
      });
    }
  }

  Future<void> _loadRequests() async {
    // Construir filtro
    // Aseguramos que la tabla de detalles también limite a Requerimientos de Cliente
    List<String> filters = ["IsActive eq true", "R_Group_ID eq 1000006"];

    // Para un usuario de proyecto, SIEMPRE se debe filtrar por su tercero asociado.
    if (AccessControl.isProject && User.cBPartnerID != null) {
      filters.add("C_BPartner_ID eq ${User.cBPartnerID}");
    }

    // Filtro por proyecto
    if (widget.projectId != null && widget.taskUUIDs != null && widget.taskUUIDs!.isNotEmpty) {
      // Filtro estricto: Solo Tareas (para coincidir con dashboard y pantalla de proyectos)
      // Eliminamos C_Project_ID de aquí si hay tareas.
      final uuidsCondition = widget.taskUUIDs!.map((uuid) => "Record_UU eq $uuid").join(' or ');
      filters.add("($uuidsCondition)");
    } else if (widget.projectId != null) {
      filters.add("C_Project_ID eq ${widget.projectId}");
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
        String categoryName = '';
        final categoryObj = req['R_Category_ID'];
        if (categoryObj is Map) {
          categoryName = categoryObj['identifier'] ?? categoryObj['name'] ?? '';
        }
        if (categoryName.isEmpty) categoryName = 'Sin Módulo';
        matchesType = categoryName == widget.filterType;
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
        final cleanStatusName = statusName.contains('_') ? statusName.split('_').last.trim() : statusName.trim();
        matchesStatus = cleanStatusName == widget.filterStatus;
      }

      return matchesType && matchesStatus;
    }).toList();

    // Procesar para tabla
    final processed = await processRequests(filtered, _statusIdMap);

    if (mounted) {
      setState(() {
        _requests = processed['requests'];
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteRequest(dynamic id) async {
    if (!AccessControl.canManageRequests) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tienes permisos para eliminar solicitudes.')));
      return;
    }
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => CustomModal(
        title: 'Confirmar Eliminación',
        content: const Text('¿Está seguro de que desea eliminar esta solicitud?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          CustomButton(text: 'Eliminar', backgroundColor: Colors.red, onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final success = await deleteRequestApi(id);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud eliminada correctamente')));
          _initData();
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al eliminar'), backgroundColor: Colors.red));
        }
      }
    }
  }

  void _editRequest(Map<String, dynamic> req) {
    if (!AccessControl.canManageRequests) return;
    showDialog(
      context: context,
      builder: (context) => EditRequestDialog(request: req, statusIdMap: _statusIdMap, priorityMap: priorityMap, onSave: _initData, onDelete: () => _deleteRequest(req['realId'])),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Solicitudes: ${widget.filterType ?? widget.filterStatus ?? "Detalle"}'),
        actions: [IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refrescar', onPressed: _initData)],
      ),
      floatingActionButton: AccessControl.canCreateRequests
          ? FloatingActionButton(
              onPressed: () async {
                if (await showDialog(
                      context: context,
                      builder: (context) => CreateRequestDialog(linkedProjectId: widget.projectId),
                    ) ==
                    true) {
                  _initData();
                }
              },
              tooltip: 'Crear Solicitud',
              child: const Icon(Icons.add),
            )
          : null,
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
                  DataColumn(label: Text('Usuario')),
                  DataColumn(label: Text('Representante Comercial')),
                  DataColumn(label: Text('Estado')),
                  DataColumn(label: Text('Prioridad')),
                  DataColumn(label: Text('Fecha')),
                  DataColumn(label: Text('Acciones')),
                ],
                rows: _requests.map((req) {
                  return DataRow(
                    cells: [
                      DataCell(Text(req['id'].toString())),
                      DataCell(
                        Tooltip(
                          message: req['description'] ?? '',
                          child: SizedBox(width: 300, child: Text((req['description'] ?? '').length > 40 ? '${(req['description'] ?? '').substring(0, 40)}...' : (req['description'] ?? ''))),
                        ),
                      ),
                      DataCell(Text(req['userName'] ?? '')),
                      DataCell(Text(req['salesRepName'] ?? '')),
                      DataCell(Text(req['status'] ?? '')),
                      DataCell(Text(req['level'] ?? '')),
                      DataCell(Text(req['time'] ?? '')),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.reply),
                              tooltip: 'Responder Solicitud',
                              onPressed: () {
                                final id = Uri.encodeComponent(req['realId'].toString());
                                GoRouter.of(context).push('/request-updates/$id', extra: {'docNo': req['id']});
                              },
                            ),
                            if (AccessControl.canManageRequests) IconButton(icon: const Icon(Icons.edit), tooltip: 'Editar Solicitud', onPressed: () => _editRequest(req)),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }
}
