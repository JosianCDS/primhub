import 'package:flutter/material.dart';
import 'package:primhub/ui/shared/custom_inputs.dart';
import 'package:primhub/ui/shared/custom_modal.dart';
import '../../shared/custom_button.dart';

class CalendarTab extends StatefulWidget {
  final List<dynamic> requests;
  const CalendarTab({super.key, required this.requests});

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  final List<Map<String, dynamic>> _events = [
    {'date': DateTime(2025, 11, 15), 'description': 'Entrega hito 3'},
    {
      'date': DateTime(2025, 11, 20),
      'description': 'Reunión de seguimiento semanal',
    },
    {'date': DateTime(2025, 12, 1), 'description': 'Cierre de sprint'},
  ];

  DateTime _focusedMonth = DateTime.now();

  void _addEvent() {
    DateTime? selectedDate;
    final TextEditingController descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return CustomModal(
            title: 'Agregar Evento',
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: descController,
                  label: 'Breve descripción',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      selectedDate == null
                          ? 'Seleccionar fecha'
                          : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _focusedMonth,
                          firstDate: DateTime(1999),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setStateDialog(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                  ],
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
                onPressed: () {
                  if (selectedDate != null && descController.text.isNotEmpty) {
                    setState(() {
                      _events.add({
                        'date': selectedDate!,
                        'description': descController.text,
                      });
                      _events.sort(
                        (a, b) => (a['date'] as DateTime).compareTo(
                          b['date'] as DateTime,
                        ),
                      );
                    });
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _editEvent(BuildContext context, Map<String, dynamic> event) {
    final TextEditingController descController = TextEditingController(
      text: event['description'],
    );
    DateTime selectedDate = event['date'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return CustomModal(
            title: 'Editar Evento',
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: descController,
                  label: 'Descripción',
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Fecha: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(1999),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setStateDialog(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() => _events.remove(event));
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Eliminar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              CustomButton(
                text: 'Guardar',
                onPressed: () {
                  if (descController.text.isNotEmpty) {
                    setState(() {
                      event['description'] = descController.text;
                      event['date'] = selectedDate;
                      _events.sort(
                        (a, b) => (a['date'] as DateTime).compareTo(
                          b['date'] as DateTime,
                        ),
                      );
                    });
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _selectMonthYear(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _focusedMonth,
      firstDate: DateTime(1999),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null &&
        (picked.year != _focusedMonth.year ||
            picked.month != _focusedMonth.month)) {
      setState(() {
        _focusedMonth = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  void _showDayDetails(BuildContext context, DateTime date) {
    final eventsForDay = _events
        .where((e) => DateUtils.isSameDay(e['date'] as DateTime, date))
        .toList();

    final requestsForDay = widget.requests.where((req) {
      if (req['DateStartPlan'] == null) return false;
      try {
        DateTime start = DateTime.parse(req['DateStartPlan']);
        DateTime end = req['DateCompletePlan'] != null
            ? DateTime.parse(req['DateCompletePlan'])
            : start;

        // Normalizar fechas (sin hora)
        start = DateTime(start.year, start.month, start.day);
        end = DateTime(end.year, end.month, end.day);
        final current = DateTime(date.year, date.month, date.day);

        return (current.isAfter(start) || current.isAtSameMomentAs(start)) &&
            (current.isBefore(end) || current.isAtSameMomentAs(end));
      } catch (e) {
        return false;
      }
    }).toList();

    showDialog(
      context: context,
      builder: (context) {
        return CustomModal(
          title: 'Detalles del ${date.day}/${date.month}/${date.year}',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eventsForDay.isEmpty && requestsForDay.isEmpty)
                const Text(
                  'No hay eventos programados para este día.\n\nAquí se muestra una descripción más extensa del día seleccionado, permitiendo ver notas o recordatorios adicionales.',
                ),
              if (eventsForDay.isNotEmpty)
                ...eventsForDay.map((e) {
                  return InkWell(
                    onTap: () {
                      Navigator.pop(context); // Close details
                      _editEvent(context, e); // Open edit
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e['description'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Click para editar. Detalles adicionales del evento: Hora de inicio, ubicación, etc.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              if (requestsForDay.isNotEmpty) ...[
                const Divider(),
                const Text(
                  'Solicitudes:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...requestsForDay.map((req) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(req['Summary'] ?? 'Sin asunto'),
                    subtitle: Text(req['DocumentNo'] ?? ''),
                    leading: const Icon(Icons.assignment, color: Colors.blue),
                    trailing: Text(
                      req['R_Status_Name'] ?? '',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }),
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
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Calendario',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => setState(
                          () => _focusedMonth = DateTime(
                            _focusedMonth.year,
                            _focusedMonth.month - 1,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _selectMonthYear(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 8.0,
                          ),
                          child: Text(
                            '${_getMonthName(_focusedMonth.month)} ${_focusedMonth.year}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => setState(
                          () => _focusedMonth = DateTime(
                            _focusedMonth.year,
                            _focusedMonth.month + 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']
                        .map(
                          (day) => Expanded(
                            child: Center(
                              child: Text(
                                day,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  _buildCalendarGrid(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
    final isMobile = MediaQuery.of(context).size.width < 600;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: isMobile ? 0.5 : 1.0,
      ),
      itemCount: daysInMonth + weekdayOffset,
      itemBuilder: (context, index) {
        if (index < weekdayOffset) return const SizedBox();

        final day = index - weekdayOffset + 1;
        final currentDayDate = DateTime(
          _focusedMonth.year,
          _focusedMonth.month,
          day,
        );
        final hasEvent = _events.any(
          (e) => DateUtils.isSameDay(e['date'] as DateTime, currentDayDate),
        );

        // Filtrar solicitudes que cubren este día
        final dayRequests = widget.requests.where((req) {
          if (req['DateStartPlan'] == null) return false;
          try {
            DateTime start = DateTime.parse(req['DateStartPlan']);
            DateTime end = req['DateCompletePlan'] != null
                ? DateTime.parse(req['DateCompletePlan'])
                : start;

            start = DateTime(start.year, start.month, start.day);
            end = DateTime(end.year, end.month, end.day);
            final current = DateTime(
              currentDayDate.year,
              currentDayDate.month,
              currentDayDate.day,
            );

            return (current.isAfter(start) ||
                    current.isAtSameMomentAs(start)) &&
                (current.isBefore(end) || current.isAtSameMomentAs(end));
          } catch (e) {
            return false;
          }
        }).toList();

        // Ordenar para mantener consistencia visual entre días
        dayRequests.sort(
          (a, b) =>
              (a['DateStartPlan'] ?? '').compareTo(b['DateStartPlan'] ?? ''),
        );

        return InkWell(
          onTap: () => _showDayDetails(context, currentDayDate),
          hoverColor: Colors.blue.withOpacity(0.1),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Text(day.toString())),
              if (hasEvent)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ...dayRequests.take(3).map((req) {
                DateTime start = DateTime.parse(req['DateStartPlan']);
                DateTime end = req['DateCompletePlan'] != null
                    ? DateTime.parse(req['DateCompletePlan'])
                    : start;
                start = DateTime(start.year, start.month, start.day);
                end = DateTime(end.year, end.month, end.day);
                final current = DateTime(
                  currentDayDate.year,
                  currentDayDate.month,
                  currentDayDate.day,
                );

                bool isStart = current.isAtSameMomentAs(start);
                bool isEnd = current.isAtSameMomentAs(end);

                return Container(
                  margin: EdgeInsets.only(
                    top: 2,
                    left: isStart ? 4 : 0,
                    right: isEnd ? 4 : 0,
                  ),
                  height: 14,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.7),
                    borderRadius: BorderRadius.horizontal(
                      left: isStart ? const Radius.circular(4) : Radius.zero,
                      right: isEnd ? const Radius.circular(4) : Radius.zero,
                    ),
                  ),
                  child: Text(
                    req['Summary'] ?? '',
                    style: const TextStyle(fontSize: 8, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }),
              if (dayRequests.length > 3)
                const Center(
                  child: Text('...', style: TextStyle(fontSize: 8, height: 1)),
                ),
            ],
          ),
        );
      },
    );
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
}
