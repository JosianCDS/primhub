import 'package:flutter/material.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/api/global_cache.dart';

class ProjectRequestFilterModel {
  final List<String> phases;
  final List<String> tasks;
  final List<String> categories;
  final List<String> types;
  final List<int> salesRepIds;
  final List<int> userIds;
  final List<String> statuses;
  final List<String> levels;

  const ProjectRequestFilterModel({
    this.phases = const [],
    this.tasks = const [],
    this.categories = const [],
    this.types = const [],
    this.salesRepIds = const [],
    this.userIds = const [],
    this.statuses = const [],
    this.levels = const [],
  });

  ProjectRequestFilterModel copyWith({
    List<String>? phases,
    List<String>? tasks,
    List<String>? categories,
    List<String>? types,
    List<int>? salesRepIds,
    List<int>? userIds,
    List<String>? statuses,
    List<String>? levels,
  }) {
    return ProjectRequestFilterModel(
      phases: phases ?? this.phases,
      tasks: tasks ?? this.tasks,
      categories: categories ?? this.categories,
      types: types ?? this.types,
      salesRepIds: salesRepIds ?? this.salesRepIds,
      userIds: userIds ?? this.userIds,
      statuses: statuses ?? this.statuses,
      levels: levels ?? this.levels,
    );
  }

  int get activeFilterCount {
    int count = 0;
    if (phases.isNotEmpty) count++;
    if (tasks.isNotEmpty) count++;
    if (categories.isNotEmpty) count++;
    if (types.isNotEmpty) count++;
    if (salesRepIds.isNotEmpty) count++;
    if (userIds.isNotEmpty) count++;
    if (statuses.isNotEmpty) count++;
    if (levels.isNotEmpty) count++;
    return count;
  }
}

class ProjectRequestFilterModal extends StatefulWidget {
  final ProjectRequestFilterModel initialFilter;
  final List<String> availablePhases;
  final List<Map<String, dynamic>> allProjectRequests;
  final List<dynamic> users;
  final Map<String, int> statusIdMap;

  const ProjectRequestFilterModal({
    super.key,
    required this.initialFilter,
    required this.availablePhases,
    required this.allProjectRequests,
    required this.users,
    required this.statusIdMap,
  });

  @override
  State<ProjectRequestFilterModal> createState() => _ProjectRequestFilterModalState();
}

class _ProjectRequestFilterModalState extends State<ProjectRequestFilterModal> {
  late ProjectRequestFilterModel _tempFilter;

  @override
  void initState() {
    super.initState();
    _tempFilter = widget.initialFilter.copyWith();
  }

