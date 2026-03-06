import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import '../../../Shared_Custom/custom_button.dart';
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
  final TextEditingController _qtyUsedController = TextEditingController();

  final String _selectedPriority = 'Media';
  String? _selectedType;
  String _selectedStatus = '1_Open';
  String? _selectedCategory;
  String? _selectedGroup;
  int? _selectedProjectId;
  int? _selectedBpId;
  int? _selectedSalesRepId;

  Map<String, int> _statusIdMap = {};
  Map<String, int> _requestTypeMap = {};
  Map<String, int> _categoryMap = {};
  Map<String, int> _groupMap = {};

  bool _isLoadingStatuses = true;
  bool _isLoadingTypes = true;
  bool _isLoadingCategories = true;
  bool _isLoadingGroups = true;

  @override
  void initState() {
    super.initState();
    _fetchStatuses();
    _fetchRequestTypes();
    _fetchCategories();
    _fetchGroups();
    // Inicializar fechas con el día de hoy para evitar strings vacíos
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    _dateStartController.text = todayStr;
    _dateCompleteController.text = todayStr;

    // Pre-llenar datos si es posible (ej. usuario actual como sales rep)
    final payload = Token.decodePayload(Token.token);
    if (payload['AD_User_ID'] != null) {
      _selectedSalesRepId = payload['AD_User_ID'];
    }
    _selectedBpId = User.cBPartnerID;
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

  Future<void> _fetchRequestTypes() async {
    try {
      final response = await http.get(Uri.parse('${Endpoint.baseUrl}/api/v1/models/R_RequestType'), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final records = jsonResponse['records'] as List;
        if (mounted) {
          setState(() {
            _requestTypeMap = {for (var r in records) r['Name']: r['id']};
            if (_selectedType == null && _requestTypeMap.isNotEmpty) {
              // Prefer 'Service Request' if available, otherwise first
              if (_requestTypeMap.containsKey('Service Request')) {
                _selectedType = 'Service Request';
              } else {
                _selectedType = _requestTypeMap.keys.first;
              }
            }
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
            if (_selectedCategory == null && _categoryMap.isNotEmpty) {
              _selectedCategory = _categoryMap.keys.first;
            }
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
            if (_selectedGroup == null && _groupMap.isNotEmpty) {
              _selectedGroup = _groupMap.keys.first;
            }
            _isLoadingGroups = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching groups: $e');
      if (mounted) setState(() => _isLoadingGroups = false);
    }
  }

  final Map<String, String> _priorityMap = {'Urgente': '1', 'Alta': '3', 'Media': '5', 'Baja': '7', 'Menor': '9'};

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
    if (_isLoadingStatuses || _isLoadingTypes || _isLoadingCategories || _isLoadingGroups) return;

    setState(() => _isSubmitting = true);

    try {
      final url = Uri.parse(Endpoint.request);
      final payloadToken = Token.decodePayload(Token.token);
      int clientId = Token.client ?? payloadToken['AD_Client_ID'] ?? 11;
      int orgId = Token.organitation ?? payloadToken['AD_Org_ID'] ?? 11;
      int userId = payloadToken['AD_User_ID'] ?? 101; // Creador
      if (orgId == 0) orgId = 11;

      final Map<String, dynamic> data = {'Summary': _summaryController.text, 'Priority': _priorityMap[_selectedPriority], 'R_RequestType_ID': _requestTypeMap[_selectedType!], 'AD_Client_ID': clientId, 'AD_Org_ID': orgId, 'AD_User_ID': userId, 'SalesRep_ID': _selectedSalesRepId ?? userId, 'R_Status_ID': _statusIdMap[_selectedStatus] ?? 100};

      if (_selectedCategory != null && _categoryMap.containsKey(_selectedCategory)) data['R_Category_ID'] = _categoryMap[_selectedCategory];
      if (_selectedGroup != null && _groupMap.containsKey(_selectedGroup)) data['R_Group_ID'] = _groupMap[_selectedGroup];

      if (_selectedBpId != null) data['C_BPartner_ID'] = _selectedBpId;
      if (_selectedProjectId != null) data['C_Project_ID'] = _selectedProjectId;

      if (widget.linkedRecordUU != null) {
        data['Record_UU'] = widget.linkedRecordUU;
      }

      // Se envía la información de fechas si el tipo es Service Request o si el usuario seleccionó fechas
      if (_selectedType == 'Service Request' || _dateStartController.text.isNotEmpty) {
        // Corregimos el envío de fechas y horas combinándolas
        String startDate = _dateStartController.text;
        String endDate = _dateCompleteController.text;

        data['DateStartPlan'] = "${startDate}T00:00:00Z";
        data['DateCompletePlan'] = "${endDate}T00:00:00Z";

        // Fecha de Inicio y Cierre reales (solicitado)
        data['StartDate'] = "${startDate}T${_startTimeController.text.isEmpty ? '00:00:00' : _startTimeController.text}Z";
        if (_endTimeController.text.isNotEmpty) {
          data['CloseDate'] = "${endDate}T${_endTimeController.text}Z";
        }

        // CORRECCIÓN ERROR 400: Enviar DateTime completo en lugar de solo Time
        if (_startTimeController.text.isNotEmpty) {
          data['StartTime'] = "${_startTimeController.text}Z";
        }
        if (_endTimeController.text.isNotEmpty) {
          data['EndTime'] = "${_endTimeController.text}Z";
        }

        // Cantidad usada (solicitado) en lugar de horas/minutos separados
        double qty = double.tryParse(_qtyUsedController.text) ?? 0.0;
        if (qty > 0) {
          data['QtyPlan'] = qty;
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
      title: widget.linkedRecordUU != null ? 'Nueva Solicitud De Tarea' : 'Nueva Solicitud de Soporte',
      width: 500,
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Campos solicitados: Tipo, Categoría, Grupo, Estado, Prioridad
              CustomDropdown<String?>(
                value: _selectedType,
                label: 'Tipo de Solicitud',
                items: _requestTypeMap.keys.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _selectedType = val!),
              ),
              const SizedBox(height: 16),
              CustomDropdown<String?>(
                value: _selectedCategory,
                label: 'Categoría',
                items: _categoryMap.keys.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val!),
              ),
              const SizedBox(height: 16),
              CustomDropdown<String?>(
                value: _selectedGroup,
                label: 'Grupo',
                items: _groupMap.keys.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _selectedGroup = val!),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: CustomDropdown<String>(
                      value: _selectedStatus,
                      label: 'Estado',
                      items: _statusIdMap.keys.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) => setState(() => _selectedStatus = val!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomDropdown<String>(
                      value: _selectedPriority, // Asumiendo que existe esta variable en el estado original
                      label: 'Prioridad',
                      items: _priorityMap.keys.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (val) => setState(() {}), // Actualizar variable local
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_selectedType == 'Service Request' || _selectedType != null) ...[
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
                          child: CustomTextField(controller: _dateCompleteController, label: 'Fecha de Cierre', hintText: 'YYYY-MM-DD', prefixIcon: const Icon(Icons.calendar_today)),
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
                      child: CustomTextField(controller: _qtyUsedController, label: 'Cantidad Usada', hintText: '0.0', keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]),
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
                  if (value == null || value.trim().isEmpty) return 'Por favor ingrese una descripción';
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
