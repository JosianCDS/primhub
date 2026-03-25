import 'package:flutter/material.dart';
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
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  DateTime? _parseDateSafely(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    String cleanStr = dateStr;
    // Reemplaza el espacio con 'T' para cumplir el estándar ISO 8601 que requiere Mac/Safari
    if (cleanStr.contains(' ') && !cleanStr.contains('T')) {
      cleanStr = cleanStr.replaceFirst(' ', 'T');
    }
    return DateTime.tryParse(cleanStr);
  }

  @override
  void initState() {
    super.initState();
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
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchProjectRequests() async {
    setState(() => _isLoading = true);

    List<Map<String, dynamic>> allReqs = [];
    try {
      // 1. Obtener solicitudes asignadas directamente al proyecto
      final pReqs = await fetchRequest(filter: "C_Project_ID eq ${widget.project['id']}");
      allReqs.addAll(pReqs);

      // 2. Obtener UUIDs de las tareas anidadas para buscar sus solicitudes
      List<String> uuids = [];
      final phases = widget.project['C_ProjectPhase'] as List? ?? [];
      for (var phase in phases) {
        final tasks = phase['C_ProjectTask'] as List? ?? [];
        for (var task in tasks) {
          final uuid = task['Record_UU'] ?? task['UUID'] ?? task['uuid'] ?? task['uid'];
          if (uuid != null) {
            uuids.add(uuid.toString());
            _uuidToTaskName[uuid.toString()] = task['Name'] ?? 'Tarea sin nombre';
          }
        }
      }
      final directTasks = widget.project['C_ProjectTask'] as List? ?? [];
      for (var task in directTasks) {
        final uuid = task['Record_UU'] ?? task['UUID'] ?? task['uuid'] ?? task['uid'];
        if (uuid != null) {
          uuids.add(uuid.toString());
          _uuidToTaskName[uuid.toString()] = task['Name'] ?? 'Tarea sin nombre';
        }
      }

      // 3. Buscar las solicitudes conectadas a esas tareas
      if (uuids.isNotEmpty) {
        for (var i = 0; i < uuids.length; i += 10) {
          final chunk = uuids.sublist(i, i + 10 > uuids.length ? uuids.length : i + 10);
          final chunkFilter = chunk.map((u) => "Record_UU eq '$u'").join(' or ');
          final tReqs = await fetchRequest(filter: "($chunkFilter)");
          allReqs.addAll(tReqs);
        }
      }
    } catch (e) {}

    if (mounted) {
      // Preprocesar fechas una sola vez para garantizar consistencia entre Calendario y Gantt
      for (var req in allReqs) {
        String? startStr = req['DateStartPlan'];
        if (startStr == null || startStr.isEmpty) startStr = req['StartDate'];
        if (startStr == null || startStr.isEmpty) startStr = req['Created'];

        if (startStr != null && startStr.isNotEmpty) {
          DateTime? start = _parseDateSafely(startStr);
          if (start != null) {
            String? endStr = req['DateCompletePlan'];
            DateTime end = (endStr != null && endStr.isNotEmpty) ? (_parseDateSafely(endStr) ?? start) : start;
            start = DateTime(start.year, start.month, start.day);
            end = DateTime(end.year, end.month, end.day);
            if (end.isBefore(start)) end = start; // Previene errores humanos donde el fin es antes del inicio
            req['_parsedStart'] = start;
            req['_parsedEnd'] = end;
          }
        }
      }

      setState(() {
        _requests = allReqs;
        _isLoading = false;
      });
    }
  }

  String _getMonthName(int month) {
    const months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return months[month - 1];
  }

  void _showDayDetails(BuildContext context, DateTime date, List<Map<String, dynamic>> dayRequests) {
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
                  if (dayRequests.isEmpty) const Text('No hay solicitudes programadas para este día.'),
                  if (dayRequests.isNotEmpty) ...[
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Builder(
                        key: ValueKey(currentIndex),
                        builder: (context) {
                          final req = dayRequests[currentIndex];
                          final statusName = req['R_Status_Name'] ?? (req['R_Status_ID'] is Map ? req['R_Status_ID']['identifier'] : '');
                          final priority = req['Priority'] is Map ? req['Priority']['identifier'] : (req['Priority'] ?? 'Media');
                          final uuid = req['Record_UU'];
                          final taskName = uuid != null ? (_uuidToTaskName[uuid.toString()] ?? 'Tarea Desconocida') : 'General del Proyecto';
                          return SizedBox(
                            height: 220,
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Center(
                                child: SingleChildScrollView(
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    title: Text(req['Summary'] ?? 'Sin asunto', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          'Tarea: $taskName',
                                          style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w600),
                                        ),
                                        Text('Ticket: ${req['DocumentNo'] ?? req['id']?.toString() ?? ''}'),
                                        if (req['_parsedStart'] != null && req['_parsedEnd'] != null) Text('En Calendario: ${(req['_parsedStart'] as DateTime).day}/${(req['_parsedStart'] as DateTime).month}/${(req['_parsedStart'] as DateTime).year} al ${(req['_parsedEnd'] as DateTime).day}/${(req['_parsedEnd'] as DateTime).month}/${(req['_parsedEnd'] as DateTime).year}'),
                                        Text('Estado: $statusName | Prioridad: $priority'),
                                      ],
                                    ),
                                    leading: const CircleAvatar(
                                      backgroundColor: Color(0xFF4F47E5),
                                      child: Icon(Icons.assignment, color: Colors.white, size: 20),
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
                            IconButton(icon: const Icon(Icons.chevron_left), onPressed: currentIndex > 0 ? () => setStateDialog(() => currentIndex--) : null),
                            Text('Solicitud ${currentIndex + 1} de ${dayRequests.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(icon: const Icon(Icons.chevron_right), onPressed: currentIndex < dayRequests.length - 1 ? () => setStateDialog(() => currentIndex++) : null),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String ganttDateText = '';
    if (_projStart != null && _projEnd != null) {
      ganttDateText = ': del ${_projStart!.day}/${_projStart!.month}/${_projStart!.year} al ${_projEnd!.day}/${_projEnd!.month}/${_projEnd!.year}';
    } else if (_projStart != null) {
      ganttDateText = ': desde el ${_projStart!.day}/${_projStart!.month}/${_projStart!.year}';
    } else if (_projEnd != null) {
      ganttDateText = ': hasta el ${_projEnd!.day}/${_projEnd!.month}/${_projEnd!.year}';
    }

    return CustomModal(
      title: 'Calendario del Proyecto: ${widget.project['Name'] ?? ''}',
      width: 1000,
      content: _isLoading
          ? const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()))
          : SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (!_isGanttView)
                        Row(
                          children: [
                            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1))),
                            Text('${_getMonthName(_focusedMonth.month)} ${_focusedMonth.year}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1))),
                          ],
                        )
                      else
                        Text('Diagrama de Gantt$ganttDateText', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, icon: Icon(Icons.calendar_month), label: Text('Calendario')),
                          ButtonSegment(value: true, icon: Icon(Icons.bar_chart_outlined), label: Text('Gantt')),
                        ],
                        selected: {_isGanttView},
                        onSelectionChanged: (set) => setState(() => _isGanttView = set.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!_isGanttView) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']
                          .map(
                            (day) => Expanded(
                              child: Center(
                                child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Expanded(
                    child: _isGanttView ? _buildGanttView() : SingleChildScrollView(controller: _verticalScrollController, child: _buildCalendarGrid()),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildLegendItem(Theme.of(context).colorScheme.primary.withOpacity(0.1), 'Duración Proyecto'),
                      const SizedBox(width: 8),
                      const Text('Prioridad Solicitudes:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      _buildLegendItem(Colors.purple, 'Urgente'),
                      _buildLegendItem(Colors.red, 'Alta'),
                      _buildLegendItem(Colors.orange, 'Media'),
                      _buildLegendItem(Colors.blue, 'Baja'),
                      _buildLegendItem(Colors.grey, 'Menor'),
                    ],
                  ),
                ],
              ),
            ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  List<Map<String, dynamic>> _getRequestsForDay(DateTime currentDayDate) {
    return _requests.where((req) {
      if (req['_parsedStart'] == null || req['_parsedEnd'] == null) return false;

      DateTime start = req['_parsedStart'];
      DateTime end = req['_parsedEnd'];

      return (currentDayDate.isAfter(start) || currentDayDate.isAtSameMomentAs(start)) && (currentDayDate.isBefore(end) || currentDayDate.isAtSameMomentAs(end));
    }).toList();
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final weekdayOffset = firstDayOfMonth.weekday - 1;
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: isMobile ? 0.7 : 1.2),
      itemCount: 42, // Siempre 6 filas de 7 días para mantener una altura fija y no dar saltos visuales
      itemBuilder: (context, index) {
        if (index < weekdayOffset || index >= daysInMonth + weekdayOffset) {
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              border: Border.all(color: theme.dividerColor, width: 0.5),
            ),
          );
        }

        final day = index - weekdayOffset + 1;
        final currentDayDate = DateTime(_focusedMonth.year, _focusedMonth.month, day);

        // Determinar si este día está dentro del ciclo de vida del proyecto
        bool isProjectDay = false;
        if (_projStart != null && _projEnd != null) {
          final s = DateTime(_projStart!.year, _projStart!.month, _projStart!.day);
          final e = DateTime(_projEnd!.year, _projEnd!.month, _projEnd!.day);
          isProjectDay = (currentDayDate.isAfter(s) || currentDayDate.isAtSameMomentAs(s)) && (currentDayDate.isBefore(e) || currentDayDate.isAtSameMomentAs(e));
        } else if (_projStart != null) {
          final s = DateTime(_projStart!.year, _projStart!.month, _projStart!.day);
          isProjectDay = currentDayDate.isAtSameMomentAs(s) || currentDayDate.isAfter(s);
        }

        // Determinar si este día tiene solicitudes activas
        final dayRequests = _getRequestsForDay(currentDayDate);

        return InkWell(
          onTap: () => _showDayDetails(context, currentDayDate, dayRequests),
          hoverColor: theme.colorScheme.primary.withOpacity(0.2),
          child: Container(
            decoration: BoxDecoration(
              color: isProjectDay ? theme.colorScheme.primary.withOpacity(0.1) : Colors.transparent,
              border: Border.all(color: theme.dividerColor, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(day.toString(), style: TextStyle(fontWeight: dayRequests.isNotEmpty ? FontWeight.bold : FontWeight.normal)),
                ),
                ...dayRequests.take(isMobile ? 1 : 3).map((req) {
                  final priority = req['Priority'] is Map ? req['Priority']['identifier'] : (req['Priority'] ?? 'Media');
                  Color reqColor = Colors.blue;
                  if (priority == 'Urgente')
                    reqColor = Colors.purple;
                  else if (priority == 'Alta')
                    reqColor = Colors.red;
                  else if (priority == 'Media')
                    reqColor = Colors.orange;
                  else if (priority == 'Menor')
                    reqColor = Colors.grey;

                  final uuid = req['Record_UU'];
                  final taskName = uuid != null ? (_uuidToTaskName[uuid.toString()] ?? 'Tarea') : 'General';

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(color: reqColor.withOpacity(0.9), borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      '$taskName: ${req['Summary'] ?? 'Solicitud'}',
                      style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }),
                if (dayRequests.length > (isMobile ? 1 : 3))
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: Text('+${dayRequests.length - (isMobile ? 1 : 3)} más', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGanttView() {
    if (_requests.isEmpty && _projStart == null) return const Center(child: Text('No hay datos para mostrar en el diagrama.'));

    List<Map<String, dynamic>> validReqs = _requests.where((r) => r['_parsedStart'] != null && r['_parsedEnd'] != null).toList();
    DateTime? minDate = _projStart;
    DateTime? maxDate = _projEnd;

    for (var req in validReqs) {
      DateTime start = req['_parsedStart'];
      DateTime end = req['_parsedEnd'];

      if (minDate == null || start.isBefore(minDate)) minDate = start;
      if (maxDate == null || end.isAfter(maxDate)) maxDate = end;
    }

    if (minDate == null || maxDate == null) return const Center(child: Text('No hay fechas válidas.'));
    if (maxDate.isBefore(minDate)) maxDate = minDate.add(const Duration(days: 30));

    minDate = minDate.subtract(const Duration(days: 2));
    maxDate = maxDate.add(const Duration(days: 2));

    int totalDays = maxDate.difference(minDate).inDays + 1;
    double dayWidth = 30.0;
    double chartWidth = totalDays * dayWidth;

    validReqs.sort((a, b) => (a['_parsedStart'] as DateTime).compareTo(b['_parsedStart'] as DateTime));

    List<Widget> dayHeaders = [];
    DateTime curr = minDate;
    for (int i = 0; i < totalDays; i++) {
      dayHeaders.add(
        Container(
          width: dayWidth,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.grey.shade300),
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Text('${curr.day}\n${_getMonthName(curr.month).substring(0, 3)}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10)),
        ),
      );
      curr = curr.add(const Duration(days: 1));
    }

    DateTime now = DateTime.now();
    now = DateTime(now.year, now.month, now.day);
    bool showToday = !now.isBefore(minDate) && !now.isAfter(maxDate);

    return SingleChildScrollView(
      controller: _verticalScrollController,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Columna Izquierda (Nombres)
          Container(
            width: 250,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade400)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 40,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: const Text('Solicitud', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ...validReqs.map((req) {
                  final uuid = req['Record_UU'];
                  final taskName = uuid != null ? (_uuidToTaskName[uuid.toString()] ?? 'Tarea') : 'General';
                  return Container(
                    height: 40,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Tooltip(
                      message: '$taskName: ${req['Summary'] ?? ''}',
                      child: Text(
                        '$taskName: ${req['Summary'] ?? ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          // Columna Derecha (Gantt)
          Expanded(
            child: SingleChildScrollView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: chartWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      child: Row(children: dayHeaders),
                    ),
                    ...validReqs.map((req) {
                      DateTime start = req['_parsedStart'];
                      DateTime end = req['_parsedEnd'];
                      int startOffset = start.difference(minDate!).inDays;
                      int duration = end.difference(start).inDays + 1;

                      final priority = req['Priority'] is Map ? req['Priority']['identifier'] : (req['Priority'] ?? 'Media');
                      Color reqColor = Colors.blue;
                      if (priority == 'Urgente')
                        reqColor = Colors.purple;
                      else if (priority == 'Alta')
                        reqColor = Colors.red;
                      else if (priority == 'Media')
                        reqColor = Colors.orange;
                      else if (priority == 'Menor')
                        reqColor = Colors.grey;

                      return Container(
                        height: 40,
                        width: chartWidth,
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              left: startOffset * dayWidth,
                              width: duration * dayWidth,
                              top: 6,
                              bottom: 6,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _isGanttView = false;
                                    _focusedMonth = DateTime(start.year, start.month, 1);
                                  });
                                  // Muestra las solicitudes del día al que navegamos en el calendario
                                  _showDayDetails(context, start, _getRequestsForDay(start));
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: reqColor.withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
