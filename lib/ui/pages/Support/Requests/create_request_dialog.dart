import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import '../../../Shared_Custom/custom_button.dart';
import '../../../../api/contract_api.dart';
import '../../../../ui/pages/Support/Requests/request_functions.dart';
import '../../../../api/validation_manager.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import '../../../../api/token.dart';
import 'package:primhub/api/api_utils.dart';

class CreateRequestDialog extends StatefulWidget {
  final String? linkedRecordUU;
  final List<Map<String, dynamic>>? bPartners;
  final int? selectedBPartnerId;
  final int? linkedProjectId;
  final int? linkedPhaseId;
  final int? linkedTaskId;

  const CreateRequestDialog({super.key, this.linkedRecordUU, this.bPartners, this.selectedBPartnerId, this.linkedProjectId, this.linkedPhaseId, this.linkedTaskId});

  @override
  State<CreateRequestDialog> createState() => _CreateRequestDialogState();
}

class _CreateRequestDialogState extends State<CreateRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _dateStartController = TextEditingController();
  final TextEditingController _dateCompleteController = TextEditingController();
  final TextEditingController _qtyUsedController = TextEditingController();
  final TextEditingController _emailSubjectController = TextEditingController();

  String _selectedPriority = 'Media';
  String? _selectedType;
  String _selectedStatus = '1_Open';
  String? _selectedCategory;
  String? _selectedGroup;
  int? _selectedProjectId;
  int? _selectedBpId;
  int? _selectedSalesRepId;
  int? _selectedUserId;

  Map<String, int> _statusIdMap = {};
  Map<String, int> _requestTypeMap = {};
  Map<String, int> _categoryMap = {};
  Map<String, int> _groupMap = {};
  List<dynamic> _users = [];
  List<dynamic> _bPartnersList = [];

  bool _isLoadingStatuses = true;
  bool _isLoadingTypes = true;
  bool _isLoadingCategories = true;
  bool _isLoadingGroups = true;
  bool _isLoadingUsers = true;
  bool _isLoadingBPartners = true;

  @override
  void initState() {
    super.initState();
    _fetchStatuses();
    _fetchRequestTypes();
    _fetchCategories();
    _fetchGroups();
    _fetchUsers();
    // Inicializar fechas con el día de hoy para evitar strings vacíos
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    _dateStartController.text = todayStr;
    _dateCompleteController.text = todayStr;

    // Pre-llenar datos si es posible (ej. usuario actual como sales rep)
    final payload = Token.decodePayload(Token.token);
    if (payload['AD_User_ID'] != null) {
      _selectedSalesRepId = payload['AD_User_ID'];
      _selectedUserId = payload['AD_User_ID'];
    }

    if (widget.linkedRecordUU == null && AccessControl.isAdmin) {
      _fetchBPartners();
    } else {
      _isLoadingBPartners = false;
      _selectedBpId = User.cBPartnerID;
    }
  }

  Future<void> _fetchBPartners() async {
    try {
      final logic = ProjectsLogic();
      final bps = await logic.fetchBPartners();
      if (mounted) {
        setState(() {
          _bPartnersList = bps;
          _isLoadingBPartners = false;
          if (_selectedBpId == null && _bPartnersList.isNotEmpty) {
            // Intentar preseleccionar el del filtro si existe
            _selectedBpId = widget.selectedBPartnerId != null && _bPartnersList.any((bp) => bp['id'] == widget.selectedBPartnerId) ? widget.selectedBPartnerId : _bPartnersList.first['id'];
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingBPartners = false);
    }
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
      if (mounted) setState(() => _isLoadingGroups = false);
    }
  }

  Future<void> _fetchUsers() async {
    try {
      final logic = ProjectsLogic();
      final users = await logic.fetchUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingUsers = false);
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
    final bool isFullAccess = AccessControl.isAdmin;

    if (!_formKey.currentState!.validate()) return;
    if (!AccessControl.canCreateRequests) return;
    if (_isLoadingStatuses || _isLoadingTypes || _isLoadingCategories || _isLoadingGroups || _isLoadingUsers || _isLoadingBPartners) return;

    double qty = double.tryParse(_qtyUsedController.text) ?? 0.0;

    int? bpId = _selectedBpId ?? User.cBPartnerID;

    // Validación de Horas Disponibles (Solo para Soporte)
    if (widget.linkedRecordUU == null && qty > 0 && !ValidationManager.isExempt(bpId)) {
      setState(() => _isSubmitting = true); // Mostrar carga mientras validamos
      try {
        if (bpId != null) {
          // 1. Obtener horas contratadas
          final contracts = await ContractApi.getSupportContracts(bPartnerId: bpId);
          final double totalContracted = contracts.fold(0.0, (sum, contract) => sum + ((contract['contractedHours'] as num?)?.toDouble() ?? 0.0));

          // 2. Obtener horas consumidas y estimadas
          final requests = await fetchRequest(filter: "C_BPartner_ID eq $bpId");
          double totalEstimatedAndConsumed = 0.0;
          for (var req in requests) {
            final recordUU = req['Record_UU'];
            if (recordUU != null && recordUU.toString().isNotEmpty) continue;

            totalEstimatedAndConsumed += (req['QtyPlan'] as num?)?.toDouble() ?? 0.0;
          }

          final double available = totalContracted - totalEstimatedAndConsumed;

          if (qty > available) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se puede exceder las horas estimadas/consumidas de las Disponibles.'), backgroundColor: Colors.red, duration: Duration(seconds: 4)));
              setState(() => _isSubmitting = false);
            }
            return;
          }
        }
      } catch (e) {
        // Si la validación falla por un error de red, se permite continuar para no bloquear al usuario.
      }
      // No se detiene el spinner aquí, continúa al bloque de submit.
    }

    if (widget.linkedRecordUU == null && AccessControl.isAdmin && _selectedBpId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Como administrador, debe seleccionar un tercero.'), backgroundColor: Colors.red));
      }
      // Detener el spinner si la validación falla aquí
      if (_isSubmitting) setState(() => _isSubmitting = false);
      return;
    }

    if (!mounted) return;
    if (!_isSubmitting) setState(() => _isSubmitting = true);

    try {
      final url = Uri.parse(Endpoint.request);
      final payloadToken = Token.decodePayload(Token.token);
      int? clientId = Token.client ?? payloadToken['AD_Client_ID'];
      int? orgId = Token.organitation ?? payloadToken['AD_Org_ID'];
      int? userId = payloadToken['AD_User_ID'];

      int defaultStatusId = _statusIdMap.isNotEmpty ? _statusIdMap.values.first : 100;
      int openStatusId = _statusIdMap.entries.firstWhere((e) => e.key.toLowerCase().contains('open'), orElse: () => MapEntry('', defaultStatusId)).value;

      // Inyectamos directamente la relación a la tabla y el UUID en el modelo R_Request
      // asegurando que herede el proyecto y se vincule a la tarea.
      await _createManualRequest(clientId, orgId, userId, openStatusId, isFullAccess);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _createManualRequest(int? clientId, int? orgId, int? userId, int openStatusId, bool isFullAccess) async {
    final url = Uri.parse(Endpoint.request);
    double qty = double.tryParse(_qtyUsedController.text) ?? 0.0;

    final Map<String, dynamic> data = {
      'Summary': _summaryController.text,
      'Priority': isFullAccess ? _priorityMap[_selectedPriority] : '5', // 5 es Media por defecto
      'R_RequestType_ID': {'id': _requestTypeMap[_selectedType!]},
      'R_Status_ID': {'id': isFullAccess ? (_statusIdMap[_selectedStatus] ?? openStatusId) : openStatusId},
    };

    if (_emailSubjectController.text.isNotEmpty) {
      data['CDS_EmailSubject'] = _emailSubjectController.text;
    }

    if (_selectedCategory != null && _categoryMap.containsKey(_selectedCategory)) {
      data['R_Category_ID'] = {'id': _categoryMap[_selectedCategory]};
    }

    if (clientId != null) data['AD_Client_ID'] = {'id': clientId};
    if (orgId != null) data['AD_Org_ID'] = {'id': orgId};

    if (isFullAccess && _selectedUserId != null) {
      data['AD_User_ID'] = {'id': _selectedUserId};
    } else if (userId != null) {
      data['AD_User_ID'] = {'id': userId};
    }

    if (isFullAccess && _selectedSalesRepId != null) {
      data['SalesRep_ID'] = {'id': _selectedSalesRepId};
    } else if (userId != null) {
      data['SalesRep_ID'] = {'id': userId};
    }

    if (isFullAccess) {
      if (_selectedGroup != null && _groupMap.containsKey(_selectedGroup)) data['R_Group_ID'] = {'id': _groupMap[_selectedGroup]};
    }

    if (_selectedBpId != null) data['C_BPartner_ID'] = {'id': _selectedBpId};

    // Vinculación directa de IDs del Proyecto en el payload nativo
    if (widget.linkedProjectId != null) {
      data['C_Project_ID'] = {'id': widget.linkedProjectId};
    } else if (_selectedProjectId != null) {
      data['C_Project_ID'] = {'id': _selectedProjectId};
    }

    if (widget.linkedRecordUU != null) {
      data['Record_UU'] = widget.linkedRecordUU;
      data['Record_ID'] = widget.linkedTaskId;

      // Obtenemos dinámicamente el ID de la tabla C_ProjectTask para evitar errores de Foreign Key
      try {
        final tableRes = await http.get(Uri.parse('${Endpoint.baseUrl}/api/v1/models/AD_Table?\$filter=TableName eq \'C_ProjectTask\''), headers: {'Authorization': Token.token});
        if (tableRes.statusCode == 200) {
          final tData = jsonDecode(utf8.decode(tableRes.bodyBytes));
          if (tData['records'] != null && tData['records'].isNotEmpty) {
            data['AD_Table_ID'] = {'id': tData['records'][0]['id']};
          }
        }
      } catch (_) {}
    }

    if (isFullAccess && (_selectedType == 'Service Request' || _dateStartController.text.isNotEmpty)) {
      // Corregimos el envío de fechas y horas combinándolas
      String startDate = _dateStartController.text;
      String endDate = _dateCompleteController.text;

      data['DateStartPlan'] = "${startDate}T00:00:00Z";
      data['DateCompletePlan'] = "${endDate}T00:00:00Z";

      // Fecha de Inicio y Cierre reales (solicitado)
      data['StartDate'] = "${startDate}T00:00:00Z";
      data['CloseDate'] = "${endDate}T00:00:00Z";

      // Cantidad usada (solicitado) en lugar de horas/minutos separados
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
  }

  @override
  Widget build(BuildContext context) {
    final bool isFullAccess = AccessControl.isAdmin;
    return CustomModal(
      title: widget.linkedRecordUU != null ? 'Nueva Solicitud De Tarea' : 'Nueva Solicitud de Soporte',
      width: 700,
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isFullAccess) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.linkedRecordUU == null) ...[
                      Expanded(
                        child: CustomDropdown<int>(
                          label: 'Tercero',
                          hintText: _isLoadingBPartners ? 'Cargando terceros...' : 'Seleccione Tercero',
                          value: _isLoadingBPartners || !_bPartnersList.any((bp) => bp['id'] == _selectedBpId) ? null : _selectedBpId,
                          items: _bPartnersList.map((bp) => DropdownMenuItem<int>(value: bp['id'], child: Text(bp['Name'] ?? 'Tercero ${bp['id']}'))).toList(),
                          onChanged: _isLoadingBPartners ? null : (value) => setState(() => _selectedBpId = value),
                          validator: (value) => value == null ? 'Debe seleccionar un tercero.' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: CustomDropdown<int>(
                        label: 'Usuario',
                        hintText: _isLoadingUsers ? 'Cargando usuarios...' : 'Seleccione Usuario',
                        value: _isLoadingUsers || !_users.any((u) => (u['AD_User_ID'] ?? u['id']) == _selectedUserId) ? null : _selectedUserId,
                        items: _users.map<DropdownMenuItem<int>>((u) => DropdownMenuItem<int>(value: u['AD_User_ID'] ?? u['id'], child: Text(u['Name'] ?? 'Sin Nombre'))).toList(),
                        onChanged: _isLoadingUsers ? null : (value) => setState(() => _selectedUserId = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CustomDropdown<String?>(
                      value: _isLoadingTypes || !_requestTypeMap.containsKey(_selectedType) ? null : _selectedType,
                      label: 'Tipo de Solicitud',
                      hintText: _isLoadingTypes ? 'Cargando tipos...' : null,
                      items: _requestTypeMap.keys.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: _isLoadingTypes ? null : (val) => setState(() => _selectedType = val!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomDropdown<String?>(
                      value: _isLoadingCategories || !_categoryMap.containsKey(_selectedCategory) ? null : _selectedCategory,
                      label: 'Categoría',
                      hintText: _isLoadingCategories ? 'Cargando categorías...' : null,
                      items: _categoryMap.keys.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: _isLoadingCategories ? null : (val) => setState(() => _selectedCategory = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CustomTextField(controller: _emailSubjectController, label: 'Asunto'),
              const SizedBox(height: 16),

              if (isFullAccess) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CustomDropdown<String?>(
                        value: _isLoadingGroups || !_groupMap.containsKey(_selectedGroup) ? null : _selectedGroup,
                        label: 'Grupo',
                        hintText: _isLoadingGroups ? 'Cargando grupos...' : null,
                        items: _groupMap.keys.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: _isLoadingGroups ? null : (val) => setState(() => _selectedGroup = val!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomDropdown<int>(
                        label: 'Representante Comercial',
                        hintText: _isLoadingUsers ? 'Cargando usuarios...' : null,
                        value: _isLoadingUsers || !_users.any((u) => (u['AD_User_ID'] ?? u['id']) == _selectedSalesRepId) ? null : _selectedSalesRepId,
                        items: _users.map<DropdownMenuItem<int>>((u) => DropdownMenuItem<int>(value: u['AD_User_ID'] ?? u['id'], child: Text(u['Name'] ?? 'Sin Nombre'))).toList(),
                        onChanged: _isLoadingUsers ? null : (value) => setState(() => _selectedSalesRepId = value),
                      ),
                    ),
                  ],
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
                        value: _selectedPriority,
                        label: 'Prioridad',
                        items: _priorityMap.keys.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                        onChanged: (val) => setState(() => _selectedPriority = val!),
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
                        child: CustomTextField(controller: _qtyUsedController, label: 'Horas Invertidas', hintText: '0.0', keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
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
