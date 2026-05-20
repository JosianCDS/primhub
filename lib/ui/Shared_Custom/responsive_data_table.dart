import 'package:flutter/material.dart';

/// A data class to define columns for the responsive table.
class ResponsiveDataColumn {
  final String label;
  final bool numeric;

  const ResponsiveDataColumn({required this.label, this.numeric = false});
}

/// A responsive data table that shows a split view (fixed/scrollable) on desktop
/// and a card list view on mobile.
class ResponsiveDataTable<T> extends StatefulWidget {
  final List<T> items;
  final List<ResponsiveDataColumn> fixedColumns;
  final List<ResponsiveDataColumn> scrollableColumns;
  final List<DataCell> Function(T item) fixedCellBuilder;
  final List<DataCell> Function(T item) scrollableCellBuilder;
  final Widget Function(T item) mobileCardBuilder;
  final Function(T item)? onRowTap;
  final Set<int> selectedIds;
  final Function(int id, bool isSelected)? onSelectChanged;
  final Function(bool? selected)? onSelectAll;
  final int Function(T item) getId;
  final bool showCheckboxColumn;

  const ResponsiveDataTable({super.key, required this.items, this.fixedColumns = const [], required this.scrollableColumns, required this.fixedCellBuilder, required this.scrollableCellBuilder, required this.mobileCardBuilder, this.onRowTap, this.selectedIds = const {}, this.onSelectChanged, this.onSelectAll, required this.getId, this.showCheckboxColumn = false});

  @override
  State<ResponsiveDataTable<T>> createState() => _ResponsiveDataTableState<T>();
}

class _ResponsiveDataTableState<T> extends State<ResponsiveDataTable<T>> {
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          // Mobile View: List of cards
          return ListView.builder(
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              return widget.mobileCardBuilder(widget.items[index]);
            },
          );
        } else {
          // Desktop View: Split table
          return _buildDesktopTable();
        }
      },
    );
  }

  Widget _buildDesktopTable() {
    final theme = Theme.of(context);

    // --- Define Columns ---
    final List<DataColumn> allFixedColumns = [];
    if (widget.showCheckboxColumn) {
      allFixedColumns.add(
        DataColumn(
          label: Checkbox(value: (widget.items.isNotEmpty && widget.selectedIds.length == widget.items.length) ? true : (widget.selectedIds.isNotEmpty ? null : false), tristate: true, onChanged: widget.onSelectAll),
        ),
      );
    }
    allFixedColumns.addAll(widget.fixedColumns.map((c) => DataColumn(label: Text(c.label), numeric: c.numeric)));

    final allScrollableColumns = widget.scrollableColumns.map((c) => DataColumn(label: Text(c.label), numeric: c.numeric)).toList();

    // --- Build Rows ---
    final List<DataRow> fixedRows = [];
    final List<DataRow> scrollableRows = [];

    for (var item in widget.items) {
      final int realId = widget.getId(item);
      final bool isSelected = widget.selectedIds.contains(realId);

      final List<DataCell> fixedCells = [];
      if (widget.showCheckboxColumn) {
        fixedCells.add(
          DataCell(
            Checkbox(
              value: isSelected,
              onChanged: (selected) {
                if (widget.onSelectChanged != null) {
                  widget.onSelectChanged!(realId, selected ?? false);
                }
              },
            ),
          ),
        );
      }
      
      final builtFixed = widget.fixedCellBuilder(item);
      if (builtFixed.length != widget.fixedColumns.length) {
        // Mismatch during state transitions (e.g. logging out). Skip to avoid assertion crash.
        continue;
      }
      fixedCells.addAll(builtFixed);

      final builtScrollable = widget.scrollableCellBuilder(item);
      if (builtScrollable.length != widget.scrollableColumns.length) {
        // Mismatch during state transitions (e.g. logging out). Skip to avoid assertion crash.
        continue;
      }

      fixedRows.add(DataRow(selected: isSelected, onSelectChanged: (_) => widget.onRowTap?.call(item), cells: fixedCells));
      scrollableRows.add(DataRow(selected: isSelected, onSelectChanged: (_) => widget.onRowTap?.call(item), cells: builtScrollable));
    }

    // --- Theme ---
    const double rowHeight = 52.0;
    final baseDataTableTheme = DataTableTheme.of(context).copyWith(
      dataRowMinHeight: rowHeight,
      dataRowMaxHeight: rowHeight,
      headingRowHeight: rowHeight,
      headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
    );

    final scrollableDataTableTheme = baseDataTableTheme.copyWith(
      headingRowColor: MaterialStateProperty.all(theme.colorScheme.surfaceContainerHighest.withOpacity(0.3)),
      dataRowColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          return theme.colorScheme.primary.withOpacity(0.15);
        }
        if (states.contains(WidgetState.hovered)) {
          return theme.colorScheme.primary.withOpacity(0.08);
        }
        return null;
      }),
    );

    final fixedDataTableTheme = baseDataTableTheme.copyWith(
      headingRowColor: MaterialStateProperty.all(theme.colorScheme.surfaceContainerHighest),
      dataRowColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        Color baseColor = theme.colorScheme.surfaceContainerHigh;
        if (states.contains(WidgetState.selected)) {
          return Color.alphaBlend(theme.colorScheme.primary.withOpacity(0.2), baseColor);
        }
        if (states.contains(WidgetState.hovered)) {
          return Color.alphaBlend(theme.colorScheme.primary.withOpacity(0.12), baseColor);
        }
        return baseColor;
      }),
    );

    if (widget.fixedColumns.isEmpty) {
      return Card(
        elevation: 4,
        clipBehavior: Clip.hardEdge,
        child: Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: DataTableTheme(
              data: scrollableDataTableTheme,
              child: DataTable(showCheckboxColumn: widget.showCheckboxColumn, onSelectAll: widget.onSelectAll, columns: allScrollableColumns, rows: scrollableRows),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      clipBehavior: Clip.hardEdge,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        scrollDirection: Axis.vertical,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Fixed Part ---
            RepaintBoundary(
              child: DataTableTheme(
                data: fixedDataTableTheme,
                child: DataTable(
                  showCheckboxColumn: false, // Handled manually
                  columns: allFixedColumns,
                  rows: fixedRows,
                ),
              ),
            ),
            // --- Scrollable Part ---
            Expanded(
              child: Scrollbar(
                controller: _horizontalScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  physics: const ClampingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  child: RepaintBoundary(
                    child: DataTableTheme(
                      data: scrollableDataTableTheme,
                      child: DataTable(
                          showCheckboxColumn: false,
                          columns: allScrollableColumns,
                          rows: scrollableRows),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
