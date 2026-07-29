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
  final bool showWithoutChipOnly;
  final VoidCallback? onToggleWithoutChip;
  final VoidCallback? onExport; // Nuevo callback para exportar
  final Widget? counterWidget;

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
    this.showWithoutChipOnly = false,
    this.onToggleWithoutChip,
    this.onExport,
    this.counterWidget,
  });

  @override
  Widget build(BuildContext context) {
    final double buttonWidth = 190.0;
    
    final buttons = Wrap(
      spacing: 12.0,
      runSpacing: 12.0,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (!AccessControl.isRealSupport)
          CustomButton(
            text: showCalendar ? 'Ver Lista' : 'Calendario/Gantt',
            onPressed: isLoading ? null : onShowCalendar,
            icon: showCalendar ? Icons.list_alt : Icons.calendar_month,
            backgroundColor: Theme.of(context).colorScheme.tertiary,
            textColor: Theme.of(context).colorScheme.onTertiary,
          ),
        CustomButton(
            text: showHistory ? 'Ver Activas' : 'Ver Bitácora',
            onPressed: isLoading ? null : onToggleHistory,
            icon: showHistory ? Icons.list : Icons.history,
            backgroundColor: Theme.of(context).colorScheme.secondary,
            textColor: Theme.of(context).colorScheme.onSecondary,
        ),
        if (AccessControl.canCreateRequests)
          CustomButton(
            text: 'Crear Solicitud',
            onPressed: isLoading ? null : onAddRequest,
            icon: Icons.add,
          ),
        if (onExport != null)
          CustomButton(
            text: 'Exportar',
            onPressed: isLoading ? null : onExport,
            icon: Icons.download,
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
            isAscending ? Icons.arrow_downward : Icons.arrow_upward,
            size: 16,
          ),
          label: Text(isAscending ? 'Más antiguas primero' : 'Más recientes primero'),
          onPressed: onSortChanged,
        ),
/*
        if (AccessControl.isAdmin && onToggleWithoutChip != null)
          ActionChip(
            backgroundColor: showWithoutChipOnly ? Theme.of(context).colorScheme.primaryContainer : null,
            labelStyle: TextStyle(
              color: showWithoutChipOnly ? Theme.of(context).colorScheme.onPrimaryContainer : null,
              fontWeight: showWithoutChipOnly ? FontWeight.bold : null,
            ),
            avatar: const Icon(Icons.block, size: 16),
            label: const Text('Sin ficha'),
            onPressed: onToggleWithoutChip,
          ),
*/
        if (!AccessControl.isSupport)
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
        final bool isLargeScreen = constraints.maxWidth >= 600;

        Widget topRow = SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16.0,
            runSpacing: 12.0,
            children: [
              Wrap(
                spacing: 12.0,
                runSpacing: 12.0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: isLargeScreen ? 400 : constraints.maxWidth,
                    child: CustomTextField(
                      controller: searchController,
                      hintText: 'Buscar por número de ticket...',
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                  if (selectedYears.length == 1 && selectedYears.first == DateTime.now().year)
                    Chip(
                      label: const Text('Año: Año Actual'),
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                ],
              ),
              buttons,
            ],
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            topRow,
            const SizedBox(height: 12),
            if (counterWidget != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: filterChips),
                  const SizedBox(width: 16),
                  counterWidget!,
                ],
              )
            else
              filterChips,
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}
