import 'package:flutter/material.dart';
import 'package:primhub/ui/shared/cardcustom.dart';
import 'package:primhub/ui/shared/custom_container.dart';
import 'package:primhub/ui/shared/custom_table.dart';
import '../widgets/custom_drawer.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestión de Horas de Soporte',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      drawer: const CustomDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              color: isDark ? colorScheme.surface : const Color(0xFFFEFEFE),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resumen del contrato',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final card1 = CardCustom(
                          height: 150,
                          width: null,
                          elevation: 0,
                          color: isDark
                              ? colorScheme.surfaceContainerHighest
                              : const Color(0xFFF6F8FA),
                          hover: true,
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Horas Contratadas',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? colorScheme.onSurfaceVariant
                                        : const Color(0xff777D8A),
                                  ),
                                ),
                                Text(
                                  '50',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? colorScheme.onSurface
                                        : const Color(0xFF1C2430),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        final card2 = CardCustom(
                          height: 150,
                          width: null,
                          elevation: 0,
                          color: isDark
                              ? colorScheme.surfaceContainerHighest
                              : const Color(0xFFF6F8FA),
                          hover: true,
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Horas Consumidas',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? colorScheme.onSurfaceVariant
                                        : const Color(0xff777D8A),
                                  ),
                                ),
                                Text(
                                  '32.5',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? colorScheme.error
                                        : const Color(0xFFD12324),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        final card3 = CardCustom(
                          height: 150,
                          width: null,
                          elevation: 0,
                          color: isDark
                              ? colorScheme.surfaceContainerHighest
                              : const Color(0xFFE9EFFD),
                          hover: true,
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Horas Disponibles',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? colorScheme.primary
                                        : const Color(0xFF463EE2),
                                  ),
                                ),
                                Text(
                                  '17.5',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? colorScheme.primary
                                        : const Color(0xFF463EE2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );

                        if (constraints.maxWidth < 800) {
                          return Column(
                            children: [
                              SizedBox(width: double.infinity, child: card1),
                              const SizedBox(height: 10),
                              SizedBox(width: double.infinity, child: card2),
                              const SizedBox(height: 10),
                              SizedBox(width: double.infinity, child: card3),
                            ],
                          );
                        } else {
                          return Row(
                            children: [
                              Expanded(child: card1),
                              const SizedBox(width: 10),
                              Expanded(child: card2),
                              const SizedBox(width: 10),
                              Expanded(child: card3),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            CustomContainer(
              title: 'Registro de Horas Consumidas',
              child: CustomTable(
                columns: const [
                  DataColumn(label: Text('Fecha')),
                  DataColumn(label: Text('Actividad/Tarea')),
                  DataColumn(label: Text('Ticket Relacionado')),
                  DataColumn(label: Text('Horas Consumidas')),
                ],
                rows: [
                  DataRow(
                    onSelectChanged: (value) {},
                    cells: const [
                      DataCell(Text('2023-10-25')),
                      DataCell(Text('Revisión de logs de servidor')),
                      DataCell(Text('#1023')),
                      DataCell(Text('2.5')),
                    ],
                  ),
                  DataRow(
                    onSelectChanged: (value) {},
                    cells: const [
                      DataCell(Text('2023-10-28')),
                      DataCell(Text('Actualización de base de datos')),
                      DataCell(Text('#1045')),
                      DataCell(Text('4.0')),
                    ],
                  ),
                  DataRow(
                    onSelectChanged: (value) {},
                    cells: const [
                      DataCell(Text('2023-11-02')),
                      DataCell(Text('Soporte usuario final - Login')),
                      DataCell(Text('#1056')),
                      DataCell(Text('1.0')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
