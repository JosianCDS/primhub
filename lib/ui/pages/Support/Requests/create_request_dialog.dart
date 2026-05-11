import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import '../../../Shared_Custom/custom_button.dart';
import '../../../../api/contract_api.dart';
import 'package:primhub/ui/Shared_Custom/customToast.dart';
import '../../../../ui/pages/Support/Requests/request_functions.dart';
import '../../../../api/validation_manager.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import '../../../../api/token.dart';
import 'package:primhub/api/api_utils.dart';
import 'package:primhub/api/global_cache.dart';
import 'package:primhub/ImagesManagment/postAttachments.dart';

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
  String _selectedStatus = 'Recibida';
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
  List<dynamic> _salesReps = [];
  List<dynamic> _bPartnersList = [];

  bool _isLoadingStatuses = true;
  bool _isLoadingTypes = true;
  bool _isLoadingCategories = true;
  bool _isLoadingGroups = true;
  bool _isLoadingUsers = true;
  bool _isLoadingSalesReps = true;
  bool _isLoadingBPartners = true;

  List<PlatformFile?> _evidences = [null, null, null, null];

  @override
  void initState() {
    super.initState();
    _salesReps = GlobalCache.salesReps;
    _isLoadingSalesReps = false;
    _fetchInitialData();
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

    if (AccessControl.isAdmin) {
      _fetchBPartners();
    } else {
      _isLoadingBPartners = false;
      _selectedBpId = User.cBPartnerID;
      _fetchUsers(); // Cargar usuarios para el tercero del usuario actual
    }
  }

  Future<void> _fetchInitialData() async {
    await Future.wait([_fetchStatuses(), _fetchRequestTypes(), _fetchCategories(), _fetchGroups()]);
  }

  Future<void> _fetchBPartners() async {
    try {
      int? resolvedBpId = widget.selectedBPartnerId;

      // Si la solicitud nace desde un proyecto, heredamos obligatoriamente su tercero
      if (resolvedBpId == null && widget.linkedProjectId != null) {
        var projRes = await http.get(Uri.parse('${Endpoint.project}/${widget.linkedProjectId}?\$select=C_BPartner_ID'), headers: {'Authorization': Token.token});
        if (projRes.statusCode == 401) {
          if (await handleTokenRefresh()) {
            projRes = await http.get(Uri.parse('${Endpoint.project}/${widget.linkedProjectId}?\$select=C_BPartner_ID'), headers: {'Authorization': Token.token});
          }
        }
        if (projRes.statusCode == 200) {
          final data = jsonDecode(utf8.decode(projRes.bodyBytes));
          final bpField = data['C_BPartner_ID'];
          resolvedBpId = (bpField is Map) ? bpField['id'] : (bpField is int ? bpField : null);
        }
      }

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

          _isLoadingBPartners = false;

          if (_selectedBpId == null && _bPartnersList.isNotEmpty) {
            _selectedBpId = resolvedBpId != null && _bPartnersList.any((bp) => bp['id'] == resolvedBpId) ? resolvedBpId : (widget.linkedProjectId != null ? resolvedBpId : _bPartnersList.first['id']);
          }

          // Rescate: Si el tercero del proyecto no estaba en la lista de activos o clientes, lo añadimos para evitar errores en el dropdown
          if (_selectedBpId != null && !_bPartnersList.any((bp) => bp['id'] == _selectedBpId)) {
            _bPartnersList.add({'id': _selectedBpId, 'Name': 'Tercero $_selectedBpId (Vinculado)'});
          }
          _fetchUsers(); // Cargar usuarios para el tercero pre-seleccionado
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
              // Predefinir 'Soporte Lirion', fallback a 'Service Request' u otro
              if (_requestTypeMap.containsKey('Soporte Lirion')) {
                _selectedType = 'Soporte Lirion';
              } else if (_requestTypeMap.containsKey('Service Request')) {
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
            // Solo autoseleccionar categoría si es administrador
            if (_selectedCategory == null && _categoryMap.isNotEmpty && AccessControl.isAdmin) {
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
      if (_selectedBpId == null) {
        if (mounted) setState(() => _isLoadingUsers = false);
        return;
      }
      final logic = ProjectsLogic();
      final users = await logic.fetchUsers(bPartnerId: _selectedBpId);
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

  Future<void> _pickFile(int index) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null && result.files.isNotEmpty) {
      if (result.files.first.bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al leer el archivo. Intente con otro formato.'), backgroundColor: Colors.orange));
        return;
      }
      setState(() {
        _evidences[index] = result.files.first;
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _evidences[index] = null;
    });
  }

  Widget _buildEvidenceField(int index) {
    final file = _evidences[index];
    final theme = Theme.of(context);

    bool isImage = false;
    if (file != null && file.extension != null) {
      final ext = file.extension!.toLowerCase();
      isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: (isImage && file?.bytes != null)
                  ? () {
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: Stack(
                            alignment: Alignment.topRight,
                            children: [
                              InteractiveViewer(child: Image.memory(file!.bytes!)),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        file != null ? file.name : 'Adjunto ${index + 1} (Sin archivo)',
                        style: TextStyle(color: file != null ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isImage) const Icon(Icons.visibility, size: 18, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (file == null) IconButton(icon: const Icon(Icons.attach_file), onPressed: () => _pickFile(index), tooltip: 'Adjuntar Archivo', color: theme.colorScheme.primary) else IconButton(icon: const Icon(Icons.delete), onPressed: () => _removeFile(index), tooltip: 'Eliminar Adjunto', color: theme.colorScheme.error),
        ],
      ),
    );
  }

  Future<void> _openSearchModal<T>({required String title, required List<dynamic> items, required T? currentValue, required String Function(dynamic) getTitle, String Function(dynamic)? getSubtitle, required T Function(dynamic) getValue, required void Function(T) onSelected}) async {
    final T? result = await showDialog<T>(
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
                    Text('Seleccionar $title *', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400)),
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
                            subtitle: getSubtitle != null ? Text(getSubtitle(item), style: const TextStyle(fontSize: 12, color: Colors.grey)) : null,
                            onTap: () => Navigator.of(context).pop(itemValue),
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

    if (result != null) onSelected(result);
  }

  Widget _buildSearchableField<T>({required String label, required String? hintText, required T? value, required bool isLoading, required bool isDisabled, required String displayText, required VoidCallback onTap, String? errorMessage}) {
    return InkWell(
      onTap: (isLoading || isDisabled) ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorMessage,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          suffixIcon: isLoading ? Transform.scale(scale: 0.5, child: const CircularProgressIndicator(strokeWidth: 3)) : const Icon(Icons.search),
        ),
        isEmpty: value == null,
        child: Text(
          value == null ? (hintText ?? '') : displayText,
          style: TextStyle(fontSize: 16, color: (isLoading || isDisabled || value == null) ? Colors.grey[600] : Theme.of(context).colorScheme.onSurface),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
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

    // --- LÓGICA PARA SELECCIONAR ORDEN DE VENTA ---
    int? orderId;
    if (widget.linkedRecordUU == null && bpId != null) {
      // Solo aplica para solicitudes de soporte, no para las de tareas de proyecto.
      final contracts = await ContractApi.getSupportContracts(bPartnerId: bpId);
      if (contracts.length > 1) {
        // Si hay más de un contrato, mostrar modal para seleccionar.
        orderId = await showDialog<int>(
          context: context,
          builder: (context) {
            int? tempOrderId;
            return StatefulBuilder(
              builder: (context, setModalState) {
                return CustomModal(
                  title: 'Seleccionar Contrato',
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Este tercero tiene múltiples contratos de soporte. Por favor, seleccione de cuál se deben descontar las horas.'),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: tempOrderId,
                        hint: const Text('Seleccione un contrato'),
                        items: contracts.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['DocumentNo'] as String))).toList(),
                        onChanged: (val) => setModalState(() => tempOrderId = val),
                        validator: (val) => val == null ? 'Debe seleccionar un contrato' : null,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
                    CustomButton(text: 'Confirmar', onPressed: () => Navigator.pop(context, tempOrderId)),
                  ],
                );
              },
            );
          },
        );
        if (orderId == null) return;
      } else if (contracts.length == 1) {
        orderId = contracts.first['id'] as int?;
      }
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => CustomModal(
        title: 'Confirmar Solicitud',
        content: const Text('¿Seguro quiere continuar? Al enviar la solicitud esta no puede ser editada por usted, compruebe que toda la información y/o adjuntos sean correctos antes de continuar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Revisar')),
          CustomButton(text: 'Sí, continuar', onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirm != true) return;

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
      await _createManualRequest(clientId, orgId, userId, openStatusId, isFullAccess, orderId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _createManualRequest(int? clientId, int? orgId, int? userId, int openStatusId, bool isFullAccess, int? orderId) async {
    final url = Uri.parse(Endpoint.request);
    double qty = double.tryParse(_qtyUsedController.text) ?? 0.0;

    final Map<String, dynamic> data = {
      'Summary': _summaryController.text,
      'Priority': isFullAccess ? _priorityMap[_selectedPriority] : '5', // 5 es Media por defecto
      'R_RequestType_ID': {'id': _requestTypeMap[_selectedType!]},
      'R_Status_ID': {'id': isFullAccess ? (_statusIdMap[_selectedStatus] ?? openStatusId) : openStatusId},
    };

    if (orderId != null) {
      data['C_Order_ID'] = {'id': orderId};
    }

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
      try {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final newId = data['id'];
        if (newId != null) {
          // Subir archivos adjuntos
          final tableName = '${Endpoint.baseUrl}/api/v1/models/R_Request';
          for (var file in _evidences) {
            if (file != null && file.bytes != null) {
              final convertedFile = {'title': file.name, 'base64': base64Encode(file.bytes!)};
              await postAttachments(recordID: newId, tableName: tableName, convertedFile: convertedFile);
            }
          }

          await GlobalCache.syncSingleRequest(newId);
        }
      } catch (_) {}

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
              const SizedBox(height: 12),
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
                        isDisabled: false,
                        displayText: _selectedBpId != null && _bPartnersList.any((bp) => bp['id'] == _selectedBpId) ? _bPartnersList.firstWhere((bp) => bp['id'] == _selectedBpId)['Name'] ?? '' : '',
                        errorMessage: _selectedBpId == null ? 'Debe seleccionar un tercero.' : null,
                        onTap: () => _openSearchModal<int>(
                          title: 'Tercero',
                          items: _bPartnersList.where((bp) => bp['id'] != null).toList(),
                          currentValue: _selectedBpId,
                          getTitle: (item) => item['Name'] ?? 'Sin Nombre',
                          getSubtitle: (item) => 'ID: ${item['id']}',
                          getValue: (item) => item['id'] as int,
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
                        hintText: _selectedBpId == null ? 'Seleccione un tercero primero' : 'Seleccione Usuario',
                        value: _selectedUserId,
                        isLoading: _isLoadingUsers,
                        isDisabled: _selectedBpId == null || _isLoadingUsers,
                        displayText: _selectedUserId != null && _users.any((u) => (u['AD_User_ID'] ?? u['id']) == _selectedUserId) ? _users.firstWhere((u) => (u['AD_User_ID'] ?? u['id']) == _selectedUserId)['Name'] ?? '' : '',
                        onTap: () => _openSearchModal<int>(
                          title: 'Usuario',
                          items: _users.where((u) => (u['AD_User_ID'] ?? u['id']) != null).toList(),
                          currentValue: _selectedUserId,
                          getTitle: (item) => item['Name'] ?? 'Sin Nombre',
                          getSubtitle: (item) => 'ID: ${item['AD_User_ID'] ?? item['id']}',
                          getValue: (item) => (item['AD_User_ID'] ?? item['id']) as int,
                          onSelected: (val) => setState(() => _selectedUserId = val),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildSearchableField<String>(
                        label: 'Tipo de Solicitud',
                        hintText: 'Seleccione Tipo',
                        value: _selectedType,
                        isLoading: _isLoadingTypes,
                        isDisabled: false,
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
                        isDisabled: false,
                        displayText: _selectedCategory ?? '',
                        onTap: () => _openSearchModal<String>(title: 'Categoría', items: _categoryMap.keys.toList(), currentValue: _selectedCategory, getTitle: (item) => item.toString(), getValue: (item) => item.toString(), onSelected: (val) => setState(() => _selectedCategory = val)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ], // Cierre correcto del isFullAccess
              CustomTextField(controller: _emailSubjectController, label: 'Asunto'),
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
                        isDisabled: false,
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
                        isDisabled: false,
                        displayText: _selectedSalesRepId != null && _salesReps.any((u) => u['id'] == _selectedSalesRepId) ? _salesReps.firstWhere((u) => u['id'] == _selectedSalesRepId)['Name'] ?? '' : '',
                        onTap: () => _openSearchModal<int>(title: 'Representante Comercial', items: _salesReps, currentValue: _selectedSalesRepId, getTitle: (item) => item['Name'] ?? 'Sin Nombre', getSubtitle: (item) => 'ID: ${item['id']}', getValue: (item) => item['id'] as int, onSelected: (val) => setState(() => _selectedSalesRepId = val)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              CustomTextField(controller: _emailSubjectController, label: 'Asunto'),
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
                        isDisabled: false,
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
                        isLoading: _isLoadingSalesReps, // Usar el estado de carga correcto
                        isDisabled: false,
                        displayText: _selectedSalesRepId != null && _salesReps.any((u) => u['id'] == _selectedSalesRepId) ? _salesReps.firstWhere((u) => u['id'] == _selectedSalesRepId)['Name'] ?? '' : '', // Usar la lista correcta
                        onTap: () => _openSearchModal<int>(
                          title: 'Representante Comercial',
                          items: _salesReps, // Usar la lista correcta
                          currentValue: _selectedSalesRepId,
                          getTitle: (item) => item['Name'] ?? 'Sin Nombre',
                          getSubtitle: (item) => 'ID: ${item['id']}',
                          getValue: (item) => item['id'] as int,
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
                        value: _selectedStatus,
                        isLoading: _isLoadingStatuses,
                        isDisabled: false,
                        displayText: _selectedStatus,
                        onTap: () => _openSearchModal<String>(title: 'Estado', items: _statusIdMap.keys.toList(), currentValue: _selectedStatus, getTitle: (item) => item.toString(), getValue: (item) => item.toString(), onSelected: (val) => setState(() => _selectedStatus = val)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSearchableField<String>(
                        label: 'Prioridad',
                        hintText: 'Seleccione Prioridad',
                        value: _selectedPriority,
                        isLoading: false,
                        isDisabled: false,
                        displayText: _selectedPriority,
                        onTap: () => _openSearchModal<String>(title: 'Prioridad', items: _priorityMap.keys.toList(), currentValue: _selectedPriority, getTitle: (item) => item.toString(), getValue: (item) => item.toString(), onSelected: (val) => setState(() => _selectedPriority = val)),
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
              const SizedBox(height: 24),
              const Text('Adjuntos (Opcional, hasta 4 archivos):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              _buildEvidenceField(0),
              _buildEvidenceField(1),
              _buildEvidenceField(2),
              _buildEvidenceField(3),
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
