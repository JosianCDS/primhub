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
import 'package:primhub/ui/Shared_Custom/customToast.dart';
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
  List<dynamic> _salesReps = [];
  List<dynamic> _bPartnersList = [];

  bool _isLoadingTypes = true;
  bool _isLoadingCategories = true;
  bool _isLoadingGroups = true;
  bool _isLoadingUsers = true;
  bool _isLoadingSalesReps = true;
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
    _fetchSalesReps();
    _fetchBPartners();
  }

  Future<void> _fetchBPartners() async {
    try {
      final logic = ProjectsLogic();
      final bps = await logic.fetchBPartners();
      if (mounted) {
        setState(() {
          // APLICAMOS EL FILTRO AQUÍ
          _bPartnersList = bps.where((bp) {
            final name = bp['Name']?.toString() ?? '';
            final isCustomer = bp['IsCustomer'] == true || bp['IsCustomer'] == 'Y';
            return !name.startsWith('~') && isCustomer;
          }).toList();

          // Rescate: Si el tercero actual del ticket estaba inactivo o no es cliente,
          // lo conservamos en la lista visual para no borrar la data existente.
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
      final users = await logic.fetchUsers(bPartnerId: _selectedBpId); // Usa el ID del tercero seleccionado
      if (mounted) {
        final previouslySelectedUserId = _selectedUserId;
        bool userWasCleared = false;

        // Si el usuario actual ya no está en la lista filtrada, lo deseleccionamos.
        if (previouslySelectedUserId != null && !users.any((u) => (u['AD_User_ID'] ?? u['id']) == previouslySelectedUserId)) {
          _selectedUserId = null;
          userWasCleared = true;
        }

        setState(() {
          _users = users;
          // Rescate: Añadir usuario actual si no vino en la lista de activos
          if (previouslySelectedUserId != null && !userWasCleared && !_users.any((u) => (u['AD_User_ID'] ?? u['id']) == previouslySelectedUserId)) {
            _users.add({'id': _selectedUserId, 'AD_User_ID': _selectedUserId, 'Name': widget.request['userName'] ?? 'Usuario $_selectedUserId'});
          }
          _isLoadingUsers = false;
        });
        if (userWasCleared) {
          WidgetsBinding.instance.addPostFrameCallback((_) => ToastMessage.show(context: context, message: 'El filtro de usuario se ha actualizado para coincidir con el tercero.', type: ToastType.help));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _fetchSalesReps() async {
    try {
      final logic = ProjectsLogic();
      final allBps = await logic.fetchBPartners();

      if (mounted) {
        setState(() {
          _salesReps = allBps.where((bp) {
            // Buscamos todas las variantes posibles del campo en el JSON
            final isRep = bp['IsSalesRep'] ?? bp['isSalesRep'] ?? bp['C_BPartner0IsSalesRep'] ?? false;

            return isRep == 'Y' || isRep == true;
          }).toList();

          _isLoadingSalesReps = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSalesReps = false);
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

  Future<void> _openSearchModal<T>({required String title, required List<dynamic> items, required T? currentValue, required String Function(dynamic) getTitle, String Function(dynamic)? getSubtitle, required T? Function(dynamic) getValue, required void Function(T?) onSelected}) async {
    final dynamic result = await showDialog(
      context: context,
      builder: (context) {
        String searchQuery = '';
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Container(
            width: 400,
            height: MediaQuery.of(context).size.height * 0.6,
            padding: const EdgeInsets.all(20),
            child: StatefulBuilder(
              builder: (context, setStateDialog) {
                final filteredItems = items.where((item) {
                  return getTitle(item).toLowerCase().contains(searchQuery.toLowerCase());
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Seleccionar $title', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400)),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.filter_list, color: Colors.grey),
                        hintText: 'Filtrar...',
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
                      ),
                      onChanged: (val) => setStateDialog(() => searchQuery = val),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filteredItems.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.grey, thickness: 0.3),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final itemValue = getValue(item);
                          final isSelected = itemValue == currentValue;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            tileColor: isSelected ? Colors.grey.withOpacity(0.1) : null,
                            title: Text(getTitle(item), style: const TextStyle(fontSize: 14)),
                            subtitle: getSubtitle != null && itemValue != null ? Text(getSubtitle(item), style: const TextStyle(fontSize: 12, color: Colors.grey)) : null,
                            onTap: () => Navigator.of(context).pop({'selected': true, 'value': itemValue}),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    // Verificamos si retornó explícitamente una selección (incluso si es null para "Todos")
    if (result != null && result is Map && result['selected'] == true) {
      onSelected(result['value'] as T?);
    }
  }

  Widget _buildSearchableField<T>({required String label, required String? hintText, required T? value, required bool isLoading, required bool isDisabled, required String displayText, required VoidCallback onTap}) {
    return InkWell(
      onTap: (isLoading || isDisabled) ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          suffixIcon: isLoading ? Transform.scale(scale: 0.5, child: const CircularProgressIndicator(strokeWidth: 3)) : const Icon(Icons.search),
        ),
        isEmpty: value == null && displayText.isEmpty,
        child: Text(
          (value == null || displayText.isEmpty) ? (hintText ?? '') : displayText,
          style: TextStyle(fontSize: 16, color: (isLoading || isDisabled || (value == null && displayText.isEmpty)) ? Colors.grey[600] : Theme.of(context).colorScheme.onSurface),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
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
                        child: _buildSearchableField<int>(
                          label: 'Tercero',
                          hintText: 'Seleccione Tercero',
                          value: _selectedBpId,
                          isLoading: _isLoadingBPartners,
                          isDisabled: _isReadOnly,
                          displayText: _selectedBpId != null && _bPartnersList.any((bp) => bp['id'] == _selectedBpId) ? _bPartnersList.firstWhere((bp) => bp['id'] == _selectedBpId)['Name'] ?? '' : '',
                          onTap: () => _openSearchModal<int>(
                            title: 'Tercero',
                            items: _bPartnersList.where((bp) => bp['id'] != null).toList(),
                            currentValue: _selectedBpId,
                            getTitle: (item) => item['Name'] ?? 'Sin Nombre',
                            getSubtitle: (item) => 'ID: ${item['id']}',
                            getValue: (item) {
                              var id = item['id'];
                              return id is int ? id : int.tryParse(id.toString());
                            },
                            onSelected: (val) {
                              setState(() {
                                _selectedBpId = val;
                                _users = [];
                                _isLoadingUsers = true;
                              });
                              _fetchUsers();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSearchableField<int>(
                          label: 'Usuario',
                          hintText: _selectedBpId == null ? 'Seleccione un tercero' : 'Seleccione Usuario',
                          value: _selectedUserId,
                          isLoading: _isLoadingUsers,
                          isDisabled: _isReadOnly || _isLoadingUsers || _selectedBpId == null,
                          displayText: _selectedUserId != null && _users.any((u) => (u['AD_User_ID'] ?? u['id']) == _selectedUserId) ? _users.firstWhere((u) => (u['AD_User_ID'] ?? u['id']) == _selectedUserId)['Name'] ?? '' : '',
                          onTap: () => _openSearchModal<int>(
                            title: 'Usuario',
                            items: _users.where((u) => (u['AD_User_ID'] ?? u['id']) != null).toList(),
                            currentValue: _selectedUserId,
                            getTitle: (item) => item['Name'] ?? 'Sin Nombre',
                            getSubtitle: (item) => 'ID: ${item['AD_User_ID'] ?? item['id']}',
                            getValue: (item) {
                              var id = item['AD_User_ID'] ?? item['id'];
                              return id is int ? id : int.tryParse(id.toString());
                            },
                            onSelected: (val) => setState(() => _selectedUserId = val),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ], // Cierre correcto del bloque isFullAccess

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildSearchableField<String>(
                        label: 'Tipo de Solicitud',
                        hintText: 'Seleccione Tipo',
                        value: _selectedType,
                        isLoading: _isLoadingTypes,
                        isDisabled: _isReadOnly || _isLoadingTypes,
                        displayText: _selectedType ?? '',
                        onTap: () => _openSearchModal<String>(title: 'Tipo de Solicitud', items: _requestTypeMap.keys.toList(), currentValue: _selectedType, getTitle: (item) => item.toString(), getValue: (item) => item.toString(), onSelected: (val) => setState(() => _selectedType = val)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSearchableField<String>(
                        label: 'Categoría',
                        hintText: 'Seleccione Categoría',
                        value: _selectedCategory,
                        isLoading: _isLoadingCategories,
                        isDisabled: _isReadOnly || _isLoadingCategories,
                        displayText: _selectedCategory ?? '',
                        onTap: () => _openSearchModal<String>(title: 'Categoría', items: _categoryMap.keys.toList(), currentValue: _selectedCategory, getTitle: (item) => item.toString(), getValue: (item) => item.toString(), onSelected: (val) => setState(() => _selectedCategory = val)),
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
                        child: _buildSearchableField<String>(
                          label: 'Grupo',
                          hintText: 'Seleccione Grupo',
                          value: _selectedGroup,
                          isLoading: _isLoadingGroups,
                          isDisabled: _isReadOnly || _isLoadingGroups,
                          displayText: _selectedGroup ?? '',
                          onTap: () => _openSearchModal<String>(title: 'Grupo', items: _groupMap.keys.toList(), currentValue: _selectedGroup, getTitle: (item) => item.toString(), getValue: (item) => item.toString(), onSelected: (val) => setState(() => _selectedGroup = val)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSearchableField<int>(
                          label: 'Representante Comercial',
                          hintText: 'Seleccione Representante',
                          value: _selectedSalesRepId,
                          isLoading: _isLoadingSalesReps,
                          isDisabled: _isReadOnly || _isLoadingSalesReps,
                          displayText: _selectedSalesRepId != null && _salesReps.any((u) => (u['AD_User_ID'] ?? u['id']) == _selectedSalesRepId) ? _salesReps.firstWhere((u) => (u['AD_User_ID'] ?? u['id']) == _selectedSalesRepId)['Name'] ?? '' : '',
                          onTap: () => _openSearchModal<int>(
                            title: 'Representante Comercial',
                            items: _salesReps.where((u) => (u['AD_User_ID'] ?? u['id']) != null).toList(),
                            currentValue: _selectedSalesRepId,
                            getTitle: (item) => item['Name'] ?? 'Sin Nombre',
                            getSubtitle: (item) => 'ID: ${item['AD_User_ID'] ?? item['id']}',
                            getValue: (item) {
                              var id = item['AD_User_ID'] ?? item['id'];
                              return id is int ? id : int.tryParse(id.toString());
                            },
                            onSelected: (val) => setState(() => _selectedSalesRepId = val),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildSearchableField<String>(
                          label: 'Estado',
                          hintText: 'Seleccione Estado',
                          value: _currentStatus,
                          isLoading: false,
                          isDisabled: _isReadOnly,
                          displayText: _currentStatus,
                          onTap: () => _openSearchModal<String>(title: 'Estado', items: statusItems, currentValue: _currentStatus, getTitle: (item) => item.toString(), getValue: (item) => item.toString(), onSelected: (val) => setState(() => _currentStatus = val ?? _currentStatus)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSearchableField<String>(
                          label: 'Prioridad',
                          hintText: 'Seleccione Prioridad',
                          value: _currentPriority,
                          isLoading: false,
                          isDisabled: _isReadOnly,
                          displayText: _currentPriority,
                          onTap: () => _openSearchModal<String>(title: 'Prioridad', items: widget.priorityMap.keys.toList(), currentValue: _currentPriority, getTitle: (item) => item.toString(), getValue: (item) => item.toString(), onSelected: (val) => setState(() => _currentPriority = val ?? _currentPriority)),
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
