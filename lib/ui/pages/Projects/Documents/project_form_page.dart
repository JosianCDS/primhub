import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/Shared_Custom/custom_container.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';

class ProjectFormPage extends StatefulWidget {
  final Map<String, dynamic>? project;
  const ProjectFormPage({super.key, this.project});

  @override
  State<ProjectFormPage> createState() => _ProjectFormPageState();
}

class _ProjectFormPageState extends State<ProjectFormPage> {
  final _formKey = GlobalKey<FormState>();
  final ProjectsLogic _logic = ProjectsLogic();
  bool _isLoading = false;
  bool get _isNewProject => widget.project == null;
  bool get _isReactivation => !_isNewProject;

  // --- Controllers ---
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _valueController = TextEditingController();
  final _dateContractController = TextEditingController();
  final _dateFinishController = TextEditingController();
  final _bPartnerController = TextEditingController();
  final _salesRepController = TextEditingController();
  final _currencyController = TextEditingController();
  final _invoiceRuleController = TextEditingController();
  final _warehouseController = TextEditingController();
  final _priceListController = TextEditingController();
  final _paymentTermController = TextEditingController();

  final _plannedAmtController = TextEditingController(text: '0.00');
  final _plannedQtyController = TextEditingController(text: '0');
  final _plannedMarginAmtController = TextEditingController(text: '0.00');
  final _committedAmtController = TextEditingController(text: '0.00');
  final _committedQtyController = TextEditingController(text: '0');
  final _invoicedAmtController = TextEditingController(text: '0.00');
  final _invoicedQtyController = TextEditingController(text: '0');
  final _projectBalanceController = TextEditingController(text: '0.00');

  // --- Estado de IDs ---
  int? _cBPartnerId;
  int? _cBPartnerSrId;
  dynamic _cCurrencyId;
  int? _mWarehouseId;
  int? _mPriceListVersionId;
  int? _cPaymentTermId;
  String? _projInvoiceRule;
  bool _isActive = true;
  DateTime? _dateContract;
  DateTime? _dateFinish;

  List<dynamic> _bPartners = [];
  List<dynamic> _users = [];
  List<dynamic> _currencies = [];
  List<dynamic> _warehouses = [];
  List<dynamic> _priceLists = [];
  List<dynamic> _paymentTerms = [];
  List<Map<String, String>> _invoiceRules = [];

  @override
  void initState() {
    super.initState();
    if (widget.project != null) {
      _initValues();
    } else {
      _isActive = true;
      if (User.userID != null) _cBPartnerSrId = User.userID;
    }
    _loadDependencies();
  }

  @override
  void dispose() {
    final all = [
      _nameController,
      _descriptionController,
      _valueController,
      _dateContractController,
      _dateFinishController,
      _bPartnerController,
      _salesRepController,
      _currencyController,
      _invoiceRuleController,
      _warehouseController,
      _priceListController,
      _paymentTermController,
      _plannedAmtController,
      _plannedQtyController,
      _plannedMarginAmtController,
      _committedAmtController,
      _committedQtyController,
      _invoicedAmtController,
      _invoicedQtyController,
      _projectBalanceController,
    ];
    for (var c in all) c.dispose();
    super.dispose();
  }

