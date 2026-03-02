import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/shared/custom_inputs.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/shared/custom_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/custom_button.dart';
import '../../../../api/token.dart';

class CreateRequestDialog extends StatefulWidget {
  final String? linkedRecordUU;
  const CreateRequestDialog({super.key, this.linkedRecordUU});

  @override
  State<CreateRequestDialog> createState() => _CreateRequestDialogState();
}

class _CreateRequestDialogState extends State<CreateRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _dateStartController = TextEditingController();
  final TextEditingController _dateCompleteController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();
  int _selectedMinutes = 0;

  String _selectedPriority = 'Media';
  String _selectedType = 'Service Request';
  String _selectedStatus = '1_Open';
  Map<String, int> _statusIdMap = {};
  bool _isLoadingStatuses = true;

  @override
  void initState() {
    super.initState();
    _fetchStatuses();
    // Inicializar fechas con el día de hoy para evitar strings vacíos
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    _dateStartController.text = todayStr;
    _dateCompleteController.text = todayStr;
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
            _isLoadingStatuses = false;
            if (!_statusIdMap.containsKey(_selectedStatus) && _statusIdMap.isNotEmpty) {
              _selectedStatus = _statusIdMap.keys.firstWhere((k) => k.toLowerCase().contains('open'), orElse: () => _statusIdMap.keys.first);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching statuses: $e');
    } finally {
      if (mounted && _isLoadingStatuses) setState(() => _isLoadingStatuses = false);
    }
  }

  final Map<String, String> _priorityMap = {'Urgente': '1', 'Alta': '3', 'Media': '5', 'Baja': '7', 'Menor': '9'};

  final Map<String, int> _requestTypeMap = {'Service Request': 101, 'Request for Quotation': 100, 'Warranty': 103};

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

  // --- CORRECCIÓN LÓGICA DE FECHAS ---
  String _combineDateAndTime(String date, String time) {
    if (date.isEmpty) {
      date = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
    }
    String cleanTime = time.isEmpty ? "00:00:00" : time;
    // Si el tiempo ya trae una Z o una T, lo limpiamos para estandarizar
    cleanTime = cleanTime.replaceAll('Z', '');
    if (cleanTime.contains('T')) cleanTime = cleanTime.split('T')[1];

    return "${date}T${cleanTime}Z";
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (!AccessControl.canCreateRequests) return;
    if (_isLoadingStatuses) return;

    setState(() => _isSubmitting = true);

    try {
      final url = Uri.parse(Endpoint.request);
      final payloadToken = Token.decodePayload(Token.token);
      int clientId = Token.client ?? payloadToken['AD_Client_ID'] ?? 11;
      int orgId = Token.organitation ?? payloadToken['AD_Org_ID'] ?? 11;
      int userId = payloadToken['AD_User_ID'] ?? 101;
      if (orgId == 0) orgId = 11;

      final Map<String, dynamic> data = {'Summary': _summaryController.text, 'Priority': _priorityMap[_selectedPriority], 'R_RequestType_ID': _requestTypeMap[_selectedType], 'AD_Client_ID': clientId, 'AD_Org_ID': orgId, 'AD_User_ID': userId, 'SalesRep_ID': userId, 'R_Status_ID': _statusIdMap[_selectedStatus] ?? 100};

      if (widget.linkedRecordUU != null) {
        data['Record_UU'] = widget.linkedRecordUU;
      }

      if (_selectedType == 'Service Request') {
        // Corregimos el envío de fechas y horas combinándolas
        String startDate = _dateStartController.text;
        String endDate = _dateCompleteController.text;

        data['DateStartPlan'] = "${startDate}T00:00:00Z";
        data['DateCompletePlan'] = "${endDate}T00:00:00Z";

        // CORRECCIÓN ERROR 400: Enviar DateTime completo en lugar de solo Time
        data['StartTime'] = _combineDateAndTime(startDate, _startTimeController.text);
        data['EndTime'] = _combineDateAndTime(endDate, _endTimeController.text);

        double h = double.tryParse(_hoursController.text) ?? 0.0;
        double m = _selectedMinutes.toDouble();
        if (h > 0 || m > 0) {
          data['QtyPlan'] = h + (m / 60.0);
        }
      }

      final body = jsonEncode(data);

      final response = await http.post(url, headers: {'Content-Type': 'application/json', 'Authorization': Token.token}, body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud creada correctamente')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error ${response.statusCode}: ${response.body}'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomModal(
      title: 'Nueva Solicitud de Soporte',
      width: 500,
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomDropdown<String>(
                value: _selectedType,
                label: 'Situación',
                items: ['Service Request', 'Request for Quotation', 'Warranty'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _selectedType = val!),
              ),
              const SizedBox(height: 16),
              if (_selectedType == 'Service Request') ...[
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectDate(context, _dateStartController),
                        child: AbsorbPointer(
                          child: CustomTextField(controller: _dateStartController, label: 'Inicio Plan', hintText: 'YYYY-MM-DD', prefixIcon: const Icon(Icons.calendar_today)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectDate(context, _dateCompleteController),
                        child: AbsorbPointer(
                          child: CustomTextField(controller: _dateCompleteController, label: 'Fecha Final', hintText: 'YYYY-MM-DD', prefixIcon: const Icon(Icons.calendar_today)),
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
                        onTap: () => _selectTime(context, _startTimeController),
                        child: AbsorbPointer(
                          child: CustomTextField(controller: _startTimeController, label: 'Hora de Inicio', hintText: 'HH:mm:ss', prefixIcon: const Icon(Icons.access_time)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectTime(context, _endTimeController),
                        child: AbsorbPointer(
                          child: CustomTextField(controller: _endTimeController, label: 'Hora de Finalización', hintText: 'HH:mm:ss', prefixIcon: const Icon(Icons.access_time)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(controller: _hoursController, label: 'Horas', hintText: '0', keyboardType: TextInputType.number),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomDropdown<int>(
                        label: 'Minutos',
                        value: _selectedMinutes,
                        items: List.generate(60, (index) {
                          return DropdownMenuItem(value: index, child: Text(index.toString().padLeft(2, '0')));
                        }),
                        onChanged: (val) => setState(() => _selectedMinutes = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              CustomTextField(
                controller: _summaryController,
                label: 'Descripción / Resumen',
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Por favor ingrese una descripción';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        CustomButton(text: 'Enviar Solicitud', onPressed: _submitForm, isLoading: _isSubmitting),
      ],
    );
  }
}
