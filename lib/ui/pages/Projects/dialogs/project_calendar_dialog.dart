import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:primhub/api/api_http.dart' as http;
import 'package:primhub/api/api_utils.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';

class ProjectCalendarDialog extends StatefulWidget {
  final Map<String, dynamic> project;

  const ProjectCalendarDialog({super.key, required this.project});

  @override
  State<ProjectCalendarDialog> createState() => _ProjectCalendarDialogState();
}

class _ProjectCalendarDialogState extends State<ProjectCalendarDialog> {
  DateTime _focusedMonth = DateTime.now();
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  DateTime? _projStart;
  DateTime? _projEnd;
  final Map<String, String> _uuidToTaskName = {};
  bool _isGanttView = false;
  final ScrollController _verticalTasksController = ScrollController();
  final ScrollController _verticalBarsController = ScrollController();
  final ScrollController _horizontalHeaderController = ScrollController();
  final ScrollController _horizontalBodyController = ScrollController();

  DateTime? _parseDateSafely(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    // Extraer YYYY-MM-DD es la forma más segura en Safari/macOS (WebKit)
    // ya que no requiere información de zona horaria o microsegundos estrictos.
    if (dateStr.length >= 10) {
      String datePart = dateStr.substring(0, 10);
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(datePart)) {
        return DateTime.tryParse(datePart);
      }
    }
    // Fallback
    String cleanStr = dateStr.replaceAll(' ', 'T');
    return DateTime.tryParse(cleanStr);
  }

  @override
  void initState() {
    super.initState();

    // Sincronizar scrolls horizontales del Gantt
    _horizontalHeaderController.addListener(() {
      if (!_horizontalHeaderController.hasClients ||
          !_horizontalBodyController.hasClients)
        return;
      if (_horizontalHeaderController.offset !=
          _horizontalBodyController.offset) {
        _horizontalBodyController.jumpTo(_horizontalHeaderController.offset);
      }
    });
    _horizontalBodyController.addListener(() {
      if (!_horizontalBodyController.hasClients ||
          !_horizontalHeaderController.hasClients)
        return;
      if (_horizontalBodyController.offset !=
          _horizontalHeaderController.offset) {
        _horizontalHeaderController.jumpTo(_horizontalBodyController.offset);
      }
    });

    // Sincronizar scrolls verticales del Gantt
    _verticalTasksController.addListener(() {
      if (!_verticalTasksController.hasClients ||
          !_verticalBarsController.hasClients)
        return;
      if (_verticalTasksController.offset != _verticalBarsController.offset) {
        _verticalBarsController.jumpTo(_verticalTasksController.offset);
      }
    });
    _verticalBarsController.addListener(() {
      if (!_verticalBarsController.hasClients ||
          !_verticalTasksController.hasClients)
        return;
      if (_verticalBarsController.offset != _verticalTasksController.offset) {
        _verticalTasksController.jumpTo(_verticalBarsController.offset);
      }
    });

    if (widget.project['DateContract'] != null) {
      _projStart = _parseDateSafely(widget.project['DateContract']);
    }
    if (widget.project['DateFinish'] != null) {
      _projEnd = _parseDateSafely(widget.project['DateFinish']);
    }
    _fetchProjectRequests();
  }

  @override
  void dispose() {
    _verticalTasksController.dispose();
    _verticalBarsController.dispose();
    _horizontalHeaderController.dispose();
    _horizontalBodyController.dispose();
    super.dispose();
  }

  Future<void> _fetchProjectRequests() async {
    setState(() => _isLoading = true);

    List<Map<String, dynamic>> allReqs = [];
    try {
      // 1. Obtener solicitudes asignadas directamente al proyecto
      final pReqs = await fetchRequest(
        filter: "C_Project_ID eq ${widget.project['id']}",
      );
      allReqs.addAll(pReqs);

      // 2. Obtener UUIDs de las tareas anidadas para buscar sus solicitudes
      final phases = widget.project['C_ProjectPhase'] as List? ?? [];
      final directTasks = widget.project['C_ProjectTask'] as List? ?? [];

      // Si no vienen expandidos (ej. si se abrió desde el Dashboard de Inicio), las buscamos en la API
      List<dynamic> loadedPhases = List.from(phases);
      List<dynamic> loadedTasks = List.from(directTasks);
      if (loadedPhases.isEmpty && loadedTasks.isEmpty) {
        try {
          final url =
              '${Endpoint.project}/${widget.project['id']}?\$expand=C_ProjectPhase(\$expand=C_ProjectTask),C_ProjectTask';
          var response = await http.get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': Token.token,
            },
          );
          if (response.statusCode == 401) {
            final refreshed = await handleTokenRefresh();
            if (refreshed) {
              response = await http.get(
                Uri.parse(url),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': Token.token,
                },
              );
            }
          }
          if (response.statusCode == 200) {
            final data = json.decode(utf8.decode(response.bodyBytes));
            loadedPhases = data['C_ProjectPhase'] as List? ?? [];
            loadedTasks = data['C_ProjectTask'] as List? ?? [];
          }
        } catch (e) {}
      }

      List<String> uuids = [];
      for (var phase in loadedPhases) {
        final tasks = phase['C_ProjectTask'] as List? ?? [];
        for (var task in tasks) {
          final uuid =
              task['Record_UU'] ?? task['UUID'] ?? task['uuid'] ?? task['uid'];
          if (uuid != null && uuid.toString().isNotEmpty) {
            uuids.add(uuid.toString());
            _uuidToTaskName[uuid.toString()] =
                task['Name'] ?? 'Tarea sin nombre';
          }
        }
      }
      for (var task in loadedTasks) {
        final uuid =
            task['Record_UU'] ?? task['UUID'] ?? task['uuid'] ?? task['uid'];
        if (uuid != null && uuid.toString().isNotEmpty) {
          uuids.add(uuid.toString());
          _uuidToTaskName[uuid.toString()] = task['Name'] ?? 'Tarea sin nombre';
        }
      }

      // 3. Buscar las solicitudes conectadas a esas tareas
      if (uuids.isNotEmpty) {
        for (var i = 0; i < uuids.length; i += 10) {
          final chunk = uuids.sublist(
            i,
            i + 10 > uuids.length ? uuids.length : i + 10,
          );
          final chunkFilter = chunk
              .map((u) => "Record_UU eq '$u'")
              .join(' or ');
          final tReqs = await fetchRequest(filter: "($chunkFilter)");
          allReqs.addAll(tReqs);
        }
      }
    } catch (e) {}

    if (mounted) {
      // Deduplicar por si una solicitud viene tanto por C_Project_ID como por Record_UU
      final uniqueReqsMap = <int, Map<String, dynamic>>{};
      for (var r in allReqs) {
        final id = r['id'];
        if (id != null) uniqueReqsMap[id] = r;
      }

      final uniqueReqs = uniqueReqsMap.values.toList();
      final List<Map<String, dynamic>> validReqs = [];

      // Preprocesar fechas una sola vez para garantizar consistencia entre Calendario y Gantt
      for (var rawReq in uniqueReqs) {
        final req = Map<String, dynamic>.from(rawReq);

        if (req['DateCompletePlan'] != null &&
            req['DateCompletePlan'].toString().isNotEmpty) {
          if (req['DateStartPlan'] == null ||
              req['DateStartPlan'].toString().isEmpty) {
            req['DateStartPlan'] = req['DateCompletePlan'];
          }
        }

        String? startStr = req['DateStartPlan'];
        if (startStr == null || startStr.isEmpty) startStr = req['StartDate'];
        if (startStr == null || startStr.isEmpty) startStr = req['Created'];

        if (startStr != null && startStr.isNotEmpty) {
          DateTime? start = _parseDateSafely(startStr);
          if (start != null) {
            String? endStr = req['DateCompletePlan'];
            DateTime end = (endStr != null && endStr.isNotEmpty)
                ? (_parseDateSafely(endStr) ?? start)
                : start;
            start = DateTime(start.year, start.month, start.day);
            end = DateTime(end.year, end.month, end.day);
            if (end.isBefore(start))
              end =
                  start; // Previene errores humanos donde el fin es antes del inicio
            req['_parsedStart'] = start;
            req['_parsedEnd'] = end;
            validReqs.add(req);
          }
        }
      }

      setState(() {
        _requests = validReqs;
        _isLoading = false;
      });
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return months[month - 1];
  }

  void _showDayDetails(
    BuildContext context,
    DateTime date,
    List<Map<String, dynamic>> dayRequests,
  ) {
    int currentIndex = 0;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return CustomModal(
              title: 'Solicitudes del ${date.day}/${date.month}/${date.year}',
              width: 600,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dayRequests.isEmpty)
                    const Text('No hay solicitudes programadas para este día.'),
                  if (dayRequests.isNotEmpty) ...[
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Builder(
                        key: ValueKey(currentIndex),
                        builder: (context) {
                          final req = dayRequests[currentIndex];
                          final statusName =
                              req['R_Status_Name'] ??
                              (req['R_Status_ID'] is Map
                                  ? req['R_Status_ID']['identifier']
                                  : '');
                          final priority = req['Priority'] is Map
                              ? req['Priority']['identifier']
                              : (req['Priority'] ?? 'Media');
                          final uuid = req['Record_UU'];
                          final taskName = uuid != null
                              ? (_uuidToTaskName[uuid.toString()] ??
                                    'Tarea Desconocida')
                              : 'General del Proyecto';
                          return SizedBox(
                            height: 220,
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Center(
                                child: SingleChildScrollView(
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    title: Text(
                                      req['Summary'] ?? 'Sin asunto',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          'Tarea: $taskName',
                                          style: const TextStyle(
                                            color: Colors.blueGrey,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Ticket: ${req['DocumentNo'] ?? req['id']?.toString() ?? ''}',
                                        ),
                                        if (req['_parsedStart'] != null &&
                                            req['_parsedEnd'] != null)
                                          Text(
                                            'En Calendario: ${(req['_parsedStart'] as DateTime).day}/${(req['_parsedStart'] as DateTime).month}/${(req['_parsedStart'] as DateTime).year} al ${(req['_parsedEnd'] as DateTime).day}/${(req['_parsedEnd'] as DateTime).month}/${(req['_parsedEnd'] as DateTime).year}',
                                          ),
                                        Text(
                                          'Estado: $statusName | Prioridad: $priority',
                                        ),
                                      ],
                                    ),
                                    leading: const CircleAvatar(
                                      backgroundColor: Color(0xFF4F47E5),
                                      child: Icon(
                                        Icons.assignment,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    isThreeLine: true,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (dayRequests.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: currentIndex > 0
                                  ? () => setStateDialog(() => currentIndex--)
                                  : null,
                            ),
                            Text(
                              'Solicitud ${currentIndex + 1} de ${dayRequests.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: currentIndex < dayRequests.length - 1
                                  ? () => setStateDialog(() => currentIndex++)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isMobile = MediaQuery.of(context).size.width < 600;

    String ganttDateText = '';
    if (_projStart != null && _projEnd != null) {
      ganttDateText =
          ' (${_projStart!.day}/${_projStart!.month} - ${_projEnd!.day}/${_projEnd!.month})';
    }

    Widget contentWidget = _isLoading
        ? const SizedBox(
            height: 400,
            child: Center(child: CircularProgressIndicator()),
          )
        : Container(
            height: isMobile ? null : MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: isMobile ? BorderRadius.zero : BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  // HEADER PREMIUM
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final bool isMobile = constraints.maxWidth < 600;
                        
                        final titleWidget = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.project['Name'] ?? 'Sin Nombre',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (!_isGanttView)
                              Text(
                                '${_getMonthName(_focusedMonth.month)} ${_focusedMonth.year}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colorScheme.outline,
                                ),
                              )
                            else
                              Text(
                                'Diagrama de Gantt$ganttDateText',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colorScheme.outline,
                                ),
                              ),
                          ],
                        );

                        final navButtons = !_isGanttView ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _HeaderNavButton(
                              icon: Icons.chevron_left,
                              onPressed: () => setState(
                                () => _focusedMonth = DateTime(
                                  _focusedMonth.year,
                                  _focusedMonth.month - 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _HeaderNavButton(
                              icon: Icons.today,
                              onPressed: () =>
                                  setState(() => _focusedMonth = DateTime.now()),
                            ),
                            const SizedBox(width: 8),
                            _HeaderNavButton(
                              icon: Icons.chevron_right,
                              onPressed: () => setState(
                                () => _focusedMonth = DateTime(
                                  _focusedMonth.year,
                                  _focusedMonth.month + 1,
                                ),
                              ),
                            ),
                          ],
                        ) : const SizedBox.shrink();

                        final toggleButtons = Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ViewToggleButton(
                                isSelected: !_isGanttView,
                                icon: Icons.calendar_month,
                                label: isMobile ? '' : 'Calendario',
                                onTap: () =>
                                    setState(() => _isGanttView = false),
                              ),
                              _ViewToggleButton(
                                isSelected: _isGanttView,
                                icon: Icons.bar_chart_outlined,
                                label: isMobile ? '' : 'Gantt',
                                onTap: () =>
                                    setState(() => _isGanttView = true),
                              ),
                            ],
                          ),
                        );

                        if (isMobile) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              titleWidget,
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  navButtons,
                                  toggleButtons,
                                ],
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: titleWidget),
                            navButtons,
                            const SizedBox(width: 16),
                            toggleButtons,
                          ],
                        );
                      },
                    ),
                  ),

                  // CALENDAR HEADER DAYS
                  if (!_isGanttView) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width < 600 ? 8.0 : 24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children:
                            ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM']
                                .map(
                                  (day) => Expanded(
                                    child: Center(
                                      child: Text(
                                        day,
                                        style: TextStyle(
                                          color: colorScheme.outline,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // MAIN CONTENT
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withOpacity(0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _isGanttView
                            ? _buildGanttView()
                            : SingleChildScrollView(
                                controller: _verticalTasksController,
                                child: _buildCalendarGrid(),
                              ),
                      ),
                    ),
                  ),

                  // LEGEND
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildLegendItem(
                          colorScheme.primary.withOpacity(0.2),
                          'Periodo Proyecto',
                          isPill: true,
                        ),
                        _buildLegendItem(const Color(0xFF4F47E5), 'Urgente'),
                        _buildLegendItem(Colors.red.shade700, 'Alta'),
                        _buildLegendItem(Colors.orange.shade800, 'Media'),
                        _buildLegendItem(Colors.blue.shade700, 'Baja'),
                        _buildLegendItem(Colors.grey.shade600, 'Menor'),
                      ],
                    ),
                  ),
                ],
              ),
            );

    if (isMobile) {
      return contentWidget;
    }

    return CustomModal(
      title: 'Seguimiento de Proyecto',
      width: 1100,
      content: contentWidget,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: colorScheme.outline),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label, {bool isPill = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isPill ? 14 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(isPill ? 2 : 4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getRequestsForDay(DateTime currentDayDate) {
    return _requests.where((req) {
      if (req['_parsedStart'] == null || req['_parsedEnd'] == null)
        return false;
      DateTime start = req['_parsedStart'];
      DateTime end = req['_parsedEnd'];
      return (currentDayDate.isAfter(start) ||
              currentDayDate.isAtSameMomentAs(start)) &&
          (currentDayDate.isBefore(end) ||
              currentDayDate.isAtSameMomentAs(end));
    }).toList();
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateUtils.getDaysInMonth(
      _focusedMonth.year,
      _focusedMonth.month,
    );
    final firstDayOfMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month,
      1,
    );
    final weekdayOffset = firstDayOfMonth.weekday - 1;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: isMobile ? 0.48 : 1.1,
      ),
      itemCount: 42,
      itemBuilder: (context, index) {
        if (index < weekdayOffset || index >= daysInMonth + weekdayOffset) {
          return Container(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.1),
          );
        }

        final day = index - weekdayOffset + 1;
        final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
        final isToday = DateUtils.isSameDay(date, DateTime.now());

        // Dentro del proyecto
        bool isProjectDay = false;
        if (_projStart != null && _projEnd != null) {
          final s = DateTime(
            _projStart!.year,
            _projStart!.month,
            _projStart!.day,
          );
          final e = DateTime(_projEnd!.year, _projEnd!.month, _projEnd!.day);
          isProjectDay =
              (date.isAfter(s) || DateUtils.isSameDay(date, s)) &&
              (date.isBefore(e) || DateUtils.isSameDay(date, e));
        }

        final dayRequests = _getRequestsForDay(date);

        return InkWell(
          onTap: () => _showDayDetails(context, date, dayRequests),
          child: Container(
            decoration: BoxDecoration(
              color: isToday
                  ? colorScheme.primary.withOpacity(0.05)
                  : (isProjectDay
                        ? colorScheme.primary.withOpacity(0.02)
                        : null),
              border: Border.all(
                color: colorScheme.outlineVariant.withOpacity(0.2),
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: isToday
                        ? BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          )
                        : null,
                    child: Text(
                      day.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isToday || dayRequests.isNotEmpty
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isToday
                            ? colorScheme.onPrimary
                            : (dayRequests.isNotEmpty
                                  ? colorScheme.onSurface
                                  : colorScheme.outline),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: dayRequests.isNotEmpty
                        ? SingleChildScrollView(
                            physics: const NeverScrollableScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: isMobile
                                  ? Column(
                            children: [
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 2,
                                runSpacing: 2,
                                children: dayRequests.take(4).map((req) {
                                  final priority = req['Priority'] is Map
                                      ? req['Priority']['identifier']
                                      : (req['Priority'] ?? 'Media');
                                  final reqColor = _getPriorityColor(priority);
                                  return Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: reqColor,
                                      shape: BoxShape.circle,
                                    ),
                                  );
                                }).toList(),
                              ),
                              if (dayRequests.length > 4)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    '+${dayRequests.length - 4}',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : Column(
                            children: [
                              ...dayRequests.take(2).map((req) {
                                final priority = req['Priority'] is Map
                                    ? req['Priority']['identifier']
                                    : (req['Priority'] ?? 'Media');
                                final reqColor = _getPriorityColor(priority);
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 2),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: reqColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: reqColor.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: reqColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          req['Summary'] ?? 'Solicitud',
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: reqColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              if (dayRequests.length > 2)
                                Text(
                                  '+${dayRequests.length - 2}',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                            ],
                          ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGanttView() {
    if (_requests.isEmpty && _projStart == null) {
      return const Center(
        child: Text('No hay datos programados para el diagrama.'),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    List<Map<String, dynamic>> validReqs = _requests
        .where((r) => r['_parsedStart'] != null && r['_parsedEnd'] != null)
        .toList();

    DateTime? minDate = _projStart;
    DateTime? maxDate = _projEnd;

    for (var req in validReqs) {
      DateTime start = req['_parsedStart'];
      DateTime end = req['_parsedEnd'];
      if (minDate == null || start.isBefore(minDate)) minDate = start;
      if (maxDate == null || end.isAfter(maxDate)) maxDate = end;
    }

    if (minDate == null || maxDate == null)
      return const Center(child: Text('Sin fechas válidas para el diagrama.'));

    minDate = minDate.subtract(const Duration(days: 2));
    maxDate = maxDate.add(const Duration(days: 5));

    int totalDays = maxDate.difference(minDate).inDays + 1;
    const double dayWidth = 40.0;
    const double rowHeight = 45.0;
    double chartWidth = totalDays * dayWidth;

    validReqs.sort(
      (a, b) => (a['_parsedStart'] as DateTime).compareTo(
        b['_parsedStart'] as DateTime,
      ),
    );

    final double leftPanelWidth = MediaQuery.of(context).size.width < 600 ? 120.0 : 200.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT: TASK NAMES (Sticky horizontal, scrollable vertical)
        Container(
              width: leftPanelWidth,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Column(
            children: [
              Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  border: Border(
                    bottom: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                child: const Text(
                  'Actividad / Tarea',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Expanded(
                child: Scrollbar(
                  controller: _verticalTasksController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _verticalTasksController,
                    child: Column(
                      children: validReqs.map((req) {
                        final uuid = req['Record_UU'];
                        final taskName = uuid != null
                            ? (_uuidToTaskName[uuid.toString()] ?? 'Tarea')
                            : 'General';
                        return Container(
                          height: rowHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: colorScheme.outlineVariant.withOpacity(
                                  0.3,
                                ),
                              ),
                            ),
                          ),
                          child: Text(
                            '$taskName: ${req['Summary'] ?? ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // RIGHT: GANTT AREA (Scrollable horizontal)
        Expanded(
          child: Scrollbar(
            controller: _horizontalBodyController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontalBodyController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: chartWidth,
                child: Column(
                  children: [
                    // DATE HEADERS (Sticky vertical)
                    Container(
                      color: colorScheme.surfaceContainerHighest.withOpacity(
                        0.3,
                      ),
                      height: 50,
                      child: Row(
                        children: List.generate(totalDays, (i) {
                          final d = minDate!.add(Duration(days: i));
                          final isWeekend = d.weekday == 6 || d.weekday == 7;
                          return Container(
                            width: dayWidth,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isWeekend
                                  ? colorScheme.outlineVariant.withOpacity(0.1)
                                  : null,
                              border: Border(
                                right: BorderSide(
                                  color: colorScheme.outlineVariant.withOpacity(
                                    0.3,
                                  ),
                                ),
                                bottom: BorderSide(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                            ),
                            child: Text(
                              '${d.day}\n${_getMonthName(d.month).substring(0, 3)}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: isWeekend
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    // BARS AREA (Scrollable vertical)
                    Expanded(
                      child: Scrollbar(
                        controller: _verticalBarsController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _verticalBarsController,
                          child: Stack(
                            children: [
                              // Weekend markers
                              Row(
                                children: List.generate(totalDays, (i) {
                                  final d = minDate!.add(Duration(days: i));
                                  return Container(
                                    width: dayWidth,
                                    height: validReqs.length * rowHeight,
                                    decoration: BoxDecoration(
                                      color: (d.weekday == 6 || d.weekday == 7)
                                          ? colorScheme.outlineVariant
                                                .withOpacity(0.05)
                                          : null,
                                      border: Border(
                                        right: BorderSide(
                                          color: colorScheme.outlineVariant
                                              .withOpacity(0.1),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              // Bars
                              Column(
                                children: validReqs.map((req) {
                                  DateTime start = req['_parsedStart'];
                                  DateTime end = req['_parsedEnd'];
                                  int startOffset = start
                                      .difference(minDate!)
                                      .inDays;
                                  int duration =
                                      end.difference(start).inDays + 1;
                                  final color = _getPriorityColor(
                                    req['Priority'] is Map
                                        ? req['Priority']['identifier']
                                        : (req['Priority'] ?? 'Media'),
                                  );

                                  return Container(
                                    height: rowHeight,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: colorScheme.outlineVariant
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          left: startOffset * dayWidth + 4,
                                          width: (duration * dayWidth) - 8,
                                          top: 10,
                                          bottom: 10,
                                          child: InkWell(
                                            onTap: () => _showDayDetails(
                                              context,
                                              start,
                                              _getRequestsForDay(start),
                                            ),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: color,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: color.withOpacity(
                                                      0.3,
                                                    ),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getPriorityColor(String priority) {
    if (priority == 'Urgente') return const Color(0xFF4F47E5);
    if (priority == 'Alta') return Colors.red.shade700;
    if (priority == 'Media') return Colors.orange.shade800;
    if (priority == 'Baja') return Colors.blue.shade700;
    return Colors.teal.shade600;
  }
}

class _HeaderNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  const _HeaderNavButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        color: Theme.of(context).colorScheme.primary,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  final bool isSelected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ViewToggleButton({
    required this.isSelected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
            ),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ]
          ],
        ),
      ),
    );
  }
}
