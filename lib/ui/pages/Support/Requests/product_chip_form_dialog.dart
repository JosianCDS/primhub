import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:primhub/api/global_cache.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/ui/Shared_Custom/customToast.dart';
import 'package:primhub/ui/pages/Support/Requests/product_chip_functions.dart';

class ProductChipFormDialog extends StatefulWidget {
  const ProductChipFormDialog({super.key});

  @override
  State<ProductChipFormDialog> createState() => _ProductChipFormDialogState();
}

class _ProductChipFormDialogState extends State<ProductChipFormDialog> {
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = true;
  bool _isSaving = false;

  Future<void> _openSearchModal<T>({
    required String title,
    required List<dynamic> items,
    required T? currentValue,
    required String Function(dynamic) getTitle,
    String Function(dynamic)? getSubtitle,
    required T Function(dynamic) getValue,
    required void Function(T) onSelected,
  }) async {
    final double dialogHeight = MediaQuery.of(context).size.height * 0.6;
    final T? result = await showDialog<T>(
      context: context,
      builder: (context) {
        String searchQuery = '';
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          insetAnimationDuration: Duration.zero,
          child: Container(
            width: 400,
            height: dialogHeight,
            padding: const EdgeInsets.all(20),
            child: StatefulBuilder(
              builder: (context, setStateDialog) {
                final filteredItems = items.where((item) {
                  return getTitle(item).toLowerCase().contains(searchQuery.toLowerCase());
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seleccionar $title *',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
                    ),
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
                            subtitle: getSubtitle != null
                                ? Text(getSubtitle(item), style: const TextStyle(fontSize: 12, color: Colors.grey))
                                : null,
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

  Widget _buildSearchableField<T>({
    required String label,
    required String? hintText,
    required T? value,
    required bool isLoading,
    required bool isDisabled,
    required String displayText,
    required VoidCallback onTap,
    IconData? prefixIcon,
  }) {
    return InkWell(
      onTap: (isLoading || isDisabled) ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Theme.of(context).colorScheme.primary) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          suffixIcon: isLoading
              ? Transform.scale(
                  scale: 0.5,
                  child: const CircularProgressIndicator(strokeWidth: 3),
                )
              : const Icon(Icons.search),
        ),
        isEmpty: value == null,
        child: Text(
          value == null ? (hintText ?? '') : displayText,
          style: TextStyle(
            fontSize: 16,
            color: (isLoading || isDisabled || value == null)
                ? Colors.grey[600]
                : Theme.of(context).colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // Selected values
  int? _selectedBPartnerId;
  int? _selectedContactId;
  int? _selectedProductId;
  String? _selectedFrequencyType;
  int? _selectedPriceListId;

  // Form Fields
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _contractNoController = TextEditingController();
  
  DateTime? _serviceStartDate;
  DateTime? _serviceFinishDate;

  // Lists
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _frequencies = [];
  List<Map<String, dynamic>> _priceLists = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _descriptionController.dispose();
    _contractNoController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    
    // Ejecutar en paralelo las llamadas a la API que no dependen del BPartner
    final results = await Future.wait([
      fetchSupportProducts(),
      fetchPriceLists(),
      fetchFrequencyTypes(),
    ]);

    if (!mounted) return;

    setState(() {
      _products = results[0];
      _priceLists = results[1];
      _frequencies = results[2];
      _isLoading = false;
    });
  }

  Future<void> _onBPartnerSelected(int? bPartnerId) async {
    if (bPartnerId == null) return;
    
    setState(() {
      _selectedBPartnerId = bPartnerId;
      _selectedContactId = null;
      _contacts = [];
    });

    final contacts = await fetchContactsForBPartner(bPartnerId);
    if (!mounted) return;
    
    setState(() {
      _contacts = contacts;
      // Auto-select if only one contact exists
      if (_contacts.length == 1) {
        _selectedContactId = (_contacts.first['id'] as num?)?.toInt();
      }
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime initialDate = isStart 
        ? (_serviceStartDate ?? DateTime.now())
        : (_serviceFinishDate ?? (_serviceStartDate ?? DateTime.now()));
        
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    
    if (picked != null) {
      setState(() {
        if (isStart) {
          _serviceStartDate = picked;
          // Ensure finish date is not before start date
          if (_serviceFinishDate != null && _serviceFinishDate!.isBefore(picked)) {
            _serviceFinishDate = null;
          }
        } else {
          _serviceFinishDate = picked;
        }
      });
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_selectedBPartnerId == null) {
      ToastMessage.show(context: context, message: 'Debe seleccionar un Tercero', type: ToastType.warning);
      return;
    }
    if (_selectedContactId == null) {
      ToastMessage.show(context: context, message: 'Debe seleccionar un Contacto de Facturación', type: ToastType.warning);
      return;
    }
    if (_selectedProductId == null) {
      ToastMessage.show(context: context, message: 'Debe seleccionar un Producto', type: ToastType.warning);
      return;
    }
    if (_selectedFrequencyType == null) {
      ToastMessage.show(context: context, message: 'Debe seleccionar un Tipo de Frecuencia', type: ToastType.warning);
      return;
    }
    if (_selectedPriceListId == null) {
      ToastMessage.show(context: context, message: 'Debe seleccionar una Lista de Precios', type: ToastType.warning);
      return;
    }
    if (_serviceStartDate == null) {
      ToastMessage.show(context: context, message: 'Debe seleccionar la fecha de inicio', type: ToastType.warning);
      return;
    }

    setState(() => _isSaving = true);
    
    final qty = double.tryParse(_qtyController.text.trim()) ?? 1.0;
    
    final result = await saveProductChip(
      context: context,
      bPartnerId: _selectedBPartnerId!,
      adUserId: _selectedContactId!,
      productId: _selectedProductId!,
      qty: qty,
      description: _descriptionController.text.trim(),
      frequencyType: _selectedFrequencyType!,
      contractNo: _contractNoController.text.trim(),
      serviceStartDate: "${_serviceStartDate!.year}-${_serviceStartDate!.month.toString().padLeft(2,'0')}-${_serviceStartDate!.day.toString().padLeft(2,'0')} 00:00:00",
      serviceFinishDate: "${_serviceFinishDate!.year}-${_serviceFinishDate!.month.toString().padLeft(2,'0')}-${_serviceFinishDate!.day.toString().padLeft(2,'0')} 00:00:00",
      priceListId: _selectedPriceListId!,
    );

    if (!mounted) return;
    
    setState(() => _isSaving = false);
    
    if (result['success'] == true) {
      ToastMessage.show(context: context, message: 'Ficha de producto creada exitosamente', type: ToastType.success);
      Navigator.of(context).pop(true);
    } else {
      ToastMessage.show(context: context, message: result['message'], type: ToastType.failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const CustomModal(
        title: 'Nueva Ficha de Producto',
        content: SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        actions: [],
      );
    }

    // Preparar BPartners
    final bPartners = GlobalCache.bPartners;

    return CustomModal(
      title: 'Nueva Ficha de Producto',
      width: 1000,
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // FILA 1: Tercero y Contacto
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: _buildSearchableField<int>(
                      label: 'Tercero Asociado *',
                      hintText: 'Seleccionar...',
                      value: _selectedBPartnerId,
                      isLoading: false,
                      isDisabled: false,
                      prefixIcon: Icons.business,
                      displayText: _selectedBPartnerId != null 
                          ? (GlobalCache.bPartners.firstWhere((b) => b['id'] == _selectedBPartnerId, orElse: () => {})['Name'] ?? 'Desconocido')
                          : '',
                      onTap: () {
                        _openSearchModal<int>(
                          title: 'Tercero Asociado',
                          items: GlobalCache.bPartners,
                          currentValue: _selectedBPartnerId,
                          getTitle: (item) => item['Name'] ?? item['name'] ?? 'Desconocido',
                          getValue: (item) => (item['id'] as num).toInt(),
                          onSelected: _onBPartnerSelected,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: _buildSearchableField<int>(
                      label: 'Contacto de Facturación *',
                      hintText: 'Seleccionar...',
                      value: _selectedContactId,
                      isLoading: _isLoading,
                      isDisabled: _contacts.isEmpty,
                      prefixIcon: Icons.person_outline,
                      displayText: _selectedContactId != null
                          ? (_contacts.firstWhere((c) => c['id'] == _selectedContactId, orElse: () => {})['Name'] ?? 'Desconocido')
                          : '',
                      onTap: () {
                        _openSearchModal<int>(
                          title: 'Contacto de Facturación',
                          items: _contacts,
                          currentValue: _selectedContactId,
                          getTitle: (item) => item['Name'] ?? item['name'] ?? 'Desconocido',
                          getValue: (item) => (item['id'] as num).toInt(),
                          onSelected: (val) {
                            setState(() => _selectedContactId = val);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // FILA 2: Nombre de Ficha y Producto
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: CustomTextField(
                      controller: _descriptionController,
                      label: 'Nombre de la Ficha de Producto *',
                      prefixIcon: Icon(Icons.label_outline, color: Theme.of(context).colorScheme.primary),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: _buildSearchableField<int>(
                      label: 'Producto (Soporte) *',
                      hintText: 'Seleccionar...',
                      value: _selectedProductId,
                      isLoading: _isLoading,
                      isDisabled: _products.isEmpty,
                      prefixIcon: Icons.inventory_2_outlined,
                      displayText: _selectedProductId != null
                          ? (_products.firstWhere((p) => p['id'] == _selectedProductId, orElse: () => {})['Name'] ?? 'Desconocido')
                          : '',
                      onTap: () {
                        _openSearchModal<int>(
                          title: 'Producto (Soporte)',
                          items: _products,
                          currentValue: _selectedProductId,
                          getTitle: (item) => item['Name'] ?? item['name'] ?? 'Desconocido',
                          getValue: (item) => (item['id'] as num).toInt(),
                          onSelected: (val) {
                            setState(() => _selectedProductId = val);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // FILA 3: Cantidad y Tipo de Frecuencia
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: CustomTextField(
                      controller: _qtyController,
                      label: 'Cantidad *',
                      prefixIcon: Icon(Icons.numbers, color: Theme.of(context).colorScheme.primary),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      validator: (value) => value == null || value.trim().isEmpty ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: _buildSearchableField<String>(
                      label: 'Tipo de Frecuencia *',
                      hintText: 'Seleccionar...',
                      value: _selectedFrequencyType,
                      isLoading: _isLoading,
                      isDisabled: false,
                      prefixIcon: Icons.update,
                      displayText: _selectedFrequencyType != null
                          ? ((_frequencies.isNotEmpty ? _frequencies : [{'Value': 'M', 'Name': 'Mensual'}, {'Value': 'A', 'Name': 'Anual'}, {'Value': 'H', 'Name': 'Por Hora'}]).firstWhere((f) => f['Value'] == _selectedFrequencyType, orElse: () => {})['Name'] ?? 'Desconocido')
                          : '',
                      onTap: () {
                        _openSearchModal<String>(
                          title: 'Tipo de Frecuencia',
                          items: _frequencies.isNotEmpty ? _frequencies : [{'Value': 'M', 'Name': 'Mensual'}, {'Value': 'A', 'Name': 'Anual'}, {'Value': 'H', 'Name': 'Por Hora'}],
                          currentValue: _selectedFrequencyType,
                          getTitle: (item) => item['Name'] ?? item['name'] ?? 'Desconocido',
                          getValue: (item) => item['Value']?.toString() ?? '',
                          onSelected: (val) {
                            setState(() => _selectedFrequencyType = val);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // FILA 4: Lista de Precios y N° de Contrato
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: _buildSearchableField<int>(
                      label: 'Lista de Precios *',
                      hintText: 'Seleccionar...',
                      value: _selectedPriceListId,
                      isLoading: false,
                      isDisabled: false,
                      prefixIcon: Icons.request_quote_outlined,
                      displayText: _selectedPriceListId != null
                          ? (_priceLists.firstWhere((pl) => pl['id'] == _selectedPriceListId, orElse: () => {})['Name'] ?? 'Desconocido')
                          : '',
                      onTap: () {
                        _openSearchModal<int>(
                          title: 'Lista de Precios',
                          items: _priceLists,
                          currentValue: _selectedPriceListId,
                          getTitle: (item) => item['Name'] ?? item['name'] ?? 'Desconocido',
                          getValue: (item) => (item['id'] as num).toInt(),
                          onSelected: (val) {
                            setState(() => _selectedPriceListId = val);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: CustomTextField(
                      controller: _contractNoController,
                      label: 'N° de Contrato',
                      prefixIcon: Icon(Icons.receipt_long_outlined, color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // FILA 5: Fechas
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: InkWell(
                      onTap: () => _selectDate(context, true),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Inicio de Servicio *',
                          prefixIcon: Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.primary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        child: Text(
                          _serviceStartDate != null 
                              ? "${_serviceStartDate!.day}/${_serviceStartDate!.month}/${_serviceStartDate!.year}"
                              : 'Seleccione',
                          style: TextStyle(
                            fontSize: 16,
                            color: _serviceStartDate != null ? Theme.of(context).colorScheme.onSurface : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: InkWell(
                      onTap: () => _selectDate(context, false),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Fin de Servicio',
                          prefixIcon: Icon(Icons.event_busy, color: Theme.of(context).colorScheme.primary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        child: Text(
                          _serviceFinishDate != null 
                              ? "${_serviceFinishDate!.day}/${_serviceFinishDate!.month}/${_serviceFinishDate!.year}"
                              : 'Opcional',
                          style: TextStyle(
                            fontSize: 16,
                            color: _serviceFinishDate != null ? Theme.of(context).colorScheme.onSurface : Colors.grey[600],
                          ),
                        ),
                      ),
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
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        CustomButton(
          text: 'Crear Ficha',
          onPressed: _saveForm,
          isLoading: _isSaving,
        ),
      ],
    );
  }
}
