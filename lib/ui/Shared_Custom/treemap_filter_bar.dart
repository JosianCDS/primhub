import 'package:flutter/material.dart';
import 'package:primhub/api/global_cache.dart';
import 'package:primhub/ui/Shared_Custom/clearable_dropdown_menu.dart';
import 'package:primhub/ui/widgets/duration_formatter.dart';

class TreemapFilterBar extends StatelessWidget {
  final int? selectedBpId;
  final int? selectedProjectId;
  final String? selectedSalesRep;
  final int? selectedChipId;
  final String? selectedRequestCategory;
  final String timeFilter;

  final List<Map<String, dynamic>> availableBps;
  final List<Map<String, dynamic>> availableProjects;
  final List<String> availableReps;
  final List<String> availableCategories;
  final int totalCount;
  final double totalHours;

  final ValueChanged<int?> onBpSelected;
  final ValueChanged<int?> onProjectSelected;
  final ValueChanged<String?> onRepSelected;
  final ValueChanged<int?> onChipSelected;
  final ValueChanged<String?> onCategorySelected;
  final ValueChanged<String> onTimeFilterChanged;
  final VoidCallback onClearFilters;

  const TreemapFilterBar({
    super.key,
    required this.selectedBpId,
    required this.selectedProjectId,
    required this.selectedSalesRep,
    required this.selectedChipId,
    required this.selectedRequestCategory,
    required this.timeFilter,
    required this.availableBps,
    required this.availableProjects,
    required this.availableReps,
    required this.availableCategories,
    required this.totalCount,
    required this.totalHours,
    required this.onBpSelected,
    required this.onProjectSelected,
    required this.onRepSelected,
    required this.onChipSelected,
    required this.onCategorySelected,
    required this.onTimeFilterChanged,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final bool hasFilters = selectedBpId != null || 
                            selectedProjectId != null || 
                            selectedChipId != null || 
                            selectedRequestCategory != null || 
                            selectedSalesRep != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isLargeScreen = constraints.maxWidth >= 1200;
          final bool isMediumScreen = constraints.maxWidth >= 800 && constraints.maxWidth < 1200;
          final double spacing = 12.0;
          
          final double itemWidth;
          if (isLargeScreen) {
            itemWidth = (constraints.maxWidth - (4 * spacing)) / 5;
          } else if (isMediumScreen) {
            itemWidth = (constraints.maxWidth - (2 * spacing)) / 3;
          } else {
            itemWidth = constraints.maxWidth;
          }

          Widget buildItem(Widget child) {
            return SizedBox(
              width: itemWidth,
              child: child,
            );
          }

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              buildItem(
                _buildDropdownContainer(
                  colorScheme: colorScheme,
                  width: itemWidth,
                  child: ClearableDropdownMenu<int?>(
                    initialSelection: selectedBpId,
                    hintText: 'Todos los Terceros',
                    leadingIcon: const Icon(Icons.business_rounded, size: 20),
                    width: itemWidth,
                    menuHeight: 300,
                    dropdownMenuEntries: [
                      const DropdownMenuEntry<int?>(value: null, label: 'Todos los Terceros'),
                      ...availableBps.map((bp) => DropdownMenuEntry<int?>(
                        value: bp['id'] as int,
                        label: bp['Name']?.toString() ?? 'Sin Nombre',
                      )),
                    ],
                    onSelected: onBpSelected,
                  ),
                ),
              ),
              buildItem(
                _buildDropdownContainer(
                  colorScheme: colorScheme,
                  width: itemWidth,
                  child: ClearableDropdownMenu<int?>(
                    initialSelection: selectedProjectId,
                    hintText: selectedBpId != null && availableProjects.isEmpty ? 'Sin Proyectos Disponibles' : 'Todos los Proyectos',
                    leadingIcon: const Icon(Icons.folder_outlined, size: 20),
                    width: itemWidth,
                    menuHeight: 300,
                    dropdownMenuEntries: [
                      if (selectedBpId != null && availableProjects.isEmpty)
                        const DropdownMenuEntry<int?>(value: null, label: 'Sin Proyectos Disponibles')
                      else ...[
                        const DropdownMenuEntry<int?>(value: null, label: 'Todos los Proyectos'),
                        ...availableProjects.map((p) => DropdownMenuEntry<int?>(
                          value: (p['id'] as num?)?.toInt(),
                          label: p['Name']?.toString() ?? 'Proyecto sin nombre',
                        )),
                      ],
                    ],
                    onSelected: onProjectSelected,
                  ),
                ),
              ),
              buildItem(
                _buildDropdownContainer(
                  colorScheme: colorScheme,
                  width: itemWidth,
                  child: ClearableDropdownMenu<String>(
                    initialSelection: selectedSalesRep,
                    fallbackText: 'Todos',
                    hintText: 'Representante',
                    leadingIcon: const Icon(Icons.person_outline, size: 20),
                    width: itemWidth,
                    menuHeight: 300,
                    dropdownMenuEntries: availableReps.isEmpty 
                        ? const [DropdownMenuEntry(value: 'Todos', label: 'Todos los Representantes')]
                        : availableReps.map((rep) => DropdownMenuEntry(value: rep, label: rep)).toList(),
                    onSelected: onRepSelected,
                  ),
                ),
              ),
              buildItem(
                _buildDropdownContainer(
                  colorScheme: colorScheme,
                  width: itemWidth,
                  child: ClearableDropdownMenu<int?>(
                    initialSelection: selectedChipId,
                    hintText: 'Todas las Fichas',
                    leadingIcon: const Icon(Icons.style_outlined, size: 20),
                    width: itemWidth,
                    menuHeight: 300,
                    dropdownMenuEntries: [
                      const DropdownMenuEntry<int?>(value: null, label: 'Todas las Fichas'),
                      ...GlobalCache.productChips.map((c) => DropdownMenuEntry<int?>(
                            value: int.tryParse(c['id']?.toString() ?? '') ?? 0,
                            label: (c['Description'] ?? c['Name'] ?? 'Ficha sin nombre').toString(),
                          )),
                    ],
                    onSelected: onChipSelected,
                  ),
                ),
              ),
              buildItem(
                _buildDropdownContainer(
                  colorScheme: colorScheme,
                  width: itemWidth,
                  child: ClearableDropdownMenu<String>(
                    initialSelection: selectedRequestCategory,
                    fallbackText: 'Todas',
                    hintText: 'Tipo de Solicitud',
                    leadingIcon: const Icon(Icons.category_outlined, size: 20),
                    width: itemWidth,
                    menuHeight: 300,
                    dropdownMenuEntries: availableCategories.map((c) => DropdownMenuEntry<String>(
                      value: c,
                      label: c,
                    )).toList(),
                    onSelected: onCategorySelected,
                  ),
                ),
              ),
              buildItem(
                _buildDropdownContainer(
                  colorScheme: colorScheme,
                  width: itemWidth,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: timeFilter,
                      icon: const Icon(Icons.filter_alt_outlined, size: 20),
                      borderRadius: BorderRadius.circular(10),
                      style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Todo el Historial', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'this_week', child: Text('Semana Actual', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'next_15_days', child: Text('15 Días', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'this_month', child: Text('Mes Actual', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'overdue', child: Text('Vencidas (Abiertas)', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          onTimeFilterChanged(val);
                        }
                      },
                    ),
                  ),
                ),
              ),
              buildItem(
                SizedBox(
                  height: 40,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: hasFilters ? onClearFilters : null,
                      icon: const Icon(Icons.filter_alt_off, size: 18),
                      label: const Text('Limpiar', style: TextStyle(fontSize: 13)),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),
              ),
              buildItem(
                Container(
                  height: 40,
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colorScheme.secondary.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Horas Est.: ${DurationFormatter.format(totalHours)}',
                    style: TextStyle(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              buildItem(
                Container(
                  height: 40,
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Solicitudes: $totalCount',
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDropdownContainer({required ColorScheme colorScheme, required Widget child, required double width}) {
    return Container(
      width: width,
      height: 40,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: child,
    );
  }
}
