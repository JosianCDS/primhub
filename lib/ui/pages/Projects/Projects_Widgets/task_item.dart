import 'package:flutter/material.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/ui/pages/Projects/Projects_Widgets/uu_requests_data_table.dart';
import 'package:primhub/ui/pages/Projects/dialogs/item_edit_dialog.dart';
import 'package:primhub/ui/pages/Support/Requests/edit_request_dialog.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';
import 'package:primhub/ui/pages/Support/Requests/create_request_dialog.dart';
import 'package:primhub/api/global_cache.dart';

class TaskItem extends StatefulWidget {
  final Map<String, dynamic> task;
  final Map<String, dynamic>? phase;
  final bool initiallyExpanded;
  final Map<String, int> statusIdMap;
  final Map<String, String> priorityMap;
  final VoidCallback onRefresh;
  final Function(String type, int id, String name, String desc) onEdit;
  final bool isArchived;
  final int projectId;

  const TaskItem({super.key, required this.task, this.phase, required this.initiallyExpanded, required this.statusIdMap, required this.priorityMap, required this.onRefresh, required this.onEdit, this.isArchived = false, required this.projectId});

  @override
  State<TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends State<TaskItem> {
  final ProjectsLogic _logic = ProjectsLogic();

  Future<List<Map<String, dynamic>>> _getTaskRequests(String? taskUU) async {
    if (taskUU == null || taskUU.isEmpty) return [];
    // Si los datos ya están cacheados, buscamos en memoria (extremadamente rápido)
    if (GlobalCache.isDataLoaded) {
      return GlobalCache.requests.where((r) => r['Record_UU'] == taskUU).toList();
    }
    return await _logic.fetchRequestsForTask(taskUU);
  }

  String? _getDropdownValue(dynamic rawValue) {
    final extracted = DocumentsLogic.extractValue(rawValue);
    return extracted == 'N/A' ? null : extracted;
  }

  Future<void> _deleteRequest(dynamic id) async {
    if (!AccessControl.canManageRequests) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tienes permisos para eliminar solicitudes.')));
      return;
    }
    // Diálogo de confirmación simple
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text('¿Está seguro de que desea eliminar esta solicitud?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await deleteRequestApi(id);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud eliminada correctamente')));
          setState(() {}); // Recargar la lista de solicitudes de la tarea
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al eliminar'), backgroundColor: Colors.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskId = widget.task['id'] is int ? widget.task['id'] as int : int.tryParse(widget.task['id'].toString()) ?? 0;
    final taskName = widget.task['Name'] ?? 'Tarea sin nombre';
    final rawUU = widget.task['C_ProjectTask_UU'] ?? widget.task['UUID'] ?? widget.task['uuid'] ?? widget.task['Record_UU'] ?? widget.task['uid'];
    String? taskUU;
    if (rawUU is String) taskUU = rawUU;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getTaskRequests(taskUU),
      builder: (context, snapshot) {
        final rawRequests = snapshot.data ?? [];
        final requests = rawRequests.map((r) {
          final newR = Map<String, dynamic>.from(r);
          newR['_rawId'] = r['id'];
          newR['id'] = r['DocumentNo'] ?? r['id'].toString();
          return newR;
        }).toList();
        final countText = snapshot.connectionState == ConnectionState.waiting ? '...' : '${requests.length}';

        return ExpansionTile(
          key: Key('task-$taskId'),
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
          trailing: ((AccessControl.canCreateRequests || AccessControl.canEditProject) && !widget.isArchived)
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
                            builder: (context) => CreateRequestDialog(linkedRecordUU: taskUU, linkedProjectId: widget.projectId, linkedPhaseId: widget.phase?['id'], linkedTaskId: taskId),
                          );
                          if (result == true) {
                            setState(() {}); // Refresca solo esta tarea para evitar colapsar el proyecto
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
                  onRefresh: () => setState(() {}),
                  onEdit: (req) {
                    if (!AccessControl.canManageRequests) return;

                    final int? currentStatusId = req['R_Status_ID'] is Map ? req['R_Status_ID']['id'] : (req['R_Status_ID'] is int ? req['R_Status_ID'] : null);
                    String currentStatusName = '1_Open';

                    if (currentStatusId != null) {
                      for (var entry in widget.statusIdMap.entries) {
                        if (entry.value == currentStatusId) {
                          currentStatusName = entry.key;
                          break;
                        }
                      }
                      if (currentStatusName == '1_Open') {
                        final extracted = DocumentsLogic.extractValue(req['R_Status_ID']);
                        if (extracted != 'N/A') currentStatusName = extracted;
                      }
                    }

                    // Mapeo manual de la solicitud cruda a lo que espera el diálogo de edición
                    final Map<String, dynamic> processedReq = {
                      'realId': req['_rawId'] ?? req['id'],
                      'id': req['id'].toString(), // Ya contiene el DocumentNo por el mapeo superior
                      'description': req['Summary'] ?? '',
                      'level': DocumentsLogic.extractValue(req['Priority']) == 'N/A' ? 'Media' : DocumentsLogic.extractValue(req['Priority']),
                      'status': currentStatusName,
                      'statusId': currentStatusId,
                      'dateStartPlan': req['DateStartPlan'] ?? '',
                      'dateCompletePlan': req['DateCompletePlan'] ?? '',
                      'startTime': extractTime(req['StartTime']),
                      'endTime': extractTime(req['EndTime']),
                      'qtyPlan': req['QtyPlan']?.toString() ?? '',
                      'type': _getDropdownValue(req['R_RequestType_ID']),
                      'category': _getDropdownValue(req['R_Category_ID']),
                      'group': _getDropdownValue(req['R_Group_ID']),
                      'salesRepId': req['SalesRep_ID'] is Map ? req['SalesRep_ID']['id'] : (req['SalesRep_ID'] is int ? req['SalesRep_ID'] : null),
                      'bpId': req['C_BPartner_ID'] is Map ? req['C_BPartner_ID']['id'] : (req['C_BPartner_ID'] is int ? req['C_BPartner_ID'] : null),
                      'userId': req['AD_User_ID'] is Map ? req['AD_User_ID']['id'] : (req['AD_User_ID'] is int ? req['AD_User_ID'] : null),
                    };

                    showDialog(
                      context: context,
                      builder: (context) => EditRequestDialog(
                        request: processedReq,
                        statusIdMap: widget.statusIdMap,
                        priorityMap: widget.priorityMap,
                        onSave: () => setState(() {}), // Recargar al guardar
                        onDelete: () => _deleteRequest(req['_rawId'] ?? req['id']),
                      ),
                    );
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
