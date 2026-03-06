import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';

class EditRequestDialog extends StatefulWidget {
  final Map<String, dynamic> request;
  final Map<String, int> statusIdMap;
  final Map<String, String> priorityMap;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  const EditRequestDialog({super.key, required this.request, required this.statusIdMap, required this.priorityMap, required this.onSave, required this.onDelete});

  @override
  State<EditRequestDialog> createState() => _EditRequestDialogState();
}

class _EditRequestDialogState extends State<EditRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _currentPriority;
  late String _currentStatus;
  late int? _statusId;
  late bool _isReadOnly;

  Map<String, int> _statusIdMap = {};
  String? _selectedType;
  String? _selectedCategory;
  String? _selectedGroup;

  Map<String, int> _requestTypeMap = {};
  Map<String, int> _categoryMap = {};
  Map<String, int> _groupMap = {};

  bool _isLoadingTypes = true;
  bool _isLoadingCategories = true;
  bool _isLoadingGroups = true;

  bool _isSaving = false;

  final _modalScrollController = ScrollController();
  final _descriptionScrollController = ScrollController();

  late TextEditingController _summaryController;
  late TextEditingController _dateStartController;
  late TextEditingController _dateCompleteController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late TextEditingController _qtyUsedController;

  @override
  void initState() {
    super.initState();
    _statusIdMap = widget.statusIdMap;
    _currentPriority = widget.request['level'];
    _currentStatus = widget.request['status'];
    _statusId = widget.request['statusId'];
    _isReadOnly = _currentStatus == '9_Final Close' || _statusId == 103;

    _summaryController = TextEditingController(text: widget.request['description']);
    _dateStartController = TextEditingController(text: widget.request['dateStartPlan']);
    _dateCompleteController = TextEditingController(text: widget.request['dateCompletePlan']);
    _startTimeController = TextEditingController(text: widget.request['startTime']);
    _endTimeController = TextEditingController(text: widget.request['endTime']);
    _qtyUsedController = TextEditingController(text: widget.request['qtyPlan']?.toString() ?? '0.0');

    _selectedType = widget.request['type'];
    _selectedCategory = widget.request['category'];
    _selectedGroup = widget.request['group'];

    _fetchStatuses();
    _fetchRequestTypes();
    _fetchCategories();
    _fetchGroups();
  }

  @override
  void dispose() {
    _modalScrollController.dispose();
    _descriptionScrollController.dispose();
    _summaryController.dispose();
    _dateStartController.dispose();
    _dateCompleteController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _qtyUsedController.dispose();
    super.dispose();
  }

  Future<void> _fetchStatuses() async {
    try {
      final response = await http.get(Uri.parse('${Endpoint.baseUrl}/api/v1/models/R_Status'), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final records = jsonResponse['records'] as List;
        if (mounted) {
          setState(() {
            _statusIdMap = {for (var r in records) r['Name']: r['id']};
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching statuses: $e');
    }
  }

  Future<void> _fetchRequestTypes() async {
    try {
      final response = await http.get(Uri.parse('${Endpoint.baseUrl}/api/v1/models/R_RequestType'), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final records = jsonResponse['records'] as List;
        if (mounted) {
          setState(() {
            _requestTypeMap = {for (var r in records) r['Name']: r['id']};
            _isLoadingTypes = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching types: $e');
      if (mounted) setState(() => _isLoadingTypes = false);
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await http.get(Uri.parse('${Endpoint.baseUrl}/api/v1/models/R_Category'), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final records = jsonResponse['records'] as List;
        if (mounted) {
          setState(() {
            _categoryMap = {for (var r in records) r['Name']: r['id']};
            _isLoadingCategories = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _fetchGroups() async {
    try {
      final response = await http.get(Uri.parse('${Endpoint.baseUrl}/api/v1/models/R_Group'), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final records = jsonResponse['records'] as List;
        if (mounted) {
          setState(() {
            _groupMap = {for (var r in records) r['Name']: r['id']};
            _isLoadingGroups = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching groups: $e');
      if (mounted) setState(() => _isLoadingGroups = false);
    }
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2101));
    if (picked != null) {
      setState(() {
        controller.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _selectTime(BuildContext context, TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) {
      setState(() {
        controller.text = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00";
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    int? statusIdToSend;
    String? statusIdentifierToSend;

    int? targetStatusId = _statusIdMap[_currentStatus];

    if (targetStatusId != null && widget.request['statusId'] != null) {
      if (targetStatusId != widget.request['statusId']) {
        statusIdToSend = targetStatusId;
      }
    } else if (_currentStatus != widget.request['status']) {
      if (targetStatusId != null) {
        statusIdToSend = targetStatusId;
      } else {
        statusIdentifierToSend = _currentStatus;
      }
    }

    String? dateStartPlanToSend = _dateStartController.text != widget.request['dateStartPlan'] ? _dateStartController.text : null;
    String? dateCompletePlanToSend = _dateCompleteController.text != widget.request['dateCompletePlan'] ? _dateCompleteController.text : null;

    // CORRECCIÓN ERROR 400: Enviar solo la hora con Z si ha cambiado
    String? startTimeToSend = _startTimeController.text != widget.request['startTime'] ? "${_startTimeController.text}Z" : null;
    String? endTimeToSend = _endTimeController.text != widget.request['endTime'] ? "${_endTimeController.text}Z" : null;

    double currentQty = double.tryParse(widget.request['qtyPlan']?.toString() ?? '0.0') ?? 0.0;
    double inputQty = double.tryParse(_qtyUsedController.text) ?? 0.0;
    double? qtyPlanToSend;

    if ((inputQty - currentQty).abs() > 0.001) {
      qtyPlanToSend = inputQty;
    }

    String? startDateToSend;
    String? closeDateToSend;

    final bool isClosing = _currentStatus == '9_Final Close' || _currentStatus == 'Final Close' || (statusIdToSend != null && statusIdToSend == 103);

    if (isClosing) {
      if (_dateStartController.text.isNotEmpty && _startTimeController.text.isNotEmpty) {
        String t = _startTimeController.text.replaceAll('Z', '');
        if (t.length == 5) t = "$t:00";
        startDateToSend = "${_dateStartController.text}T${t}Z";
      }
      if (_dateCompleteController.text.isNotEmpty && _endTimeController.text.isNotEmpty) {
        String t = _endTimeController.text.replaceAll('Z', '');
        if (t.length == 5) t = "$t:00";
        closeDateToSend = "${_dateCompleteController.text}T${t}Z";
      }

      // Primera llamada (cuando se cierra): eliminamos priorityMap
      await updateRemoteRequest(id: widget.request['realId'], priority: _currentPriority, summary: _summaryController.text, dateStartPlan: dateStartPlanToSend, dateCompletePlan: dateCompletePlanToSend, startTime: startTimeToSend, endTime: endTimeToSend, qtyPlan: qtyPlanToSend, startDate: startDateToSend, closeDate: closeDateToSend);

      statusIdToSend = 103;
      statusIdentifierToSend = null;
    }

    final result = await updateRemoteRequest(
      id: widget.request['realId'],
      priority: isClosing ? null : _currentPriority,
      statusId: statusIdToSend,
      statusIdentifier: statusIdentifierToSend,
      summary: isClosing ? null : _summaryController.text,
      dateStartPlan: dateStartPlanToSend,
      dateCompletePlan: dateCompletePlanToSend,
      startTime: startTimeToSend,
      endTime: endTimeToSend,
      qtyPlan: qtyPlanToSend,
      startDate: startDateToSend,
      closeDate: closeDateToSend,
      requestTypeId: _requestTypeMap[_selectedType],
      categoryId: _categoryMap[_selectedCategory],
      groupId: _groupMap[_selectedGroup],
    );

    setState(() => _isSaving = false);

    if (mounted) {
      if (result['success'] == true) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud actualizada correctamente')));
        widget.onSave();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${result['error']}'), backgroundColor: Colors.red, duration: const Duration(seconds: 10)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> statusItems = _statusIdMap.isNotEmpty ? (_statusIdMap.keys.toList()..sort()) : ['1_Open', '2_Waiting on customer', '3_Closed', '9_Final Close'];
    if (_currentStatus.isNotEmpty && !statusItems.contains(_currentStatus)) {
      statusItems.add(_currentStatus);
    }

    return CustomModal(
      title: 'Editar Solicitud ${widget.request['id']}',
      content: Scrollbar(
        controller: _modalScrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _modalScrollController,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomDropdown<String?>(
                  value: _selectedType,
                  label: 'Tipo de Solicitud',
                  items: _requestTypeMap.keys.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: _isReadOnly ? null : (val) => setState(() => _selectedType = val!),
                ),
                const SizedBox(height: 16),
                CustomDropdown<String?>(
                  value: _selectedCategory,
                  label: 'Categoría',
                  items: _categoryMap.keys.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: _isReadOnly ? null : (val) => setState(() => _selectedCategory = val!),
                ),
                const SizedBox(height: 16),
                CustomDropdown<String?>(
                  value: _selectedGroup,
                  label: 'Grupo',
                  items: _groupMap.keys.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: _isReadOnly ? null : (val) => setState(() => _selectedGroup = val!),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: CustomDropdown<String>(
                        value: _currentStatus,
                        label: 'Estado',
                        items: statusItems.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: _isReadOnly ? null : (val) => setState(() => _currentStatus = val!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomDropdown<String>(
                        value: _currentPriority,
                        label: 'Prioridad',
                        items: widget.priorityMap.keys.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                        onChanged: _isReadOnly ? null : (val) => setState(() => _currentPriority = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _isReadOnly ? null : () => _selectDate(context, _dateStartController),
                        child: AbsorbPointer(
                          child: CustomTextField(controller: _dateStartController, label: 'Fecha de inicio', readOnly: true, hintText: 'YYYY-MM-DD', prefixIcon: const Icon(Icons.calendar_today)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: _isReadOnly ? null : () => _selectDate(context, _dateCompleteController),
                        child: AbsorbPointer(
                          child: CustomTextField(controller: _dateCompleteController, label: 'Fecha de Cierre', readOnly: true, hintText: 'YYYY-MM-DD', prefixIcon: const Icon(Icons.calendar_today)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _isReadOnly ? null : () => _selectTime(context, _startTimeController),
                        child: AbsorbPointer(
                          child: CustomTextField(controller: _startTimeController, label: 'Hora Inicio', readOnly: true, hintText: 'HH:mm:ss', prefixIcon: const Icon(Icons.access_time)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: _isReadOnly ? null : () => _selectTime(context, _endTimeController),
                        child: AbsorbPointer(
                          child: CustomTextField(controller: _endTimeController, label: 'Hora Fin', readOnly: true, hintText: 'HH:mm:ss', prefixIcon: const Icon(Icons.access_time)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CustomTextField(controller: _qtyUsedController, label: 'Cantidad Usada', readOnly: _isReadOnly, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _summaryController,
                  scrollController: _descriptionScrollController,
                  label: 'Descripción / Resumen',
                  readOnly: _isReadOnly,
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Por favor ingrese una descripción';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onDelete();
          },
          child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(_isReadOnly ? 'Cerrar' : 'Cancelar')),
        if (!_isReadOnly) CustomButton(text: 'Guardar', isLoading: _isSaving, onPressed: _handleSave),
      ],
    );
  }
}
