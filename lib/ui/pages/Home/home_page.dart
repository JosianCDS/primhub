import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/ui/pages/Home/Home_Controller/home_controller.dart';
import 'package:primhub/ui/pages/Home/Home_Widgets/project_dashboard_cards.dart';
import 'package:primhub/ui/pages/Home/Home_Widgets/recent_requests_table.dart';
import 'package:primhub/ui/pages/Home/Home_Widgets/support_cards.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/Shared_Custom/custom_container.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
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
              tooltip: 'Refrescar',
              onPressed: () {
                // Forzar recarga completa
                _controller.initData();
              },
            ),
            if (!AccessControl.isProject)
              IconButton(
                icon: Icon(_controller.filterSalesRepId != null ? Icons.person : Icons.group),
                tooltip: _controller.filterSalesRepId != null ? 'Viendo mis proyectos' : 'Viendo todos',
                onPressed: () {
                  setState(() {
                    // Alternar filtro en el controlador: null (Todos) vs User.userID (Mis Proyectos)
                    // Funciona igual que en la pantalla de Proyectos
                    _controller.filterSalesRepId = (_controller.filterSalesRepId == null) ? User.userID : null;
                  });
                  // Recargar datos con el nuevo filtro
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
              if (_controller.validationLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center, // Asegura centrado horizontal de hijos directos
                  children: [
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Bienvenido/a ${_controller.username}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Mostrar selector solo si no es usuario de proyecto O si tiene más de 1 proyecto
                    if (_controller.projects.isNotEmpty && (!AccessControl.isProject || _controller.projects.length > 1))
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: CustomContainer(
                          title: 'Proyectos a Visualizar',
                          child: ProjectSelector(projects: _controller.projects, selectedProjectIds: _controller.selectedProjectIds, onSelectionChanged: _controller.updateSelectedProjects),
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (_controller.hasSupport && !AccessControl.isProject) ...[
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
                            final activeProjects = _controller.projects.where((p) => _controller.selectedProjectIds.contains(p['id'])).toList();

                            if (activeProjects.isEmpty) return const SizedBox.shrink();

                            // Ajuste dinámico de columnas: Si es 1 proyecto, centramos mejor.
                            int columns = activeProjects.length == 1 ? 1 : (constraints.maxWidth < 900 ? 2 : 4);
                            double spacing = 20;
                            double itemWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;

                            // Si es un solo proyecto, limitamos el ancho máximo para que no se estire demasiado
                            if (activeProjects.length == 1 && itemWidth > 400) {
                              itemWidth = 400;
                            }

                            if (itemWidth <= 0) itemWidth = 100;

                            return Center(
                              child: Wrap(
                                spacing: spacing,
                                runSpacing: spacing,
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
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
                              ),
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
