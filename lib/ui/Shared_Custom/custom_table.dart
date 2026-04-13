import 'package:flutter/material.dart';

class CustomTable extends StatefulWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final double? width;
  final double? height;
  final bool enableHover;
  final bool showCheckboxColumn;
  final ValueChanged<bool?>? onSelectAll;

  const CustomTable({super.key, required this.columns, required this.rows, this.width, this.height, this.enableHover = true, this.showCheckboxColumn = false, this.onSelectAll});

  @override
  State<CustomTable> createState() => _CustomTableState();
}

class _CustomTableState extends State<CustomTable> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Scrollbar(
            controller: _scrollController,
            thumbVisibility: true, // Mantiene la barra siempre visible
            trackVisibility: true, // Muestra el carril por donde se desliza
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  showCheckboxColumn: widget.showCheckboxColumn,
                  onSelectAll: widget.onSelectAll,
                  headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  dataRowMinHeight: 45,
                  headingRowColor: MaterialStateProperty.all(theme.colorScheme.surfaceContainerHighest.withOpacity(0.3)),
                  dataRowColor: widget.enableHover
                      ? MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
                          if (states.contains(MaterialState.hovered)) {
                            return Colors.blue.withOpacity(0.1);
                          }
                          return null;
                        })
                      : null,
                  columns: widget.columns,
                  rows: widget.rows,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
