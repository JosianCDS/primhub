import 'package:flutter/widgets.dart';
import 'package:primhub/ui/pages/Metrics/metrics.dart';
import 'package:primhub/ui/pages/Metrics/metrics_requests_page.dart';
import 'package:primhub/ui/pages/Metrics/rep_workload_page.dart';
import 'package:primhub/ui/pages/Metrics/client_workload_page.dart';

Widget buildMetricsPage() => const MetricsPage();
Widget buildRepWorkloadPage() => const RepWorkloadPage();
Widget buildClientWorkloadPage() => const ClientWorkloadPage();
Widget buildMetricRequestsPage(
  int? projectId,
  String? filterStatus,
  String? filterType,
) => ProjectRequestsPage(
  projectId: projectId,
  filterStatus: filterStatus,
  filterType: filterType,
);
