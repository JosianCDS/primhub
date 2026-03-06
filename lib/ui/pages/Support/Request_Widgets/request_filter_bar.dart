import 'package:flutter/material.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/api/access_control.dart';

class RequestFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final int? selectedYear;
  final String? selectedBP;
  final String? selectedSituation;
  final String? selectedUser;
  final String? selectedLevel;
  final String? selectedStatus;
  final bool isAscending;
  final int rowsPerPage;
  final bool showHistory;
  final List<Map<String, dynamic>> requests;
  final Map<String, int> statusIdMap;
  final Function(int?) onYearChanged;
  final Function(String?) onBPChanged;
  final Function(String?) onSituationChanged;
  final Function(String?) onUserChanged;
  final Function(String?) onLevelChanged;
  final Function(String?) onStatusChanged;
  final VoidCallback onSortChanged;
  final Function(int?) onRowsPerPageChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onAddRequest;
  final VoidCallback onToggleHistory;

  const RequestFilterBar({
    super.key,
    required this.searchController,
    required this.selectedYear,
    required this.selectedBP,
    required this.selectedSituation,
    required this.selectedUser,
    required this.selectedLevel,
    required this.selectedStatus,
    required this.isAscending,
    required this.rowsPerPage,
    required this.showHistory,
    required this.requests,
    required this.statusIdMap,
    required this.onYearChanged,
    required this.onBPChanged,
    required this.onSituationChanged,
    required this.onUserChanged,
    required this.onLevelChanged,
    required this.onStatusChanged,
    required this.onSortChanged,
    required this.onRowsPerPageChanged,
    required this.onClearFilters,
    required this.onAddRequest,
    required this.onToggleHistory,
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
            const Text('Filtros:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<int?>(
                    hint: const Text('Año'),
                    value: selectedYear,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Limpiar', style: TextStyle(color: Colors.red)),
                      ),
                      ...List.generate(10, (index) => 2024 + index).map((int value) {
                        return DropdownMenuItem<int?>(value: value, child: Text(value.toString()));
                      }),
                    ],
                    onChanged: onYearChanged,
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String?>(
                    hint: const Text('Tercero'),
                    value: selectedBP,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Limpiar', style: TextStyle(color: Colors.red)),
                      ),
                      ...requests.map((e) => e['bpName'].toString()).where((e) => e.isNotEmpty).toSet().toList().map((String value) {
                        return DropdownMenuItem<String?>(value: value, child: Text(value));
                      }),
                    ],
                    onChanged: onBPChanged,
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    hint: const Text('Asunto'),
                    value: selectedSituation,
                    items: requests.map((e) => e['situation'].toString()).toSet().toList().map((String value) {
                      return DropdownMenuItem<String>(value: value, child: Text(value));
                    }).toList(),
                    onChanged: onSituationChanged,
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    hint: const Text('Usuario'),
                    value: selectedUser,
                    items: requests.map((e) => e['userName'].toString()).where((e) => e.isNotEmpty).toSet().toList().map((String value) {
                      return DropdownMenuItem<String>(value: value, child: Text(value));
                    }).toList(),
                    onChanged: onUserChanged,
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    hint: const Text('Nivel'),
                    value: selectedLevel,
                    items: ['Urgente', 'Alta', 'Media', 'Baja', 'Menor'].map((String value) {
                      return DropdownMenuItem<String>(value: value, child: Text(value));
                    }).toList(),
                    onChanged: onLevelChanged,
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    hint: const Text('Estado'),
                    value: (statusIdMap.isNotEmpty && selectedStatus != null && !statusIdMap.containsKey(selectedStatus)) ? null : selectedStatus,
                    items: (statusIdMap.isNotEmpty ? (statusIdMap.keys.toList()..sort()) : ['1_Open', '2_Waiting on customer', '3_Closed']).map((String value) {
                      return DropdownMenuItem<String>(value: value, child: Text(value));
                    }).toList(),
                    onChanged: onStatusChanged,
                  ),
                  const SizedBox(width: 16),
                  ActionChip(avatar: Icon(isAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 16), label: Text(isAscending ? 'Más antiguas' : 'Más recientes'), onPressed: onSortChanged),
                  const SizedBox(width: 16),
                  DropdownButton<int>(
                    value: rowsPerPage,
                    items: [25, 50, 100].map((int value) {
                      return DropdownMenuItem<int>(value: value, child: Text('$value filas'));
                    }).toList(),
                    onChanged: onRowsPerPageChanged,
                  ),
                  IconButton(icon: const Icon(Icons.filter_alt_off), onPressed: onClearFilters, tooltip: 'Limpiar filtros'),
                ],
              ),
            ),
          ],
        );

        final buttons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (AccessControl.canCreateRequests)
              ElevatedButton.icon(
                onPressed: onAddRequest,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Agregar registro', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F47E5)),
              ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: onToggleHistory,
              icon: Icon(showHistory ? Icons.list : Icons.history, color: Colors.white),
              label: Text(showHistory ? 'Ver Activas' : 'Ver Bitácora', style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F47E5)),
            ),
          ],
        );

        if (constraints.maxWidth < 800) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              filters,
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: buttons),
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
