import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/shared/custom_inputs.dart';
import 'package:primhub/ui/shared/custom_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/custom_button.dart';
import '../../../api/token.dart';
import 'package:primhub/ui/shared/duration_formatter.dart';

class CreateRequestDialog extends StatefulWidget {
  const CreateRequestDialog({super.key});

  @override
  State<CreateRequestDialog> createState() => _CreateRequestDialogState();
}

class _CreateRequestDialogState extends State<CreateRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // Controladores y variables del formulario
  final TextEditingController _summaryController = TextEditingController();
  // Controladores para Service Request
  final TextEditingController _dateStartController = TextEditingController();
  final TextEditingController _dateCompleteController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _qtyPlanController = TextEditingController();

  String _selectedPriority = 'Media';
  String _selectedType = 'Service Request';
  String _selectedStatus = '1_Open';
  Map<String, int> _statusIdMap = {};
  bool _isLoadingStatuses = true;
  bool _isAdmin = true;

  @override
  void initState() {
    super.initState();
    _checkRole();
    _fetchStatuses();
  }

  Future<void> _checkRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted)
      setState(
        () => _isAdmin = (prefs.getString('user_role') ?? 'ADMIN') == 'ADMIN',
      );
  }

  Future<void> _fetchStatuses() async {
    try {
      final response = await http.get(
        Uri.parse('${Endpoint.baseUrl}/api/v1/models/R_Status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final records = jsonResponse['records'] as List;
        if (mounted) {
          setState(() {
            _statusIdMap = {for (var r in records) r['Name']: r['id']};
            _isLoadingStatuses = false;

            // Si el estado seleccionado por defecto no existe en el mapa cargado,
            // seleccionar el primero disponible para evitar errores de envío.
            if (!_statusIdMap.containsKey(_selectedStatus) &&
                _statusIdMap.isNotEmpty) {
              _selectedStatus = _statusIdMap.keys.firstWhere(
                (k) => k.toLowerCase().contains('open'),
                orElse: () => _statusIdMap.keys.first,
              );
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching statuses: $e');
    } finally {
      if (mounted && _isLoadingStatuses)
        setState(() => _isLoadingStatuses = false);
    }
  }

  // Mapeo de valores para el backend
  final Map<String, String> _priorityMap = {
    'Urgente': '1',
    'Alta': '3',
    'Media': '5',
    'Baja': '7',
    'Menor': '9',
  };

  // IDs correspondientes a los tipos de solicitud
  final Map<String, int> _requestTypeMap = {
    'Service Request': 101,
    'Request for Quotation': 100,
    'Warranty': 103,
  };

  void _calculateHours() {
    if (_startTimeController.text.isNotEmpty &&
        _endTimeController.text.isNotEmpty) {
      try {
        DateTime startBase = _dateStartController.text.isNotEmpty
            ? DateTime.parse(_dateStartController.text)
            : DateTime.now();
        DateTime endBase = _dateCompleteController.text.isNotEmpty
            ? DateTime.parse(_dateCompleteController.text)
            : startBase;

        final sParts = _startTimeController.text.split(':');
        final eParts = _endTimeController.text.split(':');
        if (sParts.length >= 2 && eParts.length >= 2) {
          final start = DateTime(
            startBase.year,
            startBase.month,
            startBase.day,
            int.parse(sParts[0]),
            int.parse(sParts[1]),
          );
          var end = DateTime(
            endBase.year,
            endBase.month,
            endBase.day,
            int.parse(eParts[0]),
            int.parse(eParts[1]),
          );
          if (end.isBefore(start)) {
            end = end.add(const Duration(days: 1));
            _dateCompleteController.text =
                "${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}";
          }
          final diff = end.difference(start);
          final hours = diff.inMinutes / 60.0;
          _qtyPlanController.text = hours.toStringAsFixed(2);
          setState(() {});
        }
      } catch (_) {}
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      controller.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      _calculateHours();
    }
  }

  Future<void> _selectTime(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      controller.text =
          "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00";
      _calculateHours();
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isLoadingStatuses) return;
    if (_statusIdMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se han cargado los estados. Verifique su conexión e intente nuevamente.',
          ),
        ),
      );
      _fetchStatuses();
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final url = Uri.parse(Endpoint.request);

      final payload = Token.decodePayload(Token.token);
      int clientId = Token.client ?? payload['AD_Client_ID'] ?? 11;
      int orgId = Token.organitation ?? payload['AD_Org_ID'] ?? 11;
      int userId = payload['AD_User_ID'] ?? 101;
      if (orgId == 0) orgId = 11;

      final Map<String, dynamic> data = {
        'Summary': _summaryController.text,
        'Priority': _priorityMap[_selectedPriority],
        'R_RequestType_ID': _requestTypeMap[_selectedType],
        'AD_Client_ID': clientId,
        'AD_Org_ID': orgId,
        'AD_User_ID': userId,
        'SalesRep_ID': userId,
        'R_Status_ID': _statusIdMap.containsKey(_selectedStatus)
            ? _statusIdMap[_selectedStatus]
            : {'identifier': _selectedStatus},
      };

      if (_selectedType == 'Service Request') {
        if (_dateStartController.text.isNotEmpty) {
          data['DateStartPlan'] = _ensureIsoDate(_dateStartController.text);
        }
        if (_dateCompleteController.text.isNotEmpty) {
          data['DateCompletePlan'] = _ensureIsoDate(
            _dateCompleteController.text,
          );
        }
        if (_startTimeController.text.isNotEmpty) {
          data['StartTime'] = _ensureIsoTime(_startTimeController.text);
        }
        if (_endTimeController.text.isNotEmpty) {
          data['EndTime'] = _ensureIsoTime(_endTimeController.text);
        }
        if (_qtyPlanController.text.isNotEmpty) {
          data['QtyPlan'] = double.tryParse(_qtyPlanController.text);
        }
      }

      final body = jsonEncode(data);

      debugPrint('Payload enviado: $body');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Solicitud creada correctamente')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error ${response.statusCode}: ${response.body}\nPayload: $body',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear solicitud: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _ensureIsoDate(String val) {
    if (val.isEmpty) return "";
    if (val.contains('T')) return val;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(val)) {
      return "${val}T00:00:00Z";
    }
    return val;
  }

  String _ensureIsoTime(String time) {
    if (time.isEmpty) return "";
    String timePart = time;
    if (time.contains('T')) {
      timePart = time.split('T')[1];
    }
    if (timePart.length == 5) timePart = "$timePart:00";
    if (!timePart.endsWith('Z')) timePart = "${timePart}Z";
    return timePart;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusItems = _statusIdMap.isNotEmpty
        ? (_statusIdMap.keys.toList()..sort())
        : ['1_Open', '2_Waiting on customer', '3_Closed'];
    if (!statusItems.contains(_selectedStatus)) {
      statusItems.add(_selectedStatus);
    }

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
                items: ['Service Request', 'Request for Quotation', 'Warranty']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedType = val!),
              ),
              const SizedBox(height: 16),
              /*
              _isLoadingStatuses
                  ? const Center(child: CircularProgressIndicator())
                  : CustomDropdown<String>(
                      value: _selectedStatus,
                      label: 'Estado',
                      items: statusItems
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedStatus = val!),
                    ),
              if (_selectedStatus != '1_Open')
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: Text(
                    'Si el estado no es open este registro no podrá eliminarse.',
                    style: TextStyle(
                      color: isDark ? Colors.red.shade300 : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              */
              if (_selectedType == 'Service Request') ...[
                /*
                CustomDropdown<String>(
                  label: 'Nivel de Prioridad',
                  value: _selectedPriority,
                  items: ['Urgente', 'Alta', 'Media', 'Baja', 'Menor']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedPriority = val!),
                ),
                const SizedBox(height: 16),
                */
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectDate(context, _dateStartController),
                        child: AbsorbPointer(
                          child: CustomTextField(
                            controller: _dateStartController,
                            label: 'Inicio Plan',
                            hintText: 'YYYY-MM-DD',
                            prefixIcon: const Icon(Icons.calendar_today),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            _selectDate(context, _dateCompleteController),
                        child: AbsorbPointer(
                          child: CustomTextField(
                            controller: _dateCompleteController,
                            label: 'Fecha Final',
                            hintText: 'YYYY-MM-DD',
                            prefixIcon: const Icon(Icons.calendar_today),
                          ),
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
                          child: CustomTextField(
                            controller: _startTimeController,
                            label: 'Hora de Inicio',
                            hintText: 'HH:mm:ss',
                            prefixIcon: const Icon(Icons.access_time),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectTime(context, _endTimeController),
                        child: AbsorbPointer(
                          child: CustomTextField(
                            controller: _endTimeController,
                            label: 'Hora de Finalización',
                            hintText: 'HH:mm:ss',
                            prefixIcon: const Icon(Icons.access_time),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? Colors.grey.shade600
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Horas Planificadas",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DurationFormatter.format(
                          double.tryParse(_qtyPlanController.text) ?? 0.0,
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              CustomTextField(
                controller: _summaryController,
                label: 'Descripción / Resumen',
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese una descripción';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        CustomButton(
          text: 'Enviar Solicitud',
          onPressed: _submitForm,
          isLoading: _isSubmitting,
        ),
      ],
    );
  }
}
