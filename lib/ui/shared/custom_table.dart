import 'package:flutter/material.dart';

class CustomTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final double? width;
  final double? height;
  final bool enableHover;

  const CustomTable({
    super.key,
    required this.columns,
    required this.rows,
    this.width,
    this.height,
    this.enableHover = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingTextStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                dataRowMinHeight: 45,
                headingRowColor: MaterialStateProperty.all(
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                ),
                dataRowColor: enableHover
                    ? MaterialStateProperty.resolveWith<Color?>((
                        Set<MaterialState> states,
                      ) {
                        if (states.contains(MaterialState.hovered)) {
                          return Colors.blue.withOpacity(0.1);
                        }
                        return null;
                      })
                    : null,
                columns: columns,
                rows: rows,
              ),
            ),
          );
        },
      ),
    );
  }
}
