import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/admin_view_mode.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/ui/pages/Home/Home_Controller/home_controller.dart';
import 'package:primhub/ui/pages/Home/Home_Widgets/project_dashboard_cards.dart';
import 'package:primhub/ui/pages/Home/Home_Widgets/recent_requests_table.dart';
import 'package:primhub/ui/pages/Home/Home_Widgets/support_cards.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/Shared_Custom/custom_container.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import '../../widgets/custom_drawer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeController _controller;
  final _adminViewModeManager = AdminViewModeManager();

  @override
  void initState() {
    super.initState();
    _controller = HomeController();
    _controller.initData();
    _adminViewModeManager.addListener(_onViewModeChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _adminViewModeManager.removeListener(_onViewModeChanged);
    super.dispose();
  }

  void _onViewModeChanged() {
    // Cuando el modo cambia, recargamos los datos del home que dependen de los roles
    // y forzamos un rebuild de la página para que se actualicen los widgets
    // y el drawer.
    setState(() {}); // Reconstruye la UI (AppBar, Drawer, etc.) que depende de AccessControl
    _controller.initData(); // Recarga los datos del dashboard
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
            if (AccessControl.isAdmin)
              PopupMenuButton<AdminViewMode>(
                icon: const Icon(Icons.admin_panel_settings),
                tooltip: 'Cambiar modo de vista',
                onSelected: (AdminViewMode mode) {
                  _adminViewModeManager.saveMode(mode);
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<AdminViewMode>>[const PopupMenuItem<AdminViewMode>(value: AdminViewMode.mixed, child: const Text('Modo Mixto')), const PopupMenuItem<AdminViewMode>(value: AdminViewMode.support, child: const Text('Modo Soporte')), const PopupMenuItem<AdminViewMode>(value: AdminViewMode.project, child: const Text('Modo Proyecto'))],
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refrescar',
              onPressed: () {
                // Forzar recarga completa
                _controller.initData();
              },
            ),
            if (AccessControl.isAdmin || Token.primConfig?.toLowerCase() == 'sp')
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
                    // Selector de Tercero para Soporte (Solo Admins)
                    if (AccessControl.isAdmin && AccessControl.isSupport)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: CustomContainer(
                          title: 'Filtrar Soporte por Tercero',
                          child: CustomDropdown<int?>(
                            value: _controller.selectedSupportBpId,
                            hintText: 'Seleccione un tercero',
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('Ver todos')),
                              ..._controller.supportBPartners.map((bp) => DropdownMenuItem<int>(value: bp['id'], child: Text(bp['Name'] ?? 'Tercero sin nombre'))),
                            ],
                            onChanged: (val) => _controller.updateSelectedSupportBp(val),
                          ),
                          child: _SupportBpSelector(
                              bPartners: _controller.supportBPartners,
                              selectedBpIds: _controller.selectedSupportBpIds,
                              onSelectionChanged: (ids) => _controller.updateSelectedSupportBps(ids)),
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (AccessControl.isSupport || (_controller.hasSupport && Token.primConfig == null))
                      Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        alignment: WrapAlignment.center,
                        children: [
                          ..._controller.supportContracts.map((contract) {
                            return SupportHoursCard(contract: contract, isDark: isDark, textColor: textColor);
                          }).toList(),
                          SupportRequestsCard(closedRequestsCount: _controller.closedRequestsCount, inProgressRequestsCount: _controller.inProgressRequestsCount, textColor: textColor),
                        ],
                      ),
                    if ((AccessControl.isSupport || (_controller.hasSupport && Token.primConfig == null)) && (AccessControl.isProject || (_controller.hasProject && Token.primConfig == null)) && _controller.selectedProjectIds.isNotEmpty) ...[const SizedBox(height: 30), const Divider(indent: 20, endIndent: 20), const SizedBox(height: 30)],
                    const SizedBox(height: 20),
                    // Mostrar selector solo si no es usuario de proyecto O si tiene más de 1 proyecto
                    if (_controller.projects.isNotEmpty && (AccessControl.isProject || (_controller.hasProject && Token.primConfig == null)) && (AccessControl.isAdmin || _controller.projects.length > 1))
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: CustomContainer(
                          title: 'Proyectos a Visualizar',
                          child: ProjectSelector(projects: _controller.projects, selectedProjectIds: _controller.selectedProjectIds, onSelectionChanged: _controller.updateSelectedProjects),
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (AccessControl.isProject || (_controller.hasProject && Token.primConfig == null))
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
                    if (AccessControl.isSupport || (_controller.hasSupport && Token.primConfig == null)) const SizedBox(height: 30),
                    if (AccessControl.isSupport || (_controller.hasSupport && Token.primConfig == null))
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

// Widget para el selector de Terceros de Soporte, similar al de Proyectos
class _SupportBpSelector extends StatelessWidget {
  final List<dynamic> bPartners;
  final List<int> selectedBpIds;
  final ValueChanged<List<int>> onSelectionChanged;

  const _SupportBpSelector({
    required this.bPartners,
    required this.selectedBpIds,
    required this.onSelectionChanged,
  });

  void _showMultiSelectBps(BuildContext context) async {
    final List<int> tempSelectedBpIds = List.from(selectedBpIds);
    List<dynamic> sortedBps = List.from(bPartners);
    sortedBps.sort((a, b) => (a['Name'] ?? '').compareTo(b['Name'] ?? ''));

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return CustomModal(
          title: 'Seleccionar Terceros',
          width: 500,
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SizedBox(
                height: 300,
                child: SingleChildScrollView(
                  child: ListBody(
                    children: sortedBps.map((bp) {
                      final bool isSelected = tempSelectedBpIds.contains(bp['id']);
                      return CheckboxListTile(
                        title: Text(bp['Name'] ?? 'Tercero sin nombre'),
                        value: isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              tempSelectedBpIds.add(bp['id']);
                            } else {
                              tempSelectedBpIds.remove(bp['id']);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop()),
            CustomButton(text: 'Aceptar', onPressed: () {
              onSelectionChanged(tempSelectedBpIds);
              Navigator.of(context).pop();
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String displayText;
    if (selectedBpIds.isEmpty) {
      displayText = 'Ningún tercero seleccionado';
    } else if (bPartners.isNotEmpty && selectedBpIds.length == bPartners.length) {
      displayText = 'Todos los terceros seleccionados';
    } else if (selectedBpIds.length == 1) {
      final bp = bPartners.firstWhere((p) => p['id'] == selectedBpIds.first, orElse: () => {'Name': 'Tercero no encontrado'});
      displayText = bp['Name'] ?? 'Tercero sin nombre';
    } else {
      displayText = '${selectedBpIds.length} terceros seleccionados';
    }

    return InkWell(
      onTap: () => _showMultiSelectBps(context),
      child: InputDecorator(
        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[Expanded(child: Text(displayText, overflow: TextOverflow.ellipsis)), const Icon(Icons.arrow_drop_down, color: Colors.grey)]),
      ),
    );
  }
}
