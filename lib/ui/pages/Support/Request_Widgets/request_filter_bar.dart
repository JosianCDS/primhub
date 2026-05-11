import 'package:flutter/material.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';

class RequestFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final bool isAscending;
  final int rowsPerPage;
  final bool showHistory;
  final List<int> selectedYears;
  final VoidCallback onShowYearFilter;
  final VoidCallback onSortChanged;
  final Function(int?) onRowsPerPageChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onAddRequest;
  final VoidCallback onToggleHistory;
  final VoidCallback onShowCalendar; // Nuevo callback para mostrar el calendario
  final VoidCallback onShowFilters;
  final int activeFilterCount;

  const RequestFilterBar({
    super.key,
    required this.searchController,
    required this.isAscending,
    required this.rowsPerPage,
    required this.showHistory,
    required this.selectedYears,
    required this.onShowYearFilter,
    required this.onSortChanged,
    required this.onRowsPerPageChanged,
    required this.onClearFilters,
    required this.onAddRequest,
    required this.onToggleHistory,
    required this.onShowFilters,
    required this.activeFilterCount,
    required this.onShowCalendar,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final filters = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: SizedBox(
                width: 400,
                child: CustomTextField(controller: searchController, hintText: 'Buscar por número de ticket...', prefixIcon: const Icon(Icons.search)),
              ),
            ),
            Wrap(
              spacing: 16.0,
              runSpacing: 8.0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                CustomButton(text: 'Filtros', onPressed: onShowFilters, icon: Icons.filter_list, backgroundColor: activeFilterCount > 0 ? Theme.of(context).colorScheme.primaryContainer : null, textColor: activeFilterCount > 0 ? Theme.of(context).colorScheme.onPrimaryContainer : null),
                if (activeFilterCount > 0)
                  Chip(
                    label: Text('$activeFilterCount'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    labelStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold),
                    padding: const EdgeInsets.all(4),
                    visualDensity: VisualDensity.compact,
                  ),
                ActionChip(avatar: Icon(isAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 16), label: Text(isAscending ? 'Más antiguas' : 'Más recientes'), onPressed: onSortChanged),
                ActionChip(
                  avatar: const Icon(Icons.calendar_today, size: 16),
                  label: Text(() {
                    if (selectedYears.isEmpty) return 'Año: Todos';
                    if (selectedYears.length == 1) {
                      if (selectedYears.first == DateTime.now().year) return 'Año: Actual';
                      return 'Año: ${selectedYears.first}';
                    }
                    return 'Años: ${selectedYears.length}';
                  }()),
                  onPressed: onShowYearFilter,
                ),
                DropdownButton<int>(
                  // ignore: sort_child_properties_last
                  value: rowsPerPage,
                  items: [10, 25, 50, 100].map((int value) => DropdownMenuItem<int>(value: value, child: Text('$value filas'))).toList(),
                  onChanged: onRowsPerPageChanged,
                ),
                IconButton(icon: const Icon(Icons.filter_alt_off), onPressed: onClearFilters, tooltip: 'Limpiar filtros'),
              ],
            ),
            const SizedBox(height: 16),
          ],
        );

        final buttons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (AccessControl.canCreateRequests) CustomButton(text: 'Crear Solicitud', onPressed: onAddRequest, icon: Icons.add),
            const SizedBox(width: 16), // Espacio entre botones
            CustomButton(text: 'Ver Calendario', onPressed: onShowCalendar, icon: Icons.calendar_month, backgroundColor: Theme.of(context).colorScheme.tertiary, textColor: Theme.of(context).colorScheme.onTertiary), // Botón de Calendario
            const SizedBox(width: 16), // Espacio entre botones
            CustomButton(text: showHistory ? 'Ver Activas' : 'Ver Bitácora', onPressed: onToggleHistory, icon: showHistory ? Icons.list : Icons.history, backgroundColor: Theme.of(context).colorScheme.secondary, textColor: Theme.of(context).colorScheme.onSecondary), // Botón de Bitácora
          ],
        );

        if (constraints.maxWidth < 800) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Ajustar la columna al tamaño de sus hijos
            children: [
              filters,
              const SizedBox(height: 16),
              Wrap(spacing: 16.0, runSpacing: 8.0, alignment: WrapAlignment.start, children: buttons.children), // Los botones se envuelven en Wrap
              const SizedBox(height: 16), // Espacio adicional si es necesario
            ],
          );
        } else {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: filters),
              const SizedBox(width: 16),
              buttons,
            ],
          );
        }
      },
    );
  }
}