  Future<void> _openMultiSelectSearchModal({
    required String title,
    required List<dynamic> items,
    required List<String> currentValues,
    required String Function(dynamic) getTitle,
    String? Function(dynamic)? getSubtitle,
    required String Function(dynamic) getValue,
    required void Function(List<String>) onSelected,
  }) async {
    final List<String>? result = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return _MultiSelectSearchDialog(
          title: title,
          items: items,
          initialSelectedValues: currentValues,
          getTitle: getTitle,
          getSubtitle: getSubtitle,
          getValue: getValue,
        );
      },
    );

    if (result != null) {
      onSelected(result);
    }
  }

  Widget _buildMultiSearchableField({
    required String label,
    required String hintText,
    required List<String> values,
    required VoidCallback onTap,
  }) {
    String displayText;
    if (values.isEmpty) {
      displayText = hintText;
    } else if (values.length == 1) {
      displayText = values.first;
    } else {
      displayText = '${values.length} seleccionados';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          suffixIcon: const Icon(Icons.search),
        ),
        isEmpty: values.isEmpty,
        child: Text(
          displayText,
          style: TextStyle(
            fontSize: 16,
            color: values.isEmpty ? Colors.grey[600] : Theme.of(context).colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calcular dinámicamente las tareas disponibles según la fase seleccionada
    final List<String> availableTasks = widget.allProjectRequests
        .where((e) {
          if (_tempFilter.phases.isEmpty) return true;
          return _tempFilter.phases.contains(e['phaseName'].toString());
        })
        .map((e) => e['taskName'].toString())
        .where((e) => e != 'General / Proyecto' && e != 'null' && e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final List<String> availableCategories = widget.allProjectRequests
        .map((e) => e['category'].toString())
        .where((e) => e.isNotEmpty && e != 'null' && e != 'Sin Categoría')
        .toSet()
        .toList()
      ..sort();

    final List<String> availableTypes = widget.allProjectRequests
        .map((e) => e['type'].toString())
        .where((e) => e.isNotEmpty && e != 'null')
        .toSet()
        .toList()
      ..sort();

    return CustomModal(
      title: 'Filtros de Proyecto',
      width: 500,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMultiSearchableField(
              label: 'Fase',
              hintText: 'Todas las Fases',
              values: _tempFilter.phases,
              onTap: () => _openMultiSelectSearchModal(
                title: 'Fase',
                items: widget.availablePhases,
                currentValues: _tempFilter.phases,
                getTitle: (item) => item.toString(),
                getValue: (item) => item.toString(),
                onSelected: (vals) => setState(() {
                  _tempFilter = _tempFilter.copyWith(phases: vals);
                  // Limpiar tareas que ya no pertenecen a las fases seleccionadas
                  _tempFilter = _tempFilter.copyWith(tasks: []); 
                }),
              ),
            ),
            const SizedBox(height: 16),
            _buildMultiSearchableField(
              label: 'Tarea',
              hintText: 'Todas las Tareas',
              values: _tempFilter.tasks,
              onTap: () => _openMultiSelectSearchModal(
                title: 'Tarea',
                items: availableTasks,
                currentValues: _tempFilter.tasks,
                getTitle: (item) => item.toString(),
                getValue: (item) => item.toString(),
                onSelected: (vals) => setState(() => _tempFilter = _tempFilter.copyWith(tasks: vals)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMultiSearchableField(
                    label: 'Rep. Comercial',
                    hintText: 'Todos',
                    values: GlobalCache.salesReps
                        .where((rep) => _tempFilter.salesRepIds.contains(((rep['AD_User_ID'] ?? rep['id']) as num?)?.toInt()))
                        .map((rep) => (rep['Name'] ?? '').toString())
                        .toList(),
                    onTap: () => _openMultiSelectSearchModal(
                      title: 'Representante Comercial',
                      items: GlobalCache.salesReps,
                      currentValues: _tempFilter.salesRepIds.map((id) => id.toString()).toList(),
                      getTitle: (item) => (item['Name'] ?? '').toString(),
                      getValue: (item) => ((item['AD_User_ID'] ?? item['id']) as num).toInt().toString(),
                      onSelected: (vals) => setState(() => _tempFilter = _tempFilter.copyWith(
                        salesRepIds: vals.map((v) => int.parse(v)).toList()
                      )),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMultiSearchableField(
                    label: 'Usuario',
                    hintText: 'Todos',
                    values: widget.users
                        .where((u) => _tempFilter.userIds.contains(((u['AD_User_ID'] ?? u['id']) as num?)?.toInt()))
                        .map((u) => (u['Name'] ?? '').toString())
                        .toList(),
                    onTap: () => _openMultiSelectSearchModal(
                      title: 'Usuario',
                      items: widget.users,
                      currentValues: _tempFilter.userIds.map((id) => id.toString()).toList(),
                      getTitle: (item) => (item['Name'] ?? '').toString(),
                      getValue: (item) => ((item['AD_User_ID'] ?? item['id']) as num).toInt().toString(),
                      onSelected: (vals) => setState(() => _tempFilter = _tempFilter.copyWith(
                        userIds: vals.map((v) => int.parse(v)).toList()
                      )),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMultiSearchableField(
                    label: 'Tipo de solicitud',
                    hintText: 'Todos',
                    values: _tempFilter.types,
                    onTap: () => _openMultiSelectSearchModal(
                      title: 'Tipo de solicitud',
                      items: availableTypes,
                      currentValues: _tempFilter.types,
                      getTitle: (item) => item.toString(),
                      getValue: (item) => item.toString(),
                      onSelected: (vals) => setState(() => _tempFilter = _tempFilter.copyWith(types: vals)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMultiSearchableField(
                    label: 'Categoría',
                    hintText: 'Todos',
                    values: _tempFilter.categories,
                    onTap: () => _openMultiSelectSearchModal(
                      title: 'Categoría',
                      items: availableCategories,
                      currentValues: _tempFilter.categories,
                      getTitle: (item) => item.toString(),
                      getValue: (item) => item.toString(),
                      onSelected: (vals) => setState(() => _tempFilter = _tempFilter.copyWith(categories: vals)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildMultiSearchableField(
              label: 'Estado',
              hintText: 'Todos',
              values: _tempFilter.statuses,
              onTap: () => _openMultiSelectSearchModal(
                title: 'Estado',
                items: widget.statusIdMap.keys.toList()..sort(),
                currentValues: _tempFilter.statuses,
                getTitle: (item) => item.toString(),
                getValue: (item) => item.toString(),
                onSelected: (vals) => setState(() => _tempFilter = _tempFilter.copyWith(statuses: vals)),
              ),
            ),
            const SizedBox(height: 16),
            _buildMultiSearchableField(
              label: 'Nivel',
              hintText: 'Todos',
              values: _tempFilter.levels,
              onTap: () => _openMultiSelectSearchModal(
                title: 'Nivel',
                items: ['Urgente', 'Alta', 'Media', 'Baja', 'Menor'],
                currentValues: _tempFilter.levels,
                getTitle: (item) => item.toString(),
                getValue: (item) => item.toString(),
                onSelected: (vals) => setState(() => _tempFilter = _tempFilter.copyWith(levels: vals)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
        CustomButton(
          text: 'Aplicar Filtros',
          onPressed: () => Navigator.pop(context, _tempFilter),
        ),
      ],
    );
  }
}

class _MultiSelectSearchDialog extends StatefulWidget {
  final String title;
  final List<dynamic> items;
  final List<String> initialSelectedValues;
  final String Function(dynamic) getTitle;
  final String? Function(dynamic)? getSubtitle;
  final String Function(dynamic) getValue;

  const _MultiSelectSearchDialog({
    required this.title,
    required this.items,
    required this.initialSelectedValues,
    required this.getTitle,
    this.getSubtitle,
    required this.getValue,
  });

  @override
  State<_MultiSelectSearchDialog> createState() => __MultiSelectSearchDialogState();
}

class __MultiSelectSearchDialogState extends State<_MultiSelectSearchDialog> {
  late Set<String> _tempSelectedValues;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tempSelectedValues = Set.from(widget.initialSelectedValues.map((s) => s.toLowerCase().trim()));
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
                  final itemValue = widget.getValue(item).toLowerCase().trim();
                  final isSelected = _tempSelectedValues.contains(itemValue);

                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(widget.getTitle(item), style: const TextStyle(fontSize: 14)),
                    subtitle: widget.getSubtitle != null && widget.getSubtitle!(item) != null 
                        ? Text(widget.getSubtitle!(item)!, style: const TextStyle(fontSize: 12, color: Colors.grey)) 
                        : null,
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
