import 'package:flutter/widgets.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents.dart';
import 'package:primhub/ui/pages/Projects/Projects_Widgets/project_requests_view.dart';
import 'package:primhub/ui/pages/Projects/project_calendar_page.dart';

Widget buildDeliverablesPage() => const DeliverablesPage();
Widget buildProjectRequestsPage(
  int? projectId,
  String? filterStatus,
  String? filterType,
  String? filterCompliance,
  bool showAllGroups,
) => ProjectRequestsView(
  projectId: projectId,
  filterStatus: filterStatus,
  filterType: filterType,
  filterCompliance: filterCompliance,
  showAllGroups: showAllGroups,
);
Widget buildProjectCalendarPage(Map<String, dynamic> project) =>
    ProjectCalendarPage(project: project);
