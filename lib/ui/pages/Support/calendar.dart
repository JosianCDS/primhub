import 'package:flutter/material.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';

class CalendarContent extends StatefulWidget {
  final List<dynamic> requests;
  const CalendarContent({super.key, required this.requests});

  @override
  State<CalendarContent> createState() => _CalendarContentState();
}

class _CalendarContentState extends State<CalendarContent> {
  DateTime _focusedMonth = DateTime.now();
  List<Map<String, dynamic>> _processedRequests = [];

  @override
  void initState() {
    super.initState();
    _processRequests();
  }

  DateTime? _parseDateSafely(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    // Extracción estricta para compatibilidad universal con macOS
    if (dateStr.length >= 10) {
      String datePart = dateStr.substring(0, 10);
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(datePart)) {
        return DateTime.tryParse(datePart);
      }
    }
    String cleanStr = dateStr.replaceAll(' ', 'T');
    return DateTime.tryParse(cleanStr);
  }

  @override
  void didUpdateWidget(CalendarContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.requests != oldWidget.requests) {
      _processRequests();
    }
  }

  void _processRequests() {
    _processedRequests = [];
    for (var rawReq in widget.requests) {
      final req = Map<String, dynamic>.from(rawReq);
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
          if (end.isBefore(start)) end = start;
          req['_parsedStart'] = start;
          req['_parsedEnd'] = end;
          _processedRequests.add(req);
        }
      }
    }
    setState(() {});
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
                    if (dayRequests.length > 1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(icon: const Icon(Icons.chevron_left), onPressed: currentIndex > 0 ? () => setStateDialog(() => currentIndex--) : null),
                          Text('Solicitud ${currentIndex + 1} de ${dayRequests.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.chevron_right), onPressed: currentIndex < dayRequests.length - 1 ? () => setStateDialog(() => currentIndex++) : null),
                        ],
                      ),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Builder(
                        key: ValueKey(currentIndex),
                        builder: (context) {
                          final req = dayRequests[currentIndex];
                          final statusName = req['R_Status_Name'] ?? (req['R_Status_ID'] is Map ? req['R_Status_ID']['identifier'] : '');
                          final priority = req['Priority'] is Map ? req['Priority']['identifier'] : (req['Priority'] ?? 'Media');
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

  List<Map<String, dynamic>> _getRequestsForDay(DateTime currentDayDate) {
    return _processedRequests.where((req) {
      if (req['_parsedStart'] == null || req['_parsedEnd'] == null) return false;
      DateTime start = req['_parsedStart'];
      DateTime end = req['_parsedEnd'];
      return (currentDayDate.isAfter(start) || currentDayDate.isAtSameMomentAs(start)) && (currentDayDate.isBefore(end) || currentDayDate.isAtSameMomentAs(end));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // Este SingleChildScrollView es el contenido del body del Scaffold padre
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1))),
                  Text('${_getMonthName(_focusedMonth.month)} ${_focusedMonth.year}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
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
          Card(
            elevation: 4,
            child: Padding(padding: const EdgeInsets.all(16.0), child: _buildCalendarGrid()),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
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
      itemCount: 42,
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

        final dayRequests = _getRequestsForDay(currentDayDate);

        return InkWell(
          onTap: () => _showDayDetails(context, currentDayDate, dayRequests),
          hoverColor: theme.colorScheme.primary.withOpacity(0.2),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
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

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(color: reqColor.withOpacity(0.9), borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      req['Summary'] ?? 'Solicitud',
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
}