  int? _parseId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is Map) return _parseId(value['id']);
    return int.tryParse(value.toString());
  }

  void _validateForm() {
    if (_formKey.currentState != null) {
      _formKey.currentState!.validate();
    }
  }

  void _initValues() {
    final p = widget.project!;
    _nameController.text = p['Name'] ?? '';
    _descriptionController.text = p['Description'] ?? '';
    _valueController.text = p['Value'] ?? '';
    _isActive = p['IsActive'] ?? true;
    _dateContract = p['DateContract'] != null ? DateTime.tryParse(p['DateContract']) : null;
    _dateFinish = p['DateFinish'] != null ? DateTime.tryParse(p['DateFinish']) : null;

    _cBPartnerId = _parseId(p['C_BPartner_ID']);
    _bPartnerController.text = p['C_BPartner_ID']?['identifier'] ?? '';
    _cBPartnerSrId = _parseId(p['SalesRep_ID'] ?? p['C_BPartnerSR_ID']);
    _salesRepController.text = p['SalesRep_ID']?['identifier'] ?? p['C_BPartnerSR_ID']?['identifier'] ?? '';
    _cCurrencyId = p['C_Currency_ID'] is Map ? p['C_Currency_ID']['id'] : p['C_Currency_ID'];
    _currencyController.text = p['C_Currency_ID']?['identifier'] ?? p['C_Currency_ID']?.toString() ?? '';
    _projInvoiceRule = p['ProjInvoiceRule'] is Map ? p['ProjInvoiceRule']['id'] : p['ProjInvoiceRule'];

    _plannedAmtController.text = (p['PlannedAmt'] ?? 0.0).toString();
    _plannedQtyController.text = (p['PlannedQty'] ?? 0).toString();
    _projectBalanceController.text = (p['ProjectBalanceAmt'] ?? 0.0).toString();
  }

  Future<void> _loadDependencies() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([_logic.fetchBPartners(), _logic.fetchUsers(), _logic.fetchCurrencies(), _logic.fetchInvoiceRules(), _logic.fetchWarehouses(), _logic.fetchPriceLists(), _logic.fetchPaymentTerms()]);

      if (mounted) {
        setState(() {
          _bPartners = results[0];
          _users = results[1];
          _currencies = results[2];
          _warehouses = results[4];
          _priceLists = results[5];
          _paymentTerms = results[6];

          // Auto-asignar nombre del representante comercial si ya tenemos el ID (caso nuevo proyecto)
          if (_isNewProject && _cBPartnerSrId != null && _salesRepController.text.isEmpty) {
            final user = _users.firstWhere((u) => (u['AD_User_ID'] ?? u['id']) == _cBPartnerSrId, orElse: () => null);
            if (user != null) {
              _salesRepController.text = user['Name'] ?? '';
            }
          }

          final fetchedRules = results[3] as List<dynamic>;
          if (fetchedRules.isNotEmpty) {
            _invoiceRules = fetchedRules.map((r) => {'id': r['Value'].toString(), 'name': r['Name']?.toString() ?? r['Value'].toString()}).toList();
          } else {
            // FALLBACK: Opciones que se ven en tu imagen de iDempiere web (image_55ccef.png)
            _invoiceRules = [
              {'id': 'I', 'name': 'Cant. Comprometida'},
              {'id': 'P', 'name': 'Cant. de Producto'},
              {'id': 'N', 'name': 'Ninguno'},
              {'id': 'T', 'name': 'Tiempo y Material'},
            ];
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    // Validar campos obligatorios: Nombre y Código (vía form), Tercero, Rep. Comercial, Regla Factura, Moneda
    bool missingMandatory = _cBPartnerId == null || _cBPartnerSrId == null || _projInvoiceRule == null || _cCurrencyId == null;

    if (!_formKey.currentState!.validate() || missingMandatory) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Llene los campos obligatorios'), backgroundColor: Colors.orange));
      return; // Detiene la ejecución aquí
    }

    setState(() => _isLoading = true);

    double _pDouble(String text) => double.tryParse(text.replaceAll(',', '.')) ?? 0.0;

    final Map<String, dynamic> data = {
      "Name": _nameController.text.trim(),
      "Description": _descriptionController.text.trim(),
      "Value": _valueController.text.trim(),
      "IsActive": _isActive,
      "ProjectLineLevel": "T",
      if (_dateContract != null) "DateContract": "${_dateContract!.toIso8601String().split('T')[0]} 00:00:00.0",
      if (_dateFinish != null) "DateFinish": "${_dateFinish!.toIso8601String().split('T')[0]} 00:00:00.0",

      // Ahora estamos seguros de que _cBPartnerId no es null
      "C_BPartner_ID": {"id": _cBPartnerId},
      "SalesRep_ID": _cBPartnerSrId != null ? {"id": _cBPartnerSrId} : null,
      "C_Currency_ID": _cCurrencyId != null ? {"id": _cCurrencyId} : null,
      "ProjInvoiceRule": _projInvoiceRule,

      if (_mWarehouseId != null) "M_Warehouse_ID": {"id": _mWarehouseId},
      if (_mPriceListVersionId != null) "M_PriceList_Version_ID": {"id": _mPriceListVersionId},
      if (_cPaymentTermId != null) "C_PaymentTerm_ID": {"id": _cPaymentTermId},

      "PlannedAmt": _pDouble(_plannedAmtController.text),
      "PlannedQty": _pDouble(_plannedQtyController.text),
      "PlannedMarginAmt": _pDouble(_plannedMarginAmtController.text),
      "CommittedAmt": _pDouble(_committedAmtController.text),
      "CommittedQty": _pDouble(_committedQtyController.text),
      "InvoicedAmt": _pDouble(_invoicedAmtController.text),
      "InvoicedQty": _pDouble(_invoicedQtyController.text),
      "ProjectBalanceAmt": _pDouble(_projectBalanceController.text),
    };

    final result = await _logic.saveProject(data, id: widget.project?['id']);
    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        Navigator.pop(context, true);
      } else {
        String errorMsg = result['error'].toString();
        if (errorMsg.contains('NotUnique') || errorMsg.contains('duplicate')) {
          errorMsg = 'Ya existe este proyecto';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNewProject ? 'Nuevo Proyecto' : 'Editar Proyecto'),
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 15), // El botón ahora se activará más fácil
              child: CustomButton(text: 'Guardar', onPressed: _save),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  CustomContainer(
                    title: 'Información General',
                    child: Column(
                      children: [
                        CustomTextField(controller: _nameController, label: 'Nombre del Proyecto *', validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null),
                        const SizedBox(height: 16),
                        CustomTextField(controller: _valueController, label: 'Código (Opcional)'),
                        SwitchListTile(title: const Text('Activo'), value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomContainer(
                    title: 'Maestros y Responsables',
                    child: Column(
                      children: [
                        _buildSearchField(
                          label: 'Tercero (Cliente) *',
                          controller: _bPartnerController,
                          items: _bPartners,
                          idKey: 'C_BPartner_ID',
                          onSelected: (id, name) => setState(() {
                            _cBPartnerId = _parseId(id);
                            _bPartnerController.text = name;
                          }),
                        ),
                        const SizedBox(height: 16),
                        _buildSearchField(
                          label: 'Representante Comercial *',
                          controller: _salesRepController,
                          items: _users,
                          idKey: 'AD_User_ID',
                          onSelected: _isReactivation
                              ? (id, name) {}
                              : (id, name) => setState(() {
                                  _cBPartnerSrId = _parseId(id);
                                  _salesRepController.text = name;
                                  _validateForm();
                                }),
                        ),
                        const SizedBox(height: 16),
                        _buildSearchField(
                          label: 'Regla de Factura *',
                          controller: _invoiceRuleController,
                          items: _invoiceRules,
                          idKey: 'id',
                          displayKey: 'name',
                          onSelected: _isReactivation
                              ? (id, name) {}
                              : (id, name) => setState(() {
                                  _projInvoiceRule = id.toString();
                                  _invoiceRuleController.text = name;
                                  _validateForm();
                                }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomContainer(
                    title: 'Fechas y Moneda',
                    child: Column(
                      children: [
                        _buildSearchField(
                          label: 'Moneda *',
                          controller: _currencyController,
                          items: _currencies,
                          idKey: 'C_Currency_ID',
                          displayKey: 'ISO_Code',
                          onSelected: _isReactivation
                              ? (id, name) {}
                              : (id, name) => setState(() {
                                  _cCurrencyId = id is Map ? id['id'] : int.tryParse(id.toString());
                                  _currencyController.text = name;
                                  _validateForm();
                                }),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildDatePicker('Fecha Contrato', _dateContract, (d) => setState(() => _dateContract = d))),
                            const SizedBox(width: 16),
                            Expanded(child: _buildDatePicker('Fecha Terminación', _dateFinish, (d) => setState(() => _dateFinish = d))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomContainer(
                    title: 'Detalles Financieros',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(controller: _plannedAmtController, label: 'Importe Planeado', keyboardType: TextInputType.number, readOnly: _isReactivation),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(controller: _plannedQtyController, label: 'Cantidad Planeada', keyboardType: TextInputType.number, readOnly: _isReactivation),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(controller: _committedAmtController, label: 'Importe Comprometido', keyboardType: TextInputType.number, readOnly: _isReactivation),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(controller: _committedQtyController, label: 'Cantidad Comprometida', keyboardType: TextInputType.number, readOnly: _isReactivation),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(controller: _invoicedAmtController, label: 'Importe Facturado', keyboardType: TextInputType.number, readOnly: _isReactivation),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(controller: _invoicedQtyController, label: 'Cantidad Facturada', keyboardType: TextInputType.number, readOnly: _isReactivation),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(controller: _plannedMarginAmtController, label: 'Margen Planeado', keyboardType: TextInputType.number, readOnly: _isReactivation),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(controller: _projectBalanceController, label: 'Balance del Proyecto', keyboardType: TextInputType.number, readOnly: true),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSearchField({required String label, required TextEditingController controller, required List<dynamic> items, required String idKey, String displayKey = 'Name', required Function(dynamic, String) onSelected}) {
    return GestureDetector(
      onTap: () {
        // Validación: si la lista está vacía, avisar al usuario
        if (items.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cargando datos de $label...')));
          return;
        }
        _showSearchModal(label, items, idKey, displayKey, onSelected);
      },
      child: AbsorbPointer(
        child: CustomTextField(
          controller: controller,
          label: label,
          prefixIcon: const Icon(Icons.search, color: Colors.blue),
        ),
      ),
    );
  }

  void _showSearchModal(String title, List<dynamic> items, String idKey, String displayKey, Function(dynamic, String) onSelected) {
    showDialog(
      context: context,
      builder: (context) {
        String filter = "";
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = items.where((i) => (i[displayKey] ?? '').toString().toLowerCase().contains(filter.toLowerCase())).toList();

            return CustomModal(
              title: 'Seleccionar $title',
              content: SizedBox(
                width: double.maxFinite,
                height: 450,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(hintText: 'Filtrar...', prefixIcon: Icon(Icons.filter_list)),
                      onChanged: (v) => setModalState(() => filter = v),
                    ),
                    const Divider(),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text("No se encontraron resultados"))
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                return ListTile(
                                  title: Text(item[displayKey]?.toString() ?? 'Sin nombre'),
                                  subtitle: Text("ID: ${item[idKey] ?? item['id'] ?? 'N/A'}"), // Auxiliar visual
                                  onTap: () {
                                    // LÓGICA DE RESCATE:
                                    // Si item[idKey] es nulo, intentamos con item['id']
                                    final selectedId = item[idKey] ?? item['id'];

                                    onSelected(selectedId, item[displayKey].toString());
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDatePicker(String label, DateTime? selectedDate, Function(DateTime) onSelected, {bool readOnly = false}) {
    final controller = TextEditingController(text: selectedDate != null ? "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}" : '');
    return GestureDetector(
      onTap: () async {
        if (readOnly) return;
        final date = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (date != null) {
          onSelected(date);
          controller.text = "${date.day}/${date.month}/${date.year}";
        }
      },
      child: AbsorbPointer(
        child: CustomTextField(controller: controller, label: label, prefixIcon: const Icon(Icons.calendar_today, size: 20)),
      ),
    );
  }
}
