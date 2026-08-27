import 'package:flutter/material.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
 // Para priorityMap

enum ChipFilterMode {
  mixed,
  withChipFirst,
  withoutChipFirst,
  onlyWithChip,
  onlyWithoutChip,
}


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
  final ChipFilterMode chipFilterMode;
  final ValueChanged<ChipFilterMode>? onChipFilterChanged;
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
    this.chipFilterMode = ChipFilterMode.mixed,
    this.onChipFilterChanged,
    this.onExport,
    this.counterWidget,
  });

  @override
  Widget build(BuildContext context) {


    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isLargeScreen = constraints.maxWidth >= 600;

        final filterChips = Wrap(
          spacing: 16.0,
          runSpacing: 8.0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (!isLargeScreen && AccessControl.canCreateRequests)
              CustomButton(
                text: 'Crear Solicitud',
                onPressed: isLoading ? null : onAddRequest,
                icon: Icons.add,
              ),
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
        if (AccessControl.isAdmin && onChipFilterChanged != null)
          PopupMenuButton<ChipFilterMode>(
            enabled: !isLoading,
            initialValue: chipFilterMode,
            onSelected: onChipFilterChanged,
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: ChipFilterMode.mixed,
                child: Text('Modo Mixto (Por defecto)'),
              ),
              const PopupMenuItem(
                value: ChipFilterMode.withChipFirst,
                child: Text('Con ficha primero'),
              ),
              const PopupMenuItem(
                value: ChipFilterMode.withoutChipFirst,
                child: Text('Sin ficha primero'),
              ),
              const PopupMenuItem(
                value: ChipFilterMode.onlyWithChip,
                child: Text('Solo con ficha de producto'),
              ),
              const PopupMenuItem(
                value: ChipFilterMode.onlyWithoutChip,
                child: Text('Solo sin ficha de producto'),
              ),
            ],
            child: Chip(
              backgroundColor: isLoading ? Theme.of(context).disabledColor.withOpacity(0.12) : null,
              side: (!isLoading && chipFilterMode != ChipFilterMode.mixed)
                  ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5)
                  : null,
              labelStyle: TextStyle(
                color: isLoading
                    ? Theme.of(context).disabledColor
                    : (chipFilterMode != ChipFilterMode.mixed
                        ? Theme.of(context).colorScheme.primary
                        : null),
                fontWeight: (!isLoading && chipFilterMode != ChipFilterMode.mixed) ? FontWeight.bold : null,
              ),
              avatar: Icon(
                Icons.filter_alt, 
                size: 16,
                color: isLoading
                    ? Theme.of(context).disabledColor
                    : (chipFilterMode != ChipFilterMode.mixed
                        ? Theme.of(context).colorScheme.primary
                        : null),
              ),
              label: SizedBox(
                width: 165,
                child: Text(
                  _getChipFilterLabel(chipFilterMode),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),

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
          onChanged: isLoading ? null : onRowsPerPageChanged,
        ),
        TextButton.icon(
          icon: const Icon(Icons.filter_alt_off, size: 18),
          label: const Text('Limpiar'),
          onPressed: isLoading ? null : onClearFilters,
        ),
      ],
    );

        Widget topRow = isLargeScreen
            ? SizedBox(
                width: double.infinity,
                child: Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: searchController,
                        hintText: 'Buscar por ticket, asunto o descripción...',
                        prefixIcon: const Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!AccessControl.isRealSupport)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: CustomButton(
                                text: showCalendar ? 'Ver Lista' : 'Calendario/Gantt',
                                onPressed: isLoading ? null : onShowCalendar,
                                icon: showCalendar ? Icons.list_alt : Icons.calendar_month,
                                backgroundColor: Theme.of(context).colorScheme.tertiary,
                                textColor: Theme.of(context).colorScheme.onTertiary,
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: CustomButton(
                              text: showHistory ? 'Ver Activas' : 'Ver Histórico',
                              onPressed: isLoading ? null : onToggleHistory,
                              icon: showHistory ? Icons.list : Icons.history,
                              backgroundColor: Theme.of(context).colorScheme.secondary,
                              textColor: Theme.of(context).colorScheme.onSecondary,
                            ),
                          ),
                          if (AccessControl.canCreateRequests)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: CustomButton(
                                text: 'Crear Solicitud',
                                onPressed: isLoading ? null : onAddRequest,
                                icon: Icons.add,
                              ),
                            ),
                          if (onExport != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: CustomButton(
                                text: 'Exportar Tabla',
                                onPressed: isLoading ? null : onExport,
                                icon: Icons.download,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          controller: searchController,
                          hintText: 'Buscar...',
                          prefixIcon: const Icon(Icons.search),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
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
                      if (onExport != null)
                        CustomButton(
                          text: 'Exportar',
                          onPressed: isLoading ? null : onExport,
                          icon: Icons.download,
                        ),
                    ],
                  ),
                ],
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            topRow,
            const SizedBox(height: 12),
            if (counterWidget != null)
              isLargeScreen
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: filterChips),
                        const SizedBox(width: 16),
                        counterWidget!,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        filterChips,
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: counterWidget!,
                        ),
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

  String _getChipFilterLabel(ChipFilterMode mode) {
    switch (mode) {
      case ChipFilterMode.mixed:
        return 'Estado de Fichas';
      case ChipFilterMode.withChipFirst:
        return 'Con ficha primero';
      case ChipFilterMode.withoutChipFirst:
        return 'Sin ficha primero';
      case ChipFilterMode.onlyWithChip:
        return 'Solo con ficha';
      case ChipFilterMode.onlyWithoutChip:
        return 'Solo sin ficha';
    }
  }
}
