import 'package:primhub/ui/Shared_Custom/custom_toast.dart';

import 'package:flutter/material.dart';

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
  bool _isActive = true;
  String _projectLineLevel = 'P';

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
  DateTime? _dateContract;
  DateTime? _dateFinish;

  List<dynamic> _bPartners = [];
  List<dynamic> _users = [];
  List<dynamic> _currencies = [];

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
    for (var c in all) {
      c.dispose();
    }
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
    _dateContract = p['DateContract'] != null
        ? DateTime.tryParse(p['DateContract'])
        : null;
    _dateFinish = p['DateFinish'] != null
        ? DateTime.tryParse(p['DateFinish'])
        : null;

    _cBPartnerId = _parseId(p['C_BPartner_ID']);
    _bPartnerController.text = p['C_BPartner_ID']?['identifier'] ?? '';
    _cBPartnerSrId = _parseId(p['SalesRep_ID'] ?? p['C_BPartnerSR_ID']);
    _salesRepController.text =
        p['SalesRep_ID']?['identifier'] ??
        p['C_BPartnerSR_ID']?['identifier'] ??
        '';
    _cCurrencyId = p['C_Currency_ID'] is Map
        ? p['C_Currency_ID']['id']
        : p['C_Currency_ID'];
    _currencyController.text =
        p['C_Currency_ID']?['identifier'] ??
        p['C_Currency_ID']?.toString() ??
        '';
    _projInvoiceRule = p['ProjInvoiceRule'] is Map
        ? p['ProjInvoiceRule']['id']
        : p['ProjInvoiceRule'];

    _plannedAmtController.text = (p['PlannedAmt'] ?? 0.0).toString();
    _plannedQtyController.text = (p['PlannedQty'] ?? 0).toString();
    _plannedMarginAmtController.text = (p['PlannedMarginAmt'] ?? 0.0).toString();
    _committedAmtController.text = (p['CommittedAmt'] ?? 0.0).toString();
    _committedQtyController.text = (p['CommittedQty'] ?? 0).toString();
    _invoicedAmtController.text = (p['InvoicedAmt'] ?? 0.0).toString();
    _invoicedQtyController.text = (p['InvoicedQty'] ?? 0).toString();
    _projectBalanceController.text = (p['ProjectBalanceAmt'] ?? 0.0).toString();

    _projectLineLevel = p['ProjectLineLevel']?['id'] ?? 'P';

    _cPaymentTermId = _parseId(p['C_PaymentTerm_ID']);
    _paymentTermController.text = p['C_PaymentTerm_ID']?['identifier'] ?? '';
  }

  Future<void> _loadDependencies() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _logic.fetchBPartners(),
        _logic.fetchUsers(),
        _logic.fetchCurrencies(),
        _logic.fetchInvoiceRules(),
        _logic.fetchWarehouses(),
        _logic.fetchPriceLists(),
        _logic.fetchPaymentTerms(),
      ]);

      if (mounted) {
        setState(() {
          _bPartners = results[0];
          _users = results[1];
          _currencies = results[2];

          _paymentTerms = results[6];

          // Auto-asignar nombre del representante comercial si ya tenemos el ID (caso nuevo proyecto)
          if (_isNewProject &&
              _cBPartnerSrId != null &&
              _salesRepController.text.isEmpty) {
            final user = _users.firstWhere(
              (u) => (u['AD_User_ID'] ?? u['id']) == _cBPartnerSrId,
              orElse: () => null,
            );
            if (user != null) {
              _salesRepController.text = user['Name'] ?? '';
            }
          }

          final fetchedRules = results[3];
          if (fetchedRules.isNotEmpty) {
            _invoiceRules = fetchedRules
                .map(
                  (r) => {
                    'id': r['Value'].toString(),
                    'name': r['Name']?.toString() ?? r['Value'].toString(),
                  },
                )
                .toList();
          } else {
            // FALLBACK: Opciones que se ven en tu imagen de iDempiere web (image_55ccef.png)
            _invoiceRules = [
              {'id': 'I', 'name': 'Cant. Comprometida'},
              {'id': 'P', 'name': 'Cant. de Producto'},
              {'id': '-', 'name': 'Ninguno'},
              {'id': 'T', 'name': 'Tiempo y Material'},
            ];
          }

          if (_isNewProject) {
            if (_cCurrencyId == null) {
              final balboa = _currencies.firstWhere((c) => c['id'] == 197 || c['C_Currency_ID'] == 197, orElse: () => null);
              if (balboa != null) {
                _cCurrencyId = balboa['id'] ?? balboa['C_Currency_ID'];
                _currencyController.text = balboa['ISO_Code'] ?? balboa['identifier'] ?? 'Balboa';
              } else {
                _cCurrencyId = 197;
                _currencyController.text = 'Balboa';
              }
            }
            if (_projInvoiceRule == null) {
              String ruleId = '-';
              String ruleName = 'Ninguno';
              
              for (final r in _invoiceRules) {
                if (r['id'] == '-' || r['name'] == 'Ninguno') {
                  ruleId = r['id'] ?? '-';
                  ruleName = r['name'] ?? 'Ninguno';
                  break;
                }
              }
              
              _projInvoiceRule = ruleId;
              _invoiceRuleController.text = ruleName;
            }
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
    bool missingMandatory =
        _cBPartnerId == null ||
        _cBPartnerSrId == null ||
        _projInvoiceRule == null ||
        _cCurrencyId == null;

    if (!_formKey.currentState!.validate() || missingMandatory) {
      ToastMessage.show(context: context, message: 'Llene los campos obligatorios', type: ToastType.warning);
      return; // Detiene la ejecución aquí
    }

    setState(() => _isLoading = true);

    double pDouble(String text) =>
        double.tryParse(text.replaceAll(',', '.')) ?? 0.0;

    final Map<String, dynamic> data = {
      "Name": _nameController.text.trim(),
      "Description": _descriptionController.text.trim(),
      "Value": _valueController.text.trim(),
      "IsActive": _isActive,
      "ProjectLineLevel": _projectLineLevel,
      if (_dateContract != null)
        "DateContract":
            "${_dateContract!.toIso8601String().split('T')[0]} 00:00:00.0",
      if (_dateFinish != null)
        "DateFinish":
            "${_dateFinish!.toIso8601String().split('T')[0]} 00:00:00.0",

      // Ahora estamos seguros de que _cBPartnerId no es null
      "C_BPartner_ID": {"id": _cBPartnerId},
      "SalesRep_ID": _cBPartnerSrId != null ? {"id": _cBPartnerSrId} : null,
      "C_Currency_ID": _cCurrencyId != null ? {"id": _cCurrencyId} : null,
      "ProjInvoiceRule": _projInvoiceRule,

      if (_mWarehouseId != null) "M_Warehouse_ID": {"id": _mWarehouseId},
      if (_mPriceListVersionId != null)
        "M_PriceList_Version_ID": {"id": _mPriceListVersionId},
      if (_cPaymentTermId != null) "C_PaymentTerm_ID": {"id": _cPaymentTermId},

      "PlannedAmt": pDouble(_plannedAmtController.text),
      "PlannedQty": pDouble(_plannedQtyController.text),
      "PlannedMarginAmt": pDouble(_plannedMarginAmtController.text),
      "CommittedAmt": pDouble(_committedAmtController.text),
      "CommittedQty": pDouble(_committedQtyController.text),
      "InvoicedAmt": pDouble(_invoicedAmtController.text),
      "InvoicedQty": pDouble(_invoicedQtyController.text),
      "ProjectBalanceAmt": pDouble(_projectBalanceController.text),
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
        ToastMessage.show(context: context, message: errorMsg, type: ToastType.failure);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _isNewProject ? 'Nuevo Proyecto' : 'Editar Proyecto',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CustomButton(text: 'Guardar', onPressed: _save),
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Column(
                          children: [
                            _buildGeneralInfoSection(),
                            const SizedBox(height: 24),
                            _buildMastersSection(),
                            const SizedBox(height: 24),
                            _buildDatesAndCurrencySection(),
                            const SizedBox(height: 24),
                            _buildFinancialDetailsSection(),
                            const SizedBox(height: 24),
                            _buildHistorySection(),
                            const SizedBox(height: 48),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: colorScheme.primary, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralInfoSection() {
    return CustomContainer(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Información General',
            Icons.info_outline_rounded,
          ),
          const SizedBox(height: 24),
          CustomTextField(
            controller: _nameController,
            label: 'Nombre del Proyecto *',
            prefixIcon: const Icon(
              Icons.drive_file_rename_outline_rounded,
              size: 20,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'El nombre es obligatorio'
                : null,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _descriptionController,
            label: 'Descripción',
            prefixIcon: const Icon(Icons.description_outlined, size: 20),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _valueController,
                  label: 'Código (Opcional)',
                  prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                ),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Activo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  Switch.adaptive(
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMastersSection() {
    return CustomContainer(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Maestros y Responsables',
            Icons.people_outline_rounded,
          ),
          const SizedBox(height: 24),
          _buildSearchField(
            label: 'Tercero (Cliente) *',
            controller: _bPartnerController,
            items: _bPartners,
            idKey: 'C_BPartner_ID',
            icon: Icons.business_rounded,
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
            icon: Icons.person_search_rounded,
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
            label: 'Término de Pago',
            controller: _paymentTermController,
            items: _paymentTerms,
            idKey: 'id',
            displayKey: 'Name',
            icon: Icons.payment_rounded,
            onSelected: (id, name) => setState(() {
              _cPaymentTermId = _parseId(id);
              _paymentTermController.text = name;
            }),
          ),
          const SizedBox(height: 16),
          _buildSearchField(
            label: 'Regla de Factura *',
            controller: _invoiceRuleController,
            items: _invoiceRules,
            idKey: 'id',
            displayKey: 'name',
            icon: Icons.rule_rounded,
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
    );
  }

  Widget _buildDatesAndCurrencySection() {
    return CustomContainer(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Fechas y Moneda', Icons.calendar_month_rounded),
          const SizedBox(height: 24),
          _buildSearchField(
            label: 'Moneda *',
            controller: _currencyController,
            items: _currencies,
            idKey: 'C_Currency_ID',
            displayKey: 'ISO_Code',
            icon: Icons.currency_exchange_rounded,
            onSelected: _isReactivation
                ? (id, name) {}
                : (id, name) => setState(() {
                    _cCurrencyId = id is Map
                        ? id['id']
                        : int.tryParse(id.toString());
                    _currencyController.text = name;
                    _validateForm();
                  }),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _projectLineLevel,
            decoration: InputDecoration(
              labelText: 'Nivel de Línea',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.account_tree_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'P', child: Text('Proyecto')),
              DropdownMenuItem(value: 'A', child: Text('Fase')),
              DropdownMenuItem(value: 'T', child: Text('Tarea')),
            ],
            onChanged: _isReactivation ? null : (val) {
              if (val != null) setState(() => _projectLineLevel = val);
            },
          ),
          const SizedBox(height: 16),
          _buildDatePicker(
            'Fecha de Inicio de proyecto',
            _dateContract,
            (d) => setState(() => _dateContract = d),
          ),
          const SizedBox(height: 16),
          _buildDatePicker(
            'Fecha Terminación',
            _dateFinish,
            (d) => setState(() => _dateFinish = d),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialDetailsSection() {
    return CustomContainer(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Totales',
            Icons.monetization_on_outlined,
          ),
          const SizedBox(height: 24),
          _buildFinancialGrid(),
        ],
      ),
    );
  }

  Widget _buildFinancialGrid() {
    final bool isWide = MediaQuery.of(context).size.width > 600;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildFinancialItem(
              'Total Planeado',
              _plannedAmtController,
              Icons.payments_outlined,
              isWide,
              constraints.maxWidth,
            ),
            _buildFinancialItem(
              'Cantidad Planeada',
              _plannedQtyController,
              Icons.inventory_2_outlined,
              isWide,
              constraints.maxWidth,
            ),
            _buildFinancialItem(
              'Total Comprometido',
              _committedAmtController,
              Icons.handshake_outlined,
              isWide,
              constraints.maxWidth,
            ),
            _buildFinancialItem(
              'Cantidad Cometida',
              _committedQtyController,
              Icons.assignment_turned_in_outlined,
              isWide,
              constraints.maxWidth,
            ),
            _buildFinancialItem(
              'Margen Planeado',
              _plannedMarginAmtController,
              Icons.trending_up_rounded,
              isWide,
              constraints.maxWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildHistorySection() {
    return CustomContainer(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Historia',
            Icons.history_rounded,
          ),
          const SizedBox(height: 24),
          _buildHistoryGrid(),
          const SizedBox(height: 20),
          CustomTextField(
            controller: _projectBalanceController,
            label: 'Balance del Proyecto',
            prefixIcon: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.green,
              size: 20,
            ),
            keyboardType: TextInputType.number,
            readOnly: _isReactivation,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryGrid() {
    final bool isWide = MediaQuery.of(context).size.width > 600;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildFinancialItem(
              'Cuenta Facturada',
              _invoicedAmtController,
              Icons.receipt_long_outlined,
              isWide,
              constraints.maxWidth,
            ),
            _buildFinancialItem(
              'Cantidad Facturada',
              _invoicedQtyController,
              Icons.fact_check_outlined,
              isWide,
              constraints.maxWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildFinancialItem(
    String label,
    TextEditingController controller,
    IconData icon,
    bool isWide,
    double maxWidth,
  ) {
    return SizedBox(
      width: isWide ? (maxWidth - 16) / 2 : maxWidth,
      child: CustomTextField(
        controller: controller,
        label: label,
        prefixIcon: Icon(icon, size: 20),
        keyboardType: TextInputType.number,
        readOnly: _isReactivation,
      ),
    );
  }

  Widget _buildSearchField({
    required String label,
    required TextEditingController controller,
    required List<dynamic> items,
    required String idKey,
    String displayKey = 'Name',
    required Function(dynamic, String) onSelected,
    IconData icon = Icons.search,
  }) {
    return GestureDetector(
      onTap: () {
        if (items.isEmpty) {
          ToastMessage.show(context: context, message: 'Cargando datos de $label...', type: ToastType.help);
          return;
        }
        _showSearchModal(label, items, idKey, displayKey, onSelected);
      },
      child: AbsorbPointer(
        child: CustomTextField(
          controller: controller,
          label: label,
          prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }

  void _showSearchModal(
    String title,
    List<dynamic> items,
    String idKey,
    String displayKey,
    Function(dynamic, String) onSelected,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        String filter = "";
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = items
                .where(
                  (i) => (i[displayKey] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(filter.toLowerCase()),
                )
                .toList();

            return CustomModal(
              title: 'Seleccionar $title',
              content: SizedBox(
                width: double.maxFinite,
                height: 450,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Filtrar...',
                        prefixIcon: Icon(Icons.filter_list),
                      ),
                      onChanged: (v) => setModalState(() => filter = v),
                    ),
                    const Divider(),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text("No se encontraron resultados"),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                return ListTile(
                                  title: Text(
                                    item[displayKey]?.toString() ??
                                        'Sin nombre',
                                  ),
                                  onTap: () {
                                    final selectedId =
                                        item[idKey] ?? item['id'];
                                    onSelected(
                                      selectedId,
                                      item[displayKey].toString(),
                                    );
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

  Widget _buildDatePicker(
    String label,
    DateTime? selectedDate,
    Function(DateTime) onSelected, {
    bool readOnly = false,
  }) {
    final controller = TextEditingController(
      text: selectedDate != null
          ? "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}"
          : '',
    );
    return GestureDetector(
      onTap: () async {
        if (readOnly) return;
        final date = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (date != null) {
          onSelected(date);
          controller.text = "${date.day}/${date.month}/${date.year}";
        }
      },
      child: AbsorbPointer(
        child: CustomTextField(
          controller: controller,
          label: label,
          prefixIcon: Icon(
            Icons.calendar_today,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
