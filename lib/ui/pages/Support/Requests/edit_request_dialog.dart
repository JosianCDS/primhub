import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';
import 'package:primhub/api/validation_manager.dart';
import 'package:primhub/api/contract_api.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:primhub/api/global_cache.dart';

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
  int? _selectedSalesRepId;
  int? _selectedBpId;
  int? _selectedUserId;

  Map<String, int> _requestTypeMap = {};
  Map<String, int> _categoryMap = {};
  Map<String, int> _groupMap = {};
  List<dynamic> _users = [];
  List<dynamic> _bPartnersList = [];

  bool _isLoadingTypes = true;
  bool _isLoadingCategories = true;
  bool _isLoadingGroups = true;
  bool _isLoadingUsers = true;
  bool _isLoadingBPartners = true;

  bool _isSaving = false;

  final _modalScrollController = ScrollController();
  final _descriptionScrollController = ScrollController();

  late TextEditingController _resultController;
  late TextEditingController _newUpdateController;
  late TextEditingController _summaryController;
  late TextEditingController _dateStartController;
  late TextEditingController _dateCompleteController;
  late TextEditingController _qtyUsedController;
  late TextEditingController _emailSubjectController;

  @override
  void initState() {
    super.initState();
    _statusIdMap = widget.statusIdMap;
    _currentPriority = widget.request['level'];
    _currentStatus = widget.request['status'];
    _statusId = widget.request['statusId'];
    _isReadOnly = _currentStatus == '9_Final Close' || _statusId == 103;

    _resultController = TextEditingController(text: widget.request['result']);
    _newUpdateController = TextEditingController();
    _summaryController = TextEditingController(text: widget.request['description']);
    _dateStartController = TextEditingController(text: widget.request['dateStartPlan']);
    _dateCompleteController = TextEditingController(text: widget.request['dateCompletePlan']);
    _qtyUsedController = TextEditingController(text: widget.request['qtyPlan']?.toString() ?? '0.0');
    _emailSubjectController = TextEditingController(text: widget.request['emailSubject']);

    _selectedType = widget.request['type'];
    _selectedCategory = widget.request['category'];
    _selectedGroup = widget.request['group'];
    _selectedSalesRepId = widget.request['salesRepId'];
    _selectedBpId = widget.request['bpId'];
    _selectedUserId = widget.request['userId'];

    _fetchStatuses();
    _fetchRequestTypes();
    _fetchCategories();
    _fetchGroups();
    _fetchUsers();
    _fetchBPartners();
  }

  Future<void> _fetchBPartners() async {
    try {
      final logic = ProjectsLogic();
      final bps = await logic.fetchBPartners();
      if (mounted) {
        setState(() {
          _bPartnersList = bps;
          // Rescate: Añadir el Tercero actual si no vino en la paginación de activos
          if (_selectedBpId != null && !_bPartnersList.any((bp) => bp['id'] == _selectedBpId)) {
            _bPartnersList.add({'id': _selectedBpId, 'Name': widget.request['bpName'] ?? 'Tercero $_selectedBpId'});
          }
          _isLoadingBPartners = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingBPartners = false);
    }
  }

  @override
  void dispose() {
    _modalScrollController.dispose();
    _descriptionScrollController.dispose();
    _resultController.dispose();
    _newUpdateController.dispose();
    _summaryController.dispose();
    _dateStartController.dispose();
    _dateCompleteController.dispose();
    _qtyUsedController.dispose();
    _emailSubjectController.dispose();
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
    } catch (e) {}
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
          // Rescate: Añadir usuarios actuales si no vinieron en la lista de activos
          if (_selectedUserId != null && !_users.any((u) => (u['AD_User_ID'] ?? u['id']) == _selectedUserId)) {
            _users.add({'id': _selectedUserId, 'AD_User_ID': _selectedUserId, 'Name': widget.request['userName'] ?? 'Usuario $_selectedUserId'});
          }
          if (_selectedSalesRepId != null && !_users.any((u) => (u['AD_User_ID'] ?? u['id']) == _selectedSalesRepId)) {
            _users.add({'id': _selectedSalesRepId, 'AD_User_ID': _selectedSalesRepId, 'Name': widget.request['salesRepName'] ?? 'Rep. Comercial $_selectedSalesRepId'});
          }
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingUsers = false);
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

  void _showFullDescription(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return CustomModal(
          title: 'Descripción Completa',
          width: 600,
          content: SizedBox(
            height: 400,
            child: SingleChildScrollView(
              child: Html(
                data: _summaryController.text,
                style: {"body": Style(margin: Margins.zero, padding: HtmlPaddings.zero)},
              ),
            ),
          ),
          actions: [CustomButton(text: 'Cerrar', onPressed: () => Navigator.of(dialogContext).pop())],
        );
      },
    );
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

    double currentQty = double.tryParse(widget.request['qtyPlan']?.toString() ?? '0.0') ?? 0.0;
    double inputQty = double.tryParse(_qtyUsedController.text) ?? 0.0;

    // VALIDACIÓN DE HORAS DISPONIBLES
    // Solo validamos si es una solicitud de soporte puro (sin Record_UU, aunque aquí no lo tenemos a mano fácil, asumimos soporte por contexto)
    // y si hay un cambio en la cantidad o si se está cerrando.
    if (inputQty > 0) {
      setState(() => _isSaving = true);
      final freshData = await fetchRequest(filter: "R_Request_ID eq ${widget.request['realId']}");
      if (freshData.isNotEmpty) {
        final req = freshData.first;
        final bpId = req['C_BPartner_ID']?['id'];
        final recordUU = req['Record_UU'];

        if (bpId != null && !ValidationManager.isExempt(bpId) && (recordUU == null || recordUU.toString().isEmpty)) {
          try {
            final contracts = await ContractApi.getSupportContracts(bPartnerId: bpId);
            final double totalContracted = contracts.fold(0.0, (sum, contract) => sum + ((contract['contractedHours'] as num?)?.toDouble() ?? 0.0));

            final allRequests = await fetchRequest(filter: "C_BPartner_ID eq $bpId");
            double totalEstimatedAndConsumed = 0.0;

            for (var r in allRequests) {
              if (r['Record_UU'] != null && r['Record_UU'].toString().isNotEmpty) continue;
              if (r['id'] == widget.request['realId']) continue;
              totalEstimatedAndConsumed += (r['QtyPlan'] as num?)?.toDouble() ?? 0.0;
            }

            if (totalEstimatedAndConsumed + inputQty > totalContracted) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se puede exceder las horas estimadas/consumidas de las Disponibles.'), backgroundColor: Colors.red, duration: Duration(seconds: 4)));
                setState(() => _isSaving = false);
              }
              return;
            }
          } catch (e) {
            // Permitir continuar si la validación falla por red.
          }
        }
      }
      // Si no hay freshData, o no hay bpId, o es exento, la validación se salta.
      // No detenemos el spinner aquí, continúa al bloque de save.
    }

    double? qtyPlanToSend;

    if ((inputQty - currentQty).abs() > 0.001) {
      qtyPlanToSend = inputQty;
    }

    String? startDateToSend;
    String? closeDateToSend;

    final bool isClosing = _currentStatus == '9_Final Close' || _currentStatus == 'Final Close' || (statusIdToSend != null && statusIdToSend == 103);

    if (isClosing) {
      if (_dateStartController.text.isNotEmpty) {
        startDateToSend = "${_dateStartController.text}T00:00:00Z";
      }
      if (_dateCompleteController.text.isNotEmpty) {
        closeDateToSend = "${_dateCompleteController.text}T00:00:00Z";
      }

      // Primera llamada (cuando se cierra): eliminamos priorityMap
      await updateRemoteRequest(id: widget.request['realId'], priority: _currentPriority, summary: _summaryController.text, result: _resultController.text, dateStartPlan: dateStartPlanToSend, dateCompletePlan: dateCompletePlanToSend, qtyPlan: qtyPlanToSend, startDate: startDateToSend, closeDate: closeDateToSend);

      statusIdToSend = _statusIdMap['9_Final Close'] ?? _statusIdMap.entries.firstWhere((e) => e.key.toLowerCase().contains('close'), orElse: () => const MapEntry('', 103)).value;
      statusIdentifierToSend = null;
    }

    final result = await updateRemoteRequest(
      id: widget.request['realId'],
      priority: isClosing ? null : _currentPriority,
      statusId: statusIdToSend,
      statusIdentifier: statusIdentifierToSend,
      result: _resultController.text,
      summary: isClosing ? null : _summaryController.text,
      dateStartPlan: dateStartPlanToSend,
      dateCompletePlan: dateCompletePlanToSend,
      qtyPlan: qtyPlanToSend,
      startDate: startDateToSend,
      closeDate: closeDateToSend,
      emailSubject: _emailSubjectController.text,
      requestTypeId: _requestTypeMap[_selectedType],
      categoryId: _categoryMap[_selectedCategory],
      groupId: _groupMap[_selectedGroup],
      salesRepId: _selectedSalesRepId,
      bPartnerId: _selectedBpId,
      userId: _selectedUserId,
    );

    // Si hay una nueva actualización, la creamos
    final newUpdateText = _newUpdateController.text.trim();
    if (newUpdateText.isNotEmpty) {
      await createRequestUpdate(
        requestId: widget.request['realId'],
        resultText: newUpdateText,
        confidentialType: 'I', // Valor por defecto para actualizaciones rápidas
        isPrinted: false, // Valor por defecto
        evidences: [null, null, null, null], // Sin archivos adjuntos desde aquí
      );
    }

    if (result['success'] == true) {
      // Sincronizar el caché local con este ticket específico
      await GlobalCache.syncSingleRequest(widget.request['realId']);
    }

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
    final bool isFullAccess = AccessControl.isAdmin || AccessControl.isRealSupport;

    return CustomModal(
      title: 'Editar Solicitud ${widget.request['id']}',
      width: 700,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ticket N°: ${widget.request['id']}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        tooltip: 'Copiar Ticket',
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.request['id'].toString()));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Número de ticket copiado al portapapeles')));
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (isFullAccess) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CustomDropdown<int>(
                          label: 'Tercero',
                          hintText: _isLoadingBPartners ? 'Cargando terceros...' : 'Seleccione Tercero',
                          value: _isLoadingBPartners || !_bPartnersList.any((bp) => bp['id'] == _selectedBpId) ? null : _selectedBpId,
                          items: _bPartnersList.map((bp) => DropdownMenuItem<int>(value: bp['id'], child: Text(bp['Name'] ?? 'Tercero ${bp['id']}'))).toList(),
                          onChanged: (_isReadOnly || _isLoadingBPartners) ? null : (value) => setState(() => _selectedBpId = value),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CustomDropdown<int>(
                          label: 'Usuario',
                          hintText: _isLoadingUsers ? 'Cargando usuarios...' : 'Seleccione Usuario',
                          value: _isLoadingUsers || !_users.any((u) => (u['AD_User_ID'] ?? u['id']) == _selectedUserId) ? null : _selectedUserId,
                          items: _users.map<DropdownMenuItem<int>>((u) => DropdownMenuItem<int>(value: u['AD_User_ID'] ?? u['id'], child: Text(u['Name'] ?? 'Sin Nombre'))).toList(),
                          onChanged: (_isReadOnly || _isLoadingUsers) ? null : (value) => setState(() => _selectedUserId = value),
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
                        onChanged: (_isReadOnly || _isLoadingTypes) ? null : (val) => setState(() => _selectedType = val!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomDropdown<String?>(
                        value: _isLoadingCategories || !_categoryMap.containsKey(_selectedCategory) ? null : _selectedCategory,
                        label: 'Categoría',
                        hintText: _isLoadingCategories ? 'Cargando categorías...' : null,
                        items: _categoryMap.keys.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (_isReadOnly || _isLoadingCategories) ? null : (val) => setState(() => _selectedCategory = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CustomTextField(controller: _emailSubjectController, label: 'Asunto', readOnly: _isReadOnly),
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
                          onChanged: (_isReadOnly || _isLoadingGroups) ? null : (val) => setState(() => _selectedGroup = val!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CustomDropdown<int>(
                          label: 'Representante Comercial',
                          hintText: _isLoadingUsers ? 'Cargando usuarios...' : null,
                          value: _isLoadingUsers || !_users.any((u) => (u['AD_User_ID'] ?? u['id']) == _selectedSalesRepId) ? null : _selectedSalesRepId,
                          items: _users.map<DropdownMenuItem<int>>((u) => DropdownMenuItem<int>(value: u['AD_User_ID'] ?? u['id'], child: Text(u['Name'] ?? 'Sin Nombre'))).toList(),
                          onChanged: (_isReadOnly || _isLoadingUsers) ? null : (value) => setState(() => _selectedSalesRepId = value),
                        ),
                      ),
                    ],
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
                  CustomTextField(controller: _qtyUsedController, label: 'Horas Invertidas', readOnly: _isReadOnly, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]),
                  const SizedBox(height: 16),
                ],

                Stack(
                  alignment: Alignment.topRight,
                  children: [
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
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, right: 4.0),
                      child: IconButton(icon: const Icon(Icons.zoom_out_map), tooltip: 'Ver descripción completa', onPressed: () => _showFullDescription(context)),
                    ),
                  ],
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
