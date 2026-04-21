import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/api/global_cache.dart';

class BulkEditRequestDialog extends StatefulWidget {
  final Set<int> selectedIds;
  final VoidCallback onSaved;

  const BulkEditRequestDialog({super.key, required this.selectedIds, required this.onSaved});

  @override
  State<BulkEditRequestDialog> createState() => _BulkEditRequestDialogState();
}

class _BulkEditRequestDialogState extends State<BulkEditRequestDialog> {
  bool _isLoading = true;
  bool _isSaving = false;

  String? _selectedType;
  String? _selectedCategory;
  String? _selectedGroup;
  String? _selectedPriority;
  String? _selectedStatus;
  int? _selectedBpId;
  int? _selectedUserId;

  Map<String, int> _statusIdMap = {};
  Map<String, int> _requestTypeMap = {};
  Map<String, int> _categoryMap = {};
  Map<String, int> _groupMap = {};
  List<dynamic> _users = [];
  List<dynamic> _bPartnersList = [];

  @override
  void initState() {
    super.initState();
    _loadDictionaries();
  }

  Future<void> _loadDictionaries() async {
    try {
      final futures = await Future.wait([fetchStatuses(), _fetchMap('${Endpoint.baseUrl}/api/v1/models/R_RequestType'), _fetchMap('${Endpoint.baseUrl}/api/v1/models/R_Category'), _fetchMap('${Endpoint.baseUrl}/api/v1/models/R_Group'), ProjectsLogic().fetchUsers(), ProjectsLogic().fetchBPartners()]);

      if (mounted) {
        setState(() {
          _statusIdMap = futures[0] as Map<String, int>;
          _requestTypeMap = futures[1] as Map<String, int>;
          _categoryMap = futures[2] as Map<String, int>;
          _groupMap = futures[3] as Map<String, int>;
          _users = futures[4] as List<dynamic>;
          // Aplicamos el filtro para excluir terceros inactivos (con '~')
          final bps = futures[5] as List<dynamic>;
          _bPartnersList = bps.where((bp) {
            final name = bp['Name']?.toString() ?? '';
            final isCustomer = bp['IsCustomer'] == true || bp['IsCustomer'] == 'Y';
            return !name.startsWith('~') && isCustomer;
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error cargando diccionarios'), backgroundColor: Colors.red));
      }
    }
  }

  Future<Map<String, int>> _fetchMap(String url) async {
    final response = await http.get(Uri.parse(url), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      final records = jsonResponse['records'] as List;
      return {for (var r in records) r['Name']: r['id']};
    }
    return {};
  }

  Future<void> _handleSave() async {
    // 1. Recopilar y mapear los cambios para mostrar en el resumen
    final Map<String, String> changes = {};
    if (_selectedType != null) changes['Tipo de Solicitud'] = _selectedType!;
    if (_selectedCategory != null) changes['Categoría'] = _selectedCategory!;
    if (_selectedGroup != null) changes['Grupo'] = _selectedGroup!;
    if (_selectedPriority != null) changes['Prioridad'] = _selectedPriority!;
    if (_selectedStatus != null) changes['Estado'] = _selectedStatus!;
    if (_selectedBpId != null) {
      final bpName = _bPartnersList.firstWhere((bp) => bp['id'] == _selectedBpId, orElse: () => <String, dynamic>{})['Name']?.toString() ?? 'Tercero $_selectedBpId';
      changes['Tercero'] = bpName;
    }
    if (_selectedUserId != null) {
      final userName = _users.firstWhere((u) => (u['AD_User_ID'] ?? u['id']) == _selectedUserId, orElse: () => <String, dynamic>{})['Name']?.toString() ?? 'Usuario $_selectedUserId';
      changes['Usuario Asignado'] = userName;
    }

    // 2. Validar que haya al menos un cambio seleccionado
    if (changes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No has seleccionado ningún campo para modificar.'), backgroundColor: Colors.orange));
      return;
    }

    // 3. Mostrar el diálogo de confirmación al administrador
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => CustomModal(
        title: 'Confirmar Edición Masiva',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Seguro que vas a hacer este cambio? Vas a afectar a ${widget.selectedIds.length} fila(s) en los siguientes campos:'),
            const SizedBox(height: 16),
            ...changes.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Text('• ${e.key}: ${e.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Esta acción se aplicará inmediatamente y no se puede deshacer de forma masiva.', style: TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          CustomButton(text: 'Continuar', onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    int successCount = 0;
    int errorCount = 0;

    for (final id in widget.selectedIds) {
      final result = await updateRemoteRequest(
        id: id,
        priority: _selectedPriority,
        statusId: _selectedStatus != null ? _statusIdMap[_selectedStatus] : null,
        requestTypeId: _selectedType != null ? _requestTypeMap[_selectedType] : null,
        categoryId: _selectedCategory != null ? _categoryMap[_selectedCategory] : null,
        groupId: _selectedGroup != null ? _groupMap[_selectedGroup] : null,
        bPartnerId: _selectedBpId,
        userId: _selectedUserId,
      );

      if (result['success'] == true) {
        await GlobalCache.syncSingleRequest(id);
        successCount++;
      } else {
        errorCount++;
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Edición masiva completada: $successCount exitosos, $errorCount errores.'), backgroundColor: errorCount > 0 ? Colors.orange : Colors.green));
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const CustomModal(
        title: 'Edición Masiva',
        content: SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      );

    return CustomModal(
      title: 'Edición Masiva (${widget.selectedIds.length} Solicitudes)',
      width: 600,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Seleccione los campos que desea actualizar. Los campos en "-- No modificar --" mantendrán su valor original.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CustomDropdown<String?>(
                    label: 'Tipo de Solicitud',
                    value: _selectedType,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('-- No modificar --')),
                      ..._requestTypeMap.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))),
                    ],
                    onChanged: (val) => setState(() => _selectedType = val),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomDropdown<String?>(
                    label: 'Categoría',
                    value: _selectedCategory,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('-- No modificar --')),
                      ..._categoryMap.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))),
                    ],
                    onChanged: (val) => setState(() => _selectedCategory = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CustomDropdown<String?>(
                    label: 'Grupo',
                    value: _selectedGroup,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('-- No modificar --')),
                      ..._groupMap.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))),
                    ],
                    onChanged: (val) => setState(() => _selectedGroup = val),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomDropdown<String?>(
                    label: 'Prioridad',
                    value: _selectedPriority,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('-- No modificar --')),
                      ...priorityMap.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))),
                    ],
                    onChanged: (val) => setState(() => _selectedPriority = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomDropdown<String?>(
              label: 'Estado',
              value: _selectedStatus,
              items: [
                const DropdownMenuItem(value: null, child: Text('-- No modificar --')),
                ..._statusIdMap.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))),
              ],
              onChanged: (val) => setState(() => _selectedStatus = val),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CustomDropdown<int?>(
                    label: 'Tercero',
                    value: _selectedBpId,
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('-- No modificar --')),
                      ..._bPartnersList.map(
                        (bp) => DropdownMenuItem<int?>(
                          value: bp['id'],
                          child: Text(bp['Name'] ?? 'Tercero ${bp['id']}', overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (val) => setState(() => _selectedBpId = val),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomDropdown<int?>(
                    label: 'Usuario Asignado',
                    value: _selectedUserId,
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('-- No modificar --')),
                      ..._users.map(
                        (u) => DropdownMenuItem<int?>(
                          value: u['AD_User_ID'] ?? u['id'],
                          child: Text(u['Name'] ?? 'Sin Nombre', overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (val) => setState(() => _selectedUserId = val),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isSaving ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        CustomButton(text: 'Aplicar a ${widget.selectedIds.length} solicitudes', onPressed: _handleSave, isLoading: _isSaving),
      ],
    );
  }
}
