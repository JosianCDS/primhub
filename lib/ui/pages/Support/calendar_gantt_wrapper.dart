import 'package:flutter/material.dart';
import 'package:primhub/ui/pages/Support/calendar.dart';
import 'package:primhub/ui/pages/Support/gantt_content.dart';

class CalendarGanttWrapper extends StatefulWidget {
  final List<dynamic> requests;
  const CalendarGanttWrapper({super.key, required this.requests});

  @override
  State<CalendarGanttWrapper> createState() => _CalendarGanttWrapperState();
}

class _CalendarGanttWrapperState extends State<CalendarGanttWrapper> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(context).colorScheme.outline,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: const [
              Tab(icon: Icon(Icons.calendar_month), text: 'Calendario'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Diagrama de Gantt'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              CalendarContent(requests: widget.requests),
              GanttContent(requests: widget.requests),
            ],
          ),
        ),
      ],
    );
  }
}
