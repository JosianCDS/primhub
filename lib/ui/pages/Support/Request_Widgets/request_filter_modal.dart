import 'package:flutter/material.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/ui/Shared_Custom/customToast.dart';

/// Data class to hold filter state for requests.
class RequestFilterModel {
  final String? bpName;
  final List<String> levels;
  final List<String> statuses;
  final List<String> situations;
  final List<String> salesRepNames;
  final List<String> userNames;

  const RequestFilterModel({this.bpName, this.levels = const [], this.statuses = const [], this.situations = const [], this.salesRepNames = const [], this.userNames = const []});

  /// Creates a copy of this filter object with the given fields replaced with the new values.
  RequestFilterModel copyWith({ValueGetter<String?>? bpName, List<String>? levels, List<String>? statuses, List<String>? situations, List<String>? salesRepNames, List<String>? userNames}) {
    return RequestFilterModel(bpName: bpName != null ? bpName() : this.bpName, levels: levels ?? this.levels, statuses: statuses ?? this.statuses, situations: situations ?? this.situations, salesRepNames: salesRepNames ?? this.salesRepNames, userNames: userNames ?? this.userNames);
  }

  /// Calculates the number of active filters.
  int get activeFilterCount {
    int count = 0;
    if (bpName != null) count++;
    count += levels.length;
    count += statuses.length;
    count += situations.length;
    count += salesRepNames.length;
    count += userNames.length;
    return count;
  }
}

/// A reusable modal dialog for filtering requests.
class RequestFilterModal extends StatefulWidget {
  final RequestFilterModel initialFilter;
  final List<Map<String, dynamic>> bPartners;
  final List<Map<String, dynamic>> allBPartners;
  final List<dynamic> users;
  final List<Map<String, dynamic>> requests;
  final Map<String, int> statusIdMap;

  const RequestFilterModal({super.key, required this.initialFilter, required this.bPartners, required this.allBPartners, required this.users, required this.requests, required this.statusIdMap});

  @override
  State<RequestFilterModal> createState() => _RequestFilterModalState();
}

class _RequestFilterModalState extends State<RequestFilterModal> {
  late RequestFilterModel _tempFilter;

  @override
  void initState() {
    super.initState();
    _tempFilter = widget.initialFilter;
  }

  Future<void> _openSingleSelectSearchModal<T>({required String title, required List<dynamic> items, required T? currentValue, required String Function(dynamic) getTitle, String Function(dynamic)? getSubtitle, required T? Function(dynamic) getValue, required void Function(T?) onSelected}) async {
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

    if (result != null && result is Map && result['selected'] == true) {
      onSelected(result['value'] as T?);
    }
  }

