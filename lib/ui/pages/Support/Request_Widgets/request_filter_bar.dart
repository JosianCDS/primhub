import 'package:flutter/material.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart'; // Para priorityMap

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
  final bool isLoading;
  final bool showCalendar; // Add showCalendar

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
    this.isLoading = false,
    this.showCalendar = false, // Default to false
  });

  @override
  Widget build(BuildContext context) {
    final buttons = Wrap(
      spacing: 12.0,
      runSpacing: 8.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        CustomButton(
          text: showCalendar ? 'Ver Lista' : 'Calendario/Gantt',
          onPressed: onShowCalendar,
          icon: showCalendar ? Icons.list_alt : Icons.calendar_month,
          backgroundColor: Theme.of(context).colorScheme.tertiary,
          textColor: Theme.of(context).colorScheme.onTertiary,
        ),
        if (AccessControl.canCreateRequests)
          CustomButton(text: 'Crear Solicitud', onPressed: isLoading ? null : onAddRequest, icon: Icons.add),
        CustomButton(
          text: showHistory ? 'Ver Activas' : 'Ver Bitácora',
          onPressed: onToggleHistory,
          icon: showHistory ? Icons.list : Icons.history,
          backgroundColor: Theme.of(context).colorScheme.secondary,
          textColor: Theme.of(context).colorScheme.onSecondary,
        ),
      ],
    );

    final filterChips = Wrap(
      spacing: 16.0,
      runSpacing: 8.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        CustomButton(
          text: 'Filtros',
          onPressed: isLoading ? null : onShowFilters,
          icon: Icons.filter_list,
          backgroundColor: activeFilterCount > 0
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          textColor: activeFilterCount > 0
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : null,
        ),
        if (activeFilterCount > 0)
          Chip(
            label: Text('$activeFilterCount'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            labelStyle: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
            padding: const EdgeInsets.all(4),
            visualDensity: VisualDensity.compact,
          ),
        ActionChip(
          avatar: Icon(
            isAscending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 16,
          ),
          label: Text(isAscending ? 'Más antiguas' : 'Más recientes'),
          onPressed: onSortChanged,
        ),
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
          value: rowsPerPage,
          items: [10, 25, 50, 100]
              .map((int value) => DropdownMenuItem<int>(
                    value: value,
                    child: Text('$value filas'),
                  ))
              .toList(),
          onChanged: onRowsPerPageChanged,
        ),
        TextButton.icon(
          icon: const Icon(Icons.filter_alt_off, size: 18),
          label: const Text('Limpiar'),
          onPressed: onClearFilters,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1200) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 400,
                child: CustomTextField(
                  controller: searchController,
                  hintText: 'Buscar por número de ticket...',
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 8),
              filterChips,
              const SizedBox(height: 8),
              Wrap(
                spacing: 16.0,
                runSpacing: 8.0,
                children: buttons.children,
              ),
              const SizedBox(height: 8),
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: SizedBox(
                  width: 400,
                  child: CustomTextField(
                    controller: searchController,
                    hintText: 'Buscar por número de ticket...',
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: filterChips),
                  const SizedBox(width: 16),
                  buttons,
                ],
              ),
              const SizedBox(height: 8),
            ],
          );
        }
      },
    );
  }
}
