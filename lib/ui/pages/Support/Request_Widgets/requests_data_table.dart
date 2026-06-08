import 'package:flutter/material.dart';
import 'package:primhub/ui/Shared_Custom/requests_data_table_core.dart';

class RequestsDataTable extends StatefulWidget {
  final List<Map<String, dynamic>> requests;
  final Function(Map<String, dynamic>) onEdit;
  final VoidCallback? onRefresh;
  final Map<String, int> statusIdMap; // Necesario para el core
  final Map<String, String> priorityMap; // Necesario para el core

  const RequestsDataTable({super.key, required this.requests, required this.onEdit, this.onRefresh, required this.statusIdMap, required this.priorityMap});

  @override
  State<RequestsDataTable> createState() => _RequestsDataTableState();
}

class _RequestsDataTableState extends State<RequestsDataTable> {
  final Set<int> _selectedIds = {};
  int? _lastSelectedIndex;

  @override
  Widget build(BuildContext context) {
    return RequestsDataTableCore(
      requests: widget.requests,
      statusIdMap: widget.statusIdMap,
      priorityMap: widget.priorityMap,
      onEdit: widget.onEdit,
      onRefresh: widget.onRefresh,
      showProjectContext: false, // Por defecto, esta tabla no muestra contexto de proyecto
    );
  }
}