  Future<void> _openMultiSelectSearchModal({required String title, required List<dynamic> items, required List<String> currentValues, required String Function(dynamic) getTitle, String? Function(dynamic)? getSubtitle, required String Function(dynamic) getValue, required void Function(List<String>) onSelected}) async {
    final List<String>? result = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return _MultiSelectSearchDialog(title: title, items: items, initialSelectedValues: currentValues, getTitle: getTitle, getSubtitle: getSubtitle, getValue: getValue);
      },
    );

    if (result != null) {
      onSelected(result);
    }
  }

  Widget _buildSingleSearchableField<T>({required String label, required String? hintText, required T? value, required bool isLoading, required bool isDisabled, required String displayText, required VoidCallback onTap}) {
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
        isEmpty: value == null && (displayText.isEmpty || displayText.startsWith('Todos los')),
        child: Text(
          (value == null || displayText.isEmpty) ? (hintText ?? '') : displayText,
          style: TextStyle(fontSize: 16, color: (isLoading || isDisabled || value == null) ? Colors.grey[600] : Theme.of(context).colorScheme.onSurface),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildMultiSearchableField({required String label, required String hintText, required List<String> values, required bool isLoading, required bool isDisabled, required VoidCallback onTap}) {
    String displayText;
    if (values.isEmpty) {
      displayText = hintText;
    } else if (values.length == 1) {
      displayText = values.first;
    } else {
      displayText = '${values.length} seleccionados';
    }

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
        isEmpty: values.isEmpty,
        child: Text(
          displayText,
          style: TextStyle(fontSize: 16, color: (isLoading || isDisabled || values.isEmpty) ? Colors.grey[600] : Theme.of(context).colorScheme.onSurface),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> modalUsers = widget.users;
    if (_tempFilter.bpName != null && _tempFilter.bpName != '__ALL__') {
      final bpData = widget.bPartners.firstWhere((bp) => bp['Name'] == _tempFilter.bpName, orElse: () => {});
      if (bpData.isNotEmpty) {
        final bpId = bpData['id'];
        modalUsers = widget.users.where((u) {
          final userBpData = u['C_BPartner_ID'];
          final uBpId = (userBpData is Map) ? userBpData['id'] : userBpData;
          return uBpId == bpId;
        }).toList();
      }
    }

    return CustomModal(
      title: 'Filtrar Solicitudes',
      width: 500,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (AccessControl.isAdmin) ...[
              _buildSingleSearchableField<String>(
                label: 'Tercero',
                hintText: 'Todos los Terceros',
                value: _tempFilter.bpName,
                isLoading: false,
                isDisabled: false,
                displayText: _tempFilter.bpName ?? 'Todos los Terceros',
                onTap: () => _openSingleSelectSearchModal<String>(
                  title: 'Tercero',
                  items: [
                    '__ALL__',
                    ...{
                      for (var bp in widget.bPartners)
                        if (bp['id'] != null) bp['id']: bp,
                    }.values,
                  ],
                  currentValue: _tempFilter.bpName,
                  getTitle: (item) => item == '__ALL__' ? 'Todos los Terceros' : (item['Name'] ?? 'Sin Nombre'),
                  getSubtitle: (item) => item == '__ALL__' ? '' : 'ID: ${item['id']}',
                  getValue: (item) => item == '__ALL__' ? null : item['Name']?.toString(),
                  onSelected: (val) {
                    setState(() {
                      // Si el tercero cambia, validamos los usuarios seleccionados
                      if (val != _tempFilter.bpName) {
                        final List<String> validatedUserNames = [];
                        List<String> removedUsers = [];
                        if (_tempFilter.userNames.isNotEmpty && val != null) {
                          final newBpData = widget.bPartners.firstWhere((bp) => bp['Name'] == val, orElse: () => {});
                          if (newBpData.isNotEmpty) {
                            final newBpId = newBpData['id'];
                            for (final userName in _tempFilter.userNames) {
                              final userRecord = widget.users.firstWhere((u) => u['Name'] == userName, orElse: () => {});
                              if (userRecord.isNotEmpty) {
                                final uBp = userRecord['C_BPartner_ID'];
                                final uBpId = (uBp is Map) ? uBp['id'] : uBp;
                                if (uBpId == newBpId) {
                                  validatedUserNames.add(userName);
                                } else {
                                  removedUsers.add(userName);
                                }
                              }
                            }
                            if (removedUsers.isNotEmpty) {
                              WidgetsBinding.instance.addPostFrameCallback((_) => ToastMessage.show(context: context, message: 'Usuarios removidos: ${removedUsers.join(", ")}', type: ToastType.help));
                            }
                          }
                        } else {
                          validatedUserNames.addAll(_tempFilter.userNames);
                        }
                        _tempFilter = _tempFilter.copyWith(bpName: () => val, userNames: validatedUserNames);
                      } else {
                        _tempFilter = _tempFilter.copyWith(bpName: () => val);
                      }
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              _buildMultiSearchableField(
                label: 'Rep. Comercial',
                hintText: 'Todos los Rep. Comerciales',
                values: _tempFilter.salesRepNames,
                isLoading: false,
                isDisabled: false,
                onTap: () => _openMultiSelectSearchModal(
                  title: 'Rep. Comercial',
                  items: widget.allBPartners.where((bp) {
                    final isRep = bp['IsSalesRep'] ?? bp['isSalesRep'] ?? bp['C_BPartner0IsSalesRep'] ?? false;
                    return isRep == 'Y' || isRep == true;
                  }).toList(),
                  currentValues: _tempFilter.salesRepNames,
                  getTitle: (item) => item['Name'] ?? 'Sin Nombre',
                  getSubtitle: (item) => 'ID: ${item['id']}',
                  getValue: (item) => item['Name']?.toString() ?? '',
                  onSelected: (vals) => setState(() => _tempFilter = _tempFilter.copyWith(salesRepNames: vals)),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _buildMultiSearchableField(
              label: 'Tipo de solicitud',
              hintText: 'Todos los Tipos',
              values: _tempFilter.situations,
              isLoading: false,
              isDisabled: false,
              onTap: () => _openMultiSelectSearchModal(
                title: 'Tipo de solicitud',
                items: widget.requests.map((e) => e['situation'].toString()).toSet().toList(),
                currentValues: _tempFilter.situations,
                getTitle: (item) => item.toString(),
                getValue: (item) => item.toString(),
                onSelected: (vals) => setState(() => _tempFilter = _tempFilter.copyWith(situations: vals)),
              ),
            ),
            const SizedBox(height: 16),
            _buildMultiSearchableField(
              label: 'Usuario',
              hintText: 'Todos los Usuarios',
              values: _tempFilter.userNames,
              isLoading: false,
              isDisabled: false,
              onTap: () => _openMultiSelectSearchModal(
                title: 'Usuario',
                items: {
                  for (var u in modalUsers)
                    if ((u['AD_User_ID'] ?? u['id']) != null) (u['AD_User_ID'] ?? u['id']): u,
                }.values.toList(),
                currentValues: _tempFilter.userNames,
                getTitle: (item) => item['Name'] ?? 'Sin Nombre',
                getSubtitle: (item) => 'ID: ${item['AD_User_ID'] ?? item['id']}',
                getValue: (item) => item['Name']?.toString() ?? '',
                onSelected: (vals) => setState(() => _tempFilter = _tempFilter.copyWith(userNames: vals)),
              ),
            ),
            const SizedBox(height: 16),
            _buildMultiSearchableField(
              label: 'Nivel',
              hintText: 'Todos los Niveles',
              values: _tempFilter.levels,
              isLoading: false,
              isDisabled: false,
              onTap: () => _openMultiSelectSearchModal(
                title: 'Nivel',
                items: ['Urgente', 'Alta', 'Media', 'Baja', 'Menor'],
                currentValues: _tempFilter.levels,
                getTitle: (item) => item.toString(),
                getValue: (item) => item.toString(),
                onSelected: (vals) => setState(() => _tempFilter = _tempFilter.copyWith(levels: vals)),
              ),
            ),
            const SizedBox(height: 16),
            _buildMultiSearchableField(
              label: 'Estado',
              hintText: 'Todos los Estados',
              values: _tempFilter.statuses,
              isLoading: false,
              isDisabled: false,
              onTap: () => _openMultiSelectSearchModal(
                title: 'Estado',
                items: (widget.statusIdMap.isNotEmpty ? (widget.statusIdMap.keys.toList()..sort()) : ['1_Open', '2_Waiting on customer', '3_Closed']),
                currentValues: _tempFilter.statuses,
                getTitle: (item) => item.toString(),
                getValue: (item) => item.toString(),
                onSelected: (vals) => setState(() => _tempFilter = _tempFilter.copyWith(statuses: vals)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
        CustomButton(text: 'Aplicar Filtros', onPressed: () => Navigator.pop(context, _tempFilter)),
      ],
    );
  }
}

/// A helper dialog for multi-selection with a search bar.
class _MultiSelectSearchDialog extends StatefulWidget {
  final String title;
  final List<dynamic> items;
  final List<String> initialSelectedValues;
  final String Function(dynamic) getTitle;
  final String? Function(dynamic)? getSubtitle;
  final String Function(dynamic) getValue;

  const _MultiSelectSearchDialog({required this.title, required this.items, required this.initialSelectedValues, required this.getTitle, this.getSubtitle, required this.getValue});

  @override
  State<_MultiSelectSearchDialog> createState() => __MultiSelectSearchDialogState();
}

class __MultiSelectSearchDialogState extends State<_MultiSelectSearchDialog> {
  late Set<String> _tempSelectedValues;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tempSelectedValues = Set.from(widget.initialSelectedValues);
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = widget.items.where((item) {
      return widget.getTitle(item).toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: 400,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Seleccionar ${widget.title}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400)),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.filter_list, color: Colors.grey),
                hintText: 'Filtrar...',
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: filteredItems.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.grey, thickness: 0.3),
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  final itemValue = widget.getValue(item);
                  final isSelected = _tempSelectedValues.contains(itemValue);

                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(widget.getTitle(item), style: const TextStyle(fontSize: 14)),
                    subtitle: widget.getSubtitle != null && widget.getSubtitle!(item) != null ? Text(widget.getSubtitle!(item)!, style: const TextStyle(fontSize: 12, color: Colors.grey)) : null,
                    value: isSelected,
                    onChanged: (bool? selected) => setState(() => selected == true ? _tempSelectedValues.add(itemValue) : _tempSelectedValues.remove(itemValue)),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancelar')),
                const SizedBox(width: 8),
                CustomButton(text: 'Aplicar', onPressed: () => Navigator.of(context).pop(_tempSelectedValues.toList())),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
