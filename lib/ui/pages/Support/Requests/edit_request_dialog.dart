import 'package:flutter/material.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';
import 'package:primhub/ui/shared/custom_button.dart';
import 'package:primhub/ui/shared/custom_inputs.dart';
import 'package:primhub/ui/shared/custom_modal.dart';

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
  late String _currentPriority;
  late String _currentStatus;
  late int? _statusId;
  late bool _isReadOnly;
  bool _isSaving = false;

  final _modalScrollController = ScrollController();
  final _descriptionScrollController = ScrollController();

  late TextEditingController _summaryController;
  late TextEditingController _dateStartController;
  late TextEditingController _dateCompleteController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late TextEditingController _hoursController;
  late int _selectedMinutes;

  @override
  void initState() {
    super.initState();
    _currentPriority = widget.request['level'];
    _currentStatus = widget.request['status'];
    _statusId = widget.request['statusId'];
    _isReadOnly = _currentStatus == '9_Final Close' || _statusId == 103;

    _summaryController = TextEditingController(text: widget.request['description']);
    _dateStartController = TextEditingController(text: widget.request['dateStartPlan']);
    _dateCompleteController = TextEditingController(text: widget.request['dateCompletePlan']);
    _startTimeController = TextEditingController(text: widget.request['startTime']);
    _endTimeController = TextEditingController(text: widget.request['endTime']);

    double initialQty = double.tryParse(widget.request['qtyPlan']?.toString() ?? '0') ?? 0.0;
    int initialHours = initialQty.floor();
    _selectedMinutes = ((initialQty - initialHours) * 60).round();
    _hoursController = TextEditingController(text: initialHours.toString());
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
    _hoursController.dispose();
    super.dispose();
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
    setState(() => _isSaving = true);

    int? statusIdToSend;
    String? statusIdentifierToSend;

    int? targetStatusId = widget.statusIdMap[_currentStatus];

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
    String? startTimeToSend = _startTimeController.text != widget.request['startTime'] ? _startTimeController.text : null;
    String? endTimeToSend = _endTimeController.text != widget.request['endTime'] ? _endTimeController.text : null;

    double currentQty = double.tryParse(widget.request['qtyPlan']?.toString() ?? '0') ?? 0.0;
    double inputHours = double.tryParse(_hoursController.text) ?? 0.0;
    double inputTotal = inputHours + (_selectedMinutes / 60.0);
    double? qtyPlanToSend;
    if ((inputTotal - currentQty).abs() > 0.001) {
      qtyPlanToSend = inputTotal;
    }

    String? startDateToSend;
    String? closeDateToSend;

    final bool isClosing = _currentStatus == '9_Final Close' || _currentStatus == 'Final Close' || (statusIdToSend != null && statusIdToSend == 103);

    if (isClosing) {
      if (_dateStartController.text.isNotEmpty && _startTimeController.text.isNotEmpty) {
        String t = _startTimeController.text;
        if (t.length == 5) t = "$t:00";
        startDateToSend = "${_dateStartController.text}T${t}Z";
      }
      if (_dateCompleteController.text.isNotEmpty && _endTimeController.text.isNotEmpty) {
        String t = _endTimeController.text;
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
    final List<String> statusItems = widget.statusIdMap.isNotEmpty ? (widget.statusIdMap.keys.toList()..sort()) : ['1_Open', '2_Waiting on customer', '3_Closed', '9_Final Close'];
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: _summaryController,
                scrollController: _descriptionScrollController,
                label: 'Descripción / Resumen',
                readOnly: _isReadOnly,
                maxLines: 8,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese una descripción';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _isReadOnly ? null : () => _selectDate(context, _dateStartController),
                      child: AbsorbPointer(
                        child: CustomTextField(controller: _dateStartController, label: 'Inicio Plan', readOnly: true, hintText: 'YYYY-MM-DD', prefixIcon: const Icon(Icons.calendar_today)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: _isReadOnly ? null : () => _selectDate(context, _dateCompleteController),
                      child: AbsorbPointer(
                        child: CustomTextField(controller: _dateCompleteController, label: 'Fin Plan', readOnly: true, hintText: 'YYYY-MM-DD', prefixIcon: const Icon(Icons.calendar_today)),
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
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(controller: _hoursController, label: 'Horas', readOnly: _isReadOnly, keyboardType: TextInputType.number),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomDropdown<int>(
                      label: 'Minutos',
                      value: _selectedMinutes,
                      items: List.generate(60, (index) {
                        return DropdownMenuItem(value: index, child: Text(index.toString().padLeft(2, '0')));
                      }),
                      onChanged: _isReadOnly ? null : (val) => setState(() => _selectedMinutes = val!),
                    ),
                  ),
                ],
              ),
            ],
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
