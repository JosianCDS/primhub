import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/ui/pages/Home/Home_Controller/home_controller.dart';
import 'package:primhub/ui/pages/Home/Home_Widgets/project_dashboard_cards.dart';
import 'package:primhub/ui/pages/Home/Home_Widgets/recent_requests_table.dart';
import 'package:primhub/ui/pages/Home/Home_Widgets/support_cards.dart';
import 'package:primhub/ui/shared/custom_button.dart';
import 'package:primhub/ui/shared/custom_container.dart';
import 'package:primhub/ui/shared/custom_modal.dart';
import '../../widgets/custom_drawer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HomeController();
    _controller.initData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF777D8A);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final bool? shouldLogout = await showDialog<bool>(
          context: context,
          builder: (context) => CustomModal(
            title: 'Cerrar Sesión',
            content: const Text('¿Seguro que quieres cerrar sesión?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              CustomButton(text: 'Sí, salir', backgroundColor: Colors.red, onPressed: () => Navigator.pop(context, true)),
            ],
          ),
        );

        if (shouldLogout == true) {
          Token.clear();
          if (context.mounted) context.go('/login');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('PrimHub'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _controller.initData();
              },
            ),
          ],
        ),
        drawer: const CustomDrawer(),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      'Bienvenido/a ${_controller.username}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    if (_controller.projects.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: CustomContainer(
                          title: 'Proyectos a Visualizar',
                          child: ProjectSelector(projects: _controller.projects, selectedProjectIds: _controller.selectedProjectIds, onSelectionChanged: _controller.updateSelectedProjects),
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (_controller.hasSupport) ...[
                      Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        alignment: WrapAlignment.center,
                        children: [
                          SupportHoursCard(contractedHours: _controller.contractedHours, consumedHours: _controller.consumedHours, isDark: isDark, textColor: textColor),
                          SupportRequestsCard(closedRequestsCount: _controller.closedRequestsCount, inProgressRequestsCount: _controller.inProgressRequestsCount, textColor: textColor),
                        ],
                      ),
                    ],
                    if (_controller.hasSupport && _controller.hasProject && _controller.selectedProjectIds.isNotEmpty) ...[const SizedBox(height: 30), const Divider(indent: 20, endIndent: 20), const SizedBox(height: 30)],
                    if (_controller.hasProject)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            int columns = constraints.maxWidth < 900 ? 2 : 4;
                            double spacing = 20;
                            double itemWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;

                            if (itemWidth <= 0) itemWidth = 100;

                            final activeProjects = _controller.projects.where((p) => _controller.selectedProjectIds.contains(p['id'])).toList();

                            if (activeProjects.isEmpty) return const SizedBox.shrink();

                            return Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              alignment: WrapAlignment.center,
                              children: activeProjects.expand((proj) {
                                return [
                                  SizedBox(
                                    width: itemWidth,
                                    child: ProjectDurationCard(project: proj, textColor: textColor),
                                  ),
                                  SizedBox(
                                    width: itemWidth,
                                    child: ProjectDeliverablesCard(projectId: proj['id'], stats: _controller.projectStats[proj['id']] ?? {}, textColor: textColor),
                                  ),
                                ];
                              }).toList(),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 30),
                    if (!AccessControl.isProject) const SizedBox(height: 30),
                    if (!AccessControl.isProject)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: RecentRequestsTable(requests: _controller.recentRequests, isLoading: _controller.isLoading, onEdit: _controller.updateRequestLocally),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
