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
  double? _contractedHours;
  double _consumedHours = 0.0;
  double _estimatedHours = 0.0;
  Map<String, int> _statusIdMap = {};

  @override
  void initState() {
    super.initState();
    _checkRole();
    _initData();
  }

  Future<void> _checkRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted)
      setState(
        () => _isAdmin = (prefs.getString('user_role') ?? 'ADMIN') == 'ADMIN',
      );
  }

  Future<void> _initData() async {
    await _loadContractedHours();
    await _fetchStatuses();
    await _refreshRequest();
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

  Future<void> _fetchStatuses() async {
    try {
      final response = await http.get(
        Uri.parse('${Endpoint.baseUrl}/api/v1/models/R_Status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final records = jsonResponse['records'] as List;
        if (mounted) {
          setState(() {
            _statusIdMap = {for (var r in records) r['Name']: r['id']};
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching statuses: $e');
    }
  }

  Future<void> _loadContractedHours() async {
    final payload = Token.decodePayload(Token.token);
    final int userId = payload['AD_User_ID'] ?? 101;

    final String queryUrl =
        "${Endpoint.order}?\$filter=IsSOTrx eq true and AD_User_ID eq $userId and (DocStatus eq 'CO' or DocStatus eq 'DR')&\$expand=C_OrderLine(\$select=M_Product_ID,QtyEntered;\$filter=M_Product_ID eq 1000850)&\$select=DocumentNo,DateOrdered,Created";

    try {
      final response = await http.get(
        Uri.parse(queryUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final records = jsonResponse['records'] as List;

        double total = 0.0;
        for (var record in records) {
          final lines = record['C_OrderLine'] as List?;
          if (lines != null) {
            for (var line in lines) {
              total += (line['QtyEntered'] as num?)?.toDouble() ?? 0.0;
            }
          }
        }

        if (mounted) {
          setState(() {
            _contractedHours = total;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading contracted hours: $e');
    }
  }

  Future<void> _refreshRequest() async {
    final requests = await fetchRequest();
    double consumed = 0.0;
    double estimated = 0.0;

    for (var req in requests) {
      final statusName = req['R_Status_Name'] ?? '';
      final qtyPlan = (req['QtyPlan'] as num?)?.toDouble() ?? 0.0;

      // Lógica de Consumo: Solo si está en Final Close
      if (statusName == '9_Final Close' || req['R_Status_ID'] == 103) {
        consumed += qtyPlan;
      } else {
        // Si NO está en Final Close Sumamos lo planificado
        estimated += qtyPlan;
      }
    }

    setState(() {
      _consumedHours = consumed;
      _estimatedHours = estimated;

      _requests = requests.map((r) {
        String level = r['Priority_Name'] ?? 'Baja';
        String status = r['R_Status_Name'] ?? '';
        int? statusId = r['R_Status_ID'];

        // Normalizar el nombre del estado usando el mapa de IDs si es posible
        if (statusId != null && _statusIdMap.isNotEmpty) {
          for (var entry in _statusIdMap.entries) {
            if (entry.value == statusId) {
              status = entry.key;
              break;
            }
          }
        }

        // Asignar colores según el nivel
        Color baseColor = Colors.green;
        if (level == 'Urgente')
          baseColor = Colors.purple;
        else if (level == 'Alta')
          baseColor = Colors.red;
        else if (level == 'Media')
          baseColor = Colors.amber.shade800;
        else if (level == 'Menor')
          baseColor = Colors.grey;
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
          'statusId': statusId,
          'time': formattedTime,
          'levelColor': baseColor,
          'levelBgColor': baseColor.withOpacity(0.2),
          'statusColor': Colors.grey,
          'dateStartPlan': r['DateStartPlan'] ?? '',
          'dateCompletePlan': r['DateCompletePlan'] ?? '',
          'startTime': _extractTime(r['StartTime']),
          'endTime': _extractTime(r['EndTime']),
          'qtyPlan': r['QtyPlan']?.toString() ?? '',
          'startDate': r['StartDate'],
          'closeDate': r['CloseDate'],
        };
      }).toList();
      _isLoading = false;
    });
  }

  String? _selectedLevel;
  String? _selectedStatus;

  final Map<String, String> _priorityMap = {
    'Urgente': '1',
    'Alta': '3',
    'Media': '5',
    'Baja': '7',
    'Menor': '9',
  };

  String _extractTime(String? val) {
    if (val == null || val.isEmpty) return '';
    String t = val;
    if (t.contains('T')) {
      t = t.split('T')[1];
    }
    return t.replaceAll('Z', '');
  }

  String _ensureIsoDate(String val) {
    if (val.isEmpty) return "";
    if (val.contains('T')) return val;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(val)) {
      return "${val}T00:00:00Z";
    }
    return val;
  }

  String _ensureIsoTime(String? dateContext, String time) {
    if (time.isEmpty) return "";
    String timePart = time;
    if (time.contains('T')) {
      timePart = time.split('T')[1];
    }
    if (timePart.length == 5) timePart = "$timePart:00";
    if (!timePart.endsWith('Z')) timePart = "${timePart}Z";
    return timePart;
  }

  Future<Map<String, dynamic>> _updateRemoteRequest(
    dynamic id,
    String? priority,
    int? statusId,
    String? statusIdentifier,
    String? summary,
    String? dateStartPlan,
    String? dateCompletePlan,
    String? startTime,
    String? endTime,
    double? qtyPlan,
    String? startDate,
    String? closeDate,
  ) async {
    try {
      final url = Uri.parse('${Endpoint.request}/$id');
      final Map<String, dynamic> data = {};

      if (priority != null) data['Priority'] = _priorityMap[priority];
      if (summary != null) data['Summary'] = summary;

      if (statusId != null) {
        data['R_Status_ID'] = statusId;
      } else if (statusIdentifier != null) {
        data['R_Status_ID'] = {'identifier': statusIdentifier};
      }

      if (dateStartPlan != null && dateStartPlan.isNotEmpty)
        data['DateStartPlan'] = _ensureIsoDate(dateStartPlan);
      if (dateCompletePlan != null && dateCompletePlan.isNotEmpty)
        data['DateCompletePlan'] = _ensureIsoDate(dateCompletePlan);
      if (startTime != null && startTime.isNotEmpty)
        data['StartTime'] = _ensureIsoTime(dateStartPlan, startTime);
      if (endTime != null && endTime.isNotEmpty)
        data['EndTime'] = _ensureIsoTime(
          dateCompletePlan ?? dateStartPlan,
          endTime,
        );
      if (qtyPlan != null) data['QtyPlan'] = qtyPlan;

      if (startDate != null) data['StartDate'] = startDate;
      if (closeDate != null) data['CloseDate'] = closeDate;

      final body = jsonEncode(data);

      debugPrint('Update Payload: $body');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': Token.token,
        },
        body: body,
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint('Update Error ${response.statusCode}: ${response.body}');
        return {
          'success': false,
          'error': 'Error ${response.statusCode}: ${response.body}',
          'payload': body,
        };
      }
      return {'success': true};
    } catch (e) {
      debugPrint('Error updating request: $e');
      String errorMessage = e.toString();
      if (errorMessage.contains('SocketException') ||
          errorMessage.contains('Failed host lookup')) {
        errorMessage =
            'Error de conexión: No se puede acceder al servidor. Verifique su conexión a internet.';
      }
      return {
        'success': false,
        'error': errorMessage,
        'payload': 'Exception occurred',
      };
    }
  }

  void _editRequest(Map<String, dynamic> req) {
    String currentPriority = req['level'];
    String currentStatus = req['status'];
    int? statusId = req['statusId'];
    bool isReadOnly = currentStatus == '9_Final Close' || statusId == 103;
    bool isSaving = false;

    final TextEditingController summaryController = TextEditingController(
      text: req['description'],
    );
    // Controladores para nuevos campos
    final TextEditingController dateStartController = TextEditingController(
      text: req['dateStartPlan'],
    );
    final TextEditingController dateCompleteController = TextEditingController(
      text: req['dateCompletePlan'],
    );
    final TextEditingController startTimeController = TextEditingController(
      text: req['startTime'],
    );
    final TextEditingController endTimeController = TextEditingController(
      text: req['endTime'],
    );
    final TextEditingController qtyPlanController = TextEditingController(
      text: req['qtyPlan'],
    );

    Future<void> selectDate(
      BuildContext context,
      TextEditingController controller,
    ) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2101),
      );
      if (picked != null) {
        controller.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      }
    }

    Future<void> selectTime(
      BuildContext context,
      TextEditingController controller,
    ) async {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (picked != null) {
        // Formato HH:mm:ss para backend si es necesario, o HH:mm
        controller.text =
            "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00";
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          // Asegurar que el estado actual esté en la lista para evitar error de Dropdown
          final List<String> statusItems = _statusIdMap.isNotEmpty
              ? (_statusIdMap.keys.toList()..sort())
              : [
                  '1_Open',
                  '2_Waiting on customer',
                  '3_Closed',
                  '9_Final Close',
                ];
          if (currentStatus.isNotEmpty &&
              !statusItems.contains(currentStatus)) {
            statusItems.add(currentStatus);
          }

          return CustomModal(
            title: 'Editar Solicitud ${req['id']}',
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomTextField(
                    controller: summaryController,
                    label: 'Descripción / Resumen',
                    readOnly: isReadOnly,
                    maxLines: 3,
                    validator: (value) => value == null || value.isEmpty
                        ? 'Por favor ingrese una descripción'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  CustomDropdown<String>(
                    label: 'Nivel de Prioridad',
                    value: currentPriority,
                    items: ['Urgente', 'Alta', 'Media', 'Baja', 'Menor']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: isReadOnly
                        ? null
                        : (val) {
                            if (val != null)
                              setStateDialog(() => currentPriority = val);
                          },
                  ),
                  const SizedBox(height: 16),
                  CustomDropdown<String>(
                    label: 'Estado',
                    value: currentStatus,
                    items: statusItems
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: isReadOnly
                        ? null
                        : (val) {
                            if (val != null)
                              setStateDialog(() => currentStatus = val);
                          },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: isReadOnly
                              ? null
                              : () => selectDate(context, dateStartController),
                          child: AbsorbPointer(
                            child: CustomTextField(
                              controller: dateStartController,
                              label: 'Inicio Plan',
                              readOnly: true,
                              hintText: 'YYYY-MM-DD',
                              prefixIcon: const Icon(Icons.calendar_today),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: isReadOnly
                              ? null
                              : () =>
                                    selectDate(context, dateCompleteController),
                          child: AbsorbPointer(
                            child: CustomTextField(
                              controller: dateCompleteController,
                              label: 'Fin Plan',
                              readOnly: true,
                              hintText: 'YYYY-MM-DD',
                              prefixIcon: const Icon(Icons.calendar_today),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: isReadOnly
                              ? null
                              : () => selectTime(context, startTimeController),
                          child: AbsorbPointer(
                            child: CustomTextField(
                              controller: startTimeController,
                              label: 'Hora Inicio',
                              readOnly: true,
                              hintText: 'HH:mm:ss',
                              prefixIcon: const Icon(Icons.access_time),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: isReadOnly
                              ? null
                              : () => selectTime(context, endTimeController),
                          child: AbsorbPointer(
                            child: CustomTextField(
                              controller: endTimeController,
                              label: 'Hora Fin',
                              readOnly: true,
                              hintText: 'HH:mm:ss',
                              prefixIcon: const Icon(Icons.access_time),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: qtyPlanController,
                    label: 'Cant Plan (Horas)',
                    readOnly: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isReadOnly ? 'Cerrar' : 'Cancelar'),
              ),
              if (!isReadOnly)
                CustomButton(
                  text: 'Guardar',
                  isLoading: isSaving,
                  onPressed: () async {
                    setStateDialog(() => isSaving = true);

                    // Calcular QtyPlan automáticamente si hay horas definidas
                    if (startTimeController.text.isNotEmpty &&
                        endTimeController.text.isNotEmpty) {
                      try {
                        DateTime startBase = dateStartController.text.isNotEmpty
                            ? DateTime.parse(dateStartController.text)
                            : DateTime.now();
                        DateTime endBase =
                            dateCompleteController.text.isNotEmpty
                            ? DateTime.parse(dateCompleteController.text)
                            : startBase;

                        final sParts = startTimeController.text.split(':');
                        final eParts = endTimeController.text.split(':');
                        if (sParts.length >= 2 && eParts.length >= 2) {
                          final start = DateTime(
                            startBase.year,
                            startBase.month,
                            startBase.day,
                            int.parse(sParts[0]),
                            int.parse(sParts[1]),
                          );
                          var end = DateTime(
                            endBase.year,
                            endBase.month,
                            endBase.day,
                            int.parse(eParts[0]),
                            int.parse(eParts[1]),
                          );
                          if (end.isBefore(start)) {
                            end = end.add(const Duration(days: 1));
                            // Actualizar la fecha de fin visualmente y para el envío
                            dateCompleteController.text =
                                "${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}";
                          }
                          final diff = end.difference(start);
                          final hours = diff.inMinutes / 60.0;
                          qtyPlanController.text = hours.toStringAsFixed(2);
                        }
                      } catch (_) {}
                    }

                    int? statusIdToSend;
                    String? statusIdentifierToSend;

                    // Verificar si el estado realmente cambió comparando IDs para evitar
                    // enviar R_Status_ID si ya está en ese estado (evita error 500 en registros procesados)
                    int? targetStatusId = _statusIdMap[currentStatus];

                    if (targetStatusId != null && req['statusId'] != null) {
                      if (targetStatusId != req['statusId']) {
                        statusIdToSend = targetStatusId;
                      }
                    } else if (currentStatus != req['status']) {
                      if (targetStatusId != null) {
                        statusIdToSend = targetStatusId;
                      } else {
                        statusIdentifierToSend = currentStatus;
                      }
                    }

                    // Solo enviar campos si han cambiado respecto al valor original
                    String? dateStartPlanToSend =
                        dateStartController.text != req['dateStartPlan']
                        ? dateStartController.text
                        : null;
                    String? dateCompletePlanToSend =
                        dateCompleteController.text != req['dateCompletePlan']
                        ? dateCompleteController.text
                        : null;
                    String? startTimeToSend =
                        startTimeController.text != req['startTime']
                        ? startTimeController.text
                        : null;
                    String? endTimeToSend =
                        endTimeController.text != req['endTime']
                        ? endTimeController.text
                        : null;
                    double? qtyPlanToSend =
                        qtyPlanController.text != req['qtyPlan']
                        ? double.tryParse(qtyPlanController.text)
                        : null;

                    // Si el estado es Final Close, preparamos StartDate y CloseDate
                    String? startDateToSend;
                    String? closeDateToSend;

                    final bool isClosing =
                        currentStatus == '9_Final Close' ||
                        (statusIdToSend != null && statusIdToSend == 103);

                    if (isClosing) {
                      // Usamos los valores actuales de los controladores
                      if (dateStartController.text.isNotEmpty &&
                          startTimeController.text.isNotEmpty) {
                        String t = startTimeController.text;
                        if (t.length == 5) t = "$t:00";
                        startDateToSend = "${dateStartController.text}T${t}Z";
                      }
                      if (dateCompleteController.text.isNotEmpty &&
                          endTimeController.text.isNotEmpty) {
                        String t = endTimeController.text;
                        if (t.length == 5) t = "$t:00";
                        closeDateToSend =
                            "${dateCompleteController.text}T${t}Z";
                      }

                      dateStartPlanToSend = null;
                      dateCompletePlanToSend = null;
                      startTimeToSend = null;
                      endTimeToSend = null;

                      // 1. Primero guardamos los datos (fechas, horas, resumen) sin cambiar el estado.
                      // 2. Luego enviamos solo el cambio de estado a Cerrado.
                      // Esto evita el error "Cannot update ... on processed record".

                      // PASO 1: Guardar datos
                      await _updateRemoteRequest(
                        req['realId'],
                        currentPriority,
                        null, // No enviamos estado aún
                        null,
                        summaryController.text,
                        dateStartPlanToSend,
                        dateCompletePlanToSend,
                        startTimeToSend,
                        endTimeToSend,
                        qtyPlanToSend,
                        startDateToSend,
                        closeDateToSend,
                      );

                      // Limpiamos variables para el PASO 2 (Solo enviar Status)
                      currentPriority = req['level']; // Restaurar o ignorar
                      summaryController.text =
                          req['description']; // Restaurar o ignorar
                      dateStartPlanToSend = null;
                      dateCompletePlanToSend = null;
                      startTimeToSend = null;
                      endTimeToSend = null;
                      qtyPlanToSend = null;
                      startDateToSend = null;
                      closeDateToSend = null;

                      // Aseguramos que se envíe el ID de cierre
                      statusIdToSend = 103;
                      statusIdentifierToSend = null;
                    }

                    // Evitar enviar fechas si no han cambiado para prevenir errores de "Update on processed record"
                    if (startDateToSend == req['startDate'])
                      startDateToSend = null;
                    if (closeDateToSend == req['closeDate'])
                      closeDateToSend = null;

                    final result = await _updateRemoteRequest(
                      req['realId'],
                      isClosing
                          ? null
                          : currentPriority, // Si cerramos, ya enviamos esto en el paso 1
                      statusIdToSend,
                      statusIdentifierToSend,
                      isClosing
                          ? null
                          : summaryController
                                .text, // Si cerramos, ya enviamos esto en el paso 1
                      dateStartPlanToSend,
                      dateCompletePlanToSend,
                      startTimeToSend,
                      endTimeToSend,
                      qtyPlanToSend,
                      startDateToSend,
                      closeDateToSend,
                    );
                    setStateDialog(() => isSaving = false);

                    if (result['success'] == true) {
                      if (mounted) {
                        setState(() {
                          req['level'] = currentPriority;
                          req['status'] = currentStatus;
                          req['description'] = summaryController.text;
                          if (currentPriority == 'Urgente') {
                            req['levelColor'] = Colors.purple;
                          } else if (currentPriority == 'Alta') {
                            req['levelColor'] = Colors.red;
                          } else if (currentPriority == 'Media') {
                            req['levelColor'] = Colors.amber.shade800;
                          } else if (currentPriority == 'Menor') {
                            req['levelColor'] = Colors.grey;
                          } else {
                            req['levelColor'] = Colors.green;
                          }
                          req['levelBgColor'] = req['levelColor'].withOpacity(
                            0.2,
                          );
                          _refreshRequest(); // Recalcular totales
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Solicitud actualizada correctamente',
                            ),
                          ),
                        );
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Error: ${result['error']}\nPayload: ${result['payload']}',
                            ),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 10),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredAlerts = _requests.where((alert) {
      // Lógica para separar Activas de Historial (Final Close)
      bool isClosed =
          alert['status'] == '9_Final Close' || alert['statusId'] == 103;
      if (_showHistory) {
        if (!isClosed) return false;
      } else {
        if (isClosed) return false;
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

    double availableHours = (_contractedHours ?? 0) - _consumedHours;
    bool isInsufficient = _estimatedHours > availableHours;

    double maxHours = _contractedHours ?? 1.0;
    if (maxHours <= 0) maxHours = 1.0;
    double consumedPct = (_consumedHours / maxHours).clamp(0.0, 1.0);
    double estimatedPct = (_estimatedHours / maxHours).clamp(
      0.0,
      1.0 - consumedPct,
    );
    int consumedFlex = (consumedPct * 1000).toInt();
    int estimatedFlex = (estimatedPct * 1000).toInt();
    int remainingFlex = 1000 - consumedFlex - estimatedFlex;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Solicitudes De Soporte')),
      drawer: const CustomDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card de Estimación de Horas
            if (_contractedHours != null)
              Card(
                color: isInsufficient
                    ? (isDark
                          ? Colors.red.shade900.withOpacity(0.5)
                          : Colors.red.shade50)
                    : (isDark
                          ? Colors.blue.shade900.withOpacity(0.5)
                          : Colors.blue.shade50),
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Consumidas: ${_consumedHours.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.red.shade300
                                  : Colors.red.shade800,
                            ),
                          ),
                          Text(
                            'Estimadas: ${_estimatedHours.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.amber.shade300
                                  : Colors.amber.shade800,
                            ),
                          ),
                          Text(
                            'Disponibles: ${availableHours.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.green.shade300
                                  : Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 12,
                          color: Colors.grey.shade300,
                          child: isInsufficient
                              ? Container(color: Colors.red)
                              : Row(
                                  children: [
                                    if (consumedFlex > 0)
                                      Expanded(
                                        flex: consumedFlex,
                                        child: Container(color: Colors.red),
                                      ),
                                    if (estimatedFlex > 0)
                                      Expanded(
                                        flex: estimatedFlex,
                                        child: Container(color: Colors.amber),
                                      ),
                                    if (remainingFlex > 0)
                                      Expanded(
                                        flex: remainingFlex,
                                        child: Container(color: Colors.green),
                                      ),
                                  ],
                                ),
                        ),
                      ),
                      if (isInsufficient) ...[
                        const SizedBox(height: 8),
                        Text(
                          '¡Advertencia! Las horas estimadas superan las disponibles. Deberá contratar más horas.',
                          style: TextStyle(
                            color: isDark
                                ? Colors.red.shade200
                                : Colors.red.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
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
                          items: ['Urgente', 'Alta', 'Media', 'Baja', 'Menor']
                              .map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              })
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedLevel = val),
                        ),
                        const SizedBox(width: 16),
                        DropdownButton<String>(
                          hint: const Text('Estado'),
                          // Validar que el valor seleccionado exista en las opciones actuales para evitar errores
                          value:
                              (_statusIdMap.isNotEmpty &&
                                  _selectedStatus != null &&
                                  !_statusIdMap.containsKey(_selectedStatus))
                              ? null
                              : _selectedStatus,
                          items:
                              (_statusIdMap.isNotEmpty
                                      ? (_statusIdMap.keys.toList()..sort())
                                      : [
                                          '1_Open',
                                          '2_Waiting on customer',
                                          '3_Closed',
                                        ])
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
                          DataColumn(label: Text('Inicio Plan')),
                          DataColumn(label: Text('Fin Plan')),
                          DataColumn(label: Text('Hora Inicio')),
                          DataColumn(label: Text('Hora Fin')),
                          DataColumn(label: Text('Cant. Plan')),
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
                              DataCell(Text(alert['dateStartPlan'])),
                              DataCell(Text(alert['dateCompletePlan'])),
                              DataCell(Text(alert['startTime'])),
                              DataCell(Text(alert['endTime'])),
                              DataCell(Text(alert['qtyPlan'])),
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
