import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/pages/request/create_request_dialog.dart';
import 'package:primhub/ui/pages/request/request_functions.dart';
import 'package:primhub/ui/shared/custom_button.dart';
import 'package:primhub/ui/shared/custom_inputs.dart';
import 'package:primhub/ui/shared/custom_modal.dart';
import 'package:primhub/ui/shared/custom_table.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/custom_drawer.dart';

class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({super.key});

  @override
  State<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  bool _isAscending = false;
  bool _showHistory = false;
  bool _isInit = true;
  bool _isAdmin = true;

  @override
  void initState() {
    super.initState();
    _checkRole();
    _refreshRequest();
  }

  Future<void> _checkRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted)
      setState(
        () => _isAdmin = (prefs.getString('user_role') ?? 'ADMIN') == 'ADMIN',
      );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['showHistory'] == true) {
        _showHistory = true;
      }
      _isInit = false;
    }
  }

  Future<void> _refreshRequest() async {
    final requests = await fetchRequest();
    setState(() {
      _requests = requests.map((r) {
        String level = r['Priority_Name'] ?? 'Baja';
        String status = r['R_Status_Name'] ?? '';

        // Asignar colores según el nivel
        Color baseColor = Colors.green;
        if (level == 'Alta')
          baseColor = Colors.red;
        else if (level == 'Media')
          baseColor = Colors.amber.shade800;
        String formattedTime = r['Created'] ?? '';
        try {
          if (formattedTime.isNotEmpty) {
            final DateTime date = DateTime.parse(formattedTime).toLocal();
            formattedTime =
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
          }
        } catch (_) {}

        return {
          'id': r['DocumentNo'] ?? r['id'].toString(),
          'realId': r['id'],
          'situation': r['R_RequestType_Name'] ?? 'Solicitud',
          'description': r['Summary'] ?? '',
          'level': level,
          'status': status,
          'time': formattedTime,
          'levelColor': baseColor,
          'levelBgColor': baseColor.withOpacity(0.2),
          'statusColor': Colors.grey,
        };
      }).toList();
      _isLoading = false;
    });
  }

  String? _selectedLevel;
  String? _selectedStatus;

  final Map<String, String> _priorityMap = {
    'Alta': '3',
    'Media': '5',
    'Baja': '7',
  };

  // IDs from API response
  final Map<String, int> _statusMap = {
    '1_Open': 100,
    '2_Waiting on customer': 101,
    '3_Closed': 102,
    '9_Final Close': 103,
  };

  Future<bool> _updateRemoteRequest(
    dynamic id,
    String priority,
    String status,
  ) async {
    try {
      final url = Uri.parse('${Endpoint.request}/$id');
      final body = jsonEncode({
        'Priority': _priorityMap[priority],
        'R_Status_ID': _statusMap[status],
      });

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
        body: body,
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error updating request: $e');
      return false;
    }
  }

  void _editRequest(Map<String, dynamic> req) {
    String currentPriority = req['level'];
    String currentStatus = req['status'];
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return CustomModal(
            title: 'Editar Solicitud ${req['id']}',
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomDropdown<String>(
                  label: 'Nivel de Prioridad',
                  value: currentPriority,
                  items: ['Alta', 'Media', 'Baja']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null)
                      setStateDialog(() => currentPriority = val);
                  },
                ),
                const SizedBox(height: 16),
                CustomDropdown<String>(
                  label: 'Estado',
                  value: currentStatus,
                  items:
                      [
                            '1_Open',
                            '2_Waiting on customer',
                            '3_Closed',
                            '9_Final Close',
                          ]
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                  onChanged: (val) {
                    if (val != null) setStateDialog(() => currentStatus = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              CustomButton(
                text: 'Guardar',
                isLoading: isSaving,
                onPressed: () async {
                  setStateDialog(() => isSaving = true);
                  final success = await _updateRemoteRequest(
                    req['realId'],
                    currentPriority,
                    currentStatus,
                  );
                  setStateDialog(() => isSaving = false);

                  if (success) {
                    if (mounted) {
                      setState(() {
                        req['level'] = currentPriority;
                        req['status'] = currentStatus;
                        if (currentPriority == 'Alta') {
                          req['levelColor'] = Colors.red;
                        } else if (currentPriority == 'Media') {
                          req['levelColor'] = Colors.amber.shade800;
                        } else {
                          req['levelColor'] = Colors.green;
                        }
                        req['levelBgColor'] = req['levelColor'].withOpacity(
                          0.2,
                        );
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Solicitud actualizada correctamente'),
                        ),
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Error al actualizar la solicitud'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredAlerts = _requests.where((alert) {
      // Lógica para separar Activas de Historial (Final Close)
      if (_showHistory) {
        if (alert['status'] != '9_Final Close') return false;
      } else {
        if (alert['status'] == '9_Final Close') return false;
      }

      if (_selectedLevel != null && alert['level'] != _selectedLevel)
        return false;
      if (_selectedStatus != null && alert['status'] != _selectedStatus)
        return false;
      return true;
    }).toList();

    filteredAlerts.sort((a, b) {
      final timeA = a['time'] ?? '';
      final timeB = b['time'] ?? '';
      return _isAscending ? timeA.compareTo(timeB) : timeB.compareTo(timeA);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Solicitudes De Soporte')),
      drawer: const CustomDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final filters = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filtros:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DropdownButton<String>(
                          hint: const Text('Nivel'),
                          value: _selectedLevel,
                          items: ['Alta', 'Media', 'Baja'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => _selectedLevel = val),
                        ),
                        const SizedBox(width: 16),
                        DropdownButton<String>(
                          hint: const Text('Estado'),
                          value: _selectedStatus,
                          items: ['1_Open', '2_Waiting on customer', '3_Closed']
                              .map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              })
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedStatus = val),
                        ),
                        const SizedBox(width: 16),
                        ActionChip(
                          avatar: Icon(
                            _isAscending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 16,
                          ),
                          label: Text(
                            _isAscending ? 'Más antiguas' : 'Más recientes',
                          ),
                          onPressed: () {
                            setState(() => _isAscending = !_isAscending);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.filter_alt_off),
                          onPressed: () => setState(() {
                            _selectedLevel = null;
                            _selectedStatus = null;
                            _isAscending = false;
                          }),
                          tooltip: 'Limpiar filtros',
                        ),
                      ],
                    ),
                  ],
                );

                final buttons = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => setState(() {
                        _showHistory = !_showHistory;
                        _selectedStatus = null;
                      }),
                      icon: Icon(
                        _showHistory ? Icons.list : Icons.history,
                        color: Colors.white,
                      ),
                      label: Text(
                        _showHistory ? 'Ver Activas' : 'Ver Bitácora',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F47E5),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await showDialog(
                          context: context,
                          builder: (context) => const CreateRequestDialog(),
                        );
                        if (result == true) {
                          _refreshRequest(); // Recargar la tabla
                        }
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'Solicitud',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F47E5),
                      ),
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
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 1000),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(50.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Card(
                      elevation: 4,
                      child: CustomTable(
                        columns: const [
                          DataColumn(label: Text('Ticket')),
                          DataColumn(label: Text('Asunto')),
                          DataColumn(label: Text('Nivel')),
                          DataColumn(label: Text('Ultima Actualización')),
                          DataColumn(label: Text('Descripción')),
                          DataColumn(label: Text('Estado')),
                        ],
                        rows: filteredAlerts.map((alert) {
                          return DataRow(
                            onSelectChanged: _isAdmin
                                ? (value) => _editRequest(alert)
                                : null,
                            cells: [
                              DataCell(Text(alert['id'])),
                              DataCell(Text(alert['situation'])),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: alert['levelBgColor'],
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Text(
                                    alert['level'],
                                    style: TextStyle(
                                      color: alert['levelColor'],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(alert['time'] ?? '')),
                              DataCell(Text(alert['description'])),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(width: 8),
                                    Text(alert['status']),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
