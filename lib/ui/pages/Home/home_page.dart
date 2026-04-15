import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/admin_view_mode.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/api/api_utils.dart';
import 'package:primhub/ui/pages/Home/Home_Controller/home_controller.dart';
import 'package:primhub/ui/pages/Home/Home_Widgets/project_dashboard_cards.dart';
import 'package:primhub/ui/pages/Home/Home_Widgets/recent_requests_table.dart';
import 'package:primhub/ui/pages/Home/Home_Widgets/support_cards.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/Shared_Custom/custom_container.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/ui/widgets/duration_formatter.dart';
import 'package:card_stack_swiper/card_stack_swiper.dart';
import '../../Shared_Custom/cardcustom.dart' show CardCustom;
import '../../widgets/custom_drawer.dart';
import 'package:primhub/ui/widgets/project_bottom_nav.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:primhub/ui/Shared_Custom/custom_skeleton.dart';
import 'package:primhub/ui/Shared_Custom/user_info_leading.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeController _controller;
  final _adminViewModeManager = AdminViewModeManager();
  final Set<int> _expandedBps = {};

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
    setState(() {});
    _controller.initData();
  }

  void _showRequestDetails(Map<String, dynamic> record) {
    // El mapa record en recentRequests tiene una estructura plana o anidada en 'original'.
    // Usamos los datos ya procesados en _applyFilters del controller.
    final descriptionHtml = record['description'] ?? '';
    final descriptionClean = record['descriptionClean'] ?? '';
    final time = record['time'] ?? '';
    final level = record['level'] ?? '';
    final status = record['status'] ?? '';
    final bpName = record['bpName'] ?? '';
    final userName = record['userName'] ?? '';
    final code = record['code'] ?? '';
    final situation = record['situation'] ?? '';
    final emailSubject = record['emailSubject'] ?? '';

    showDialog(
      context: context,
      builder: (context) => CustomModal(
        title: 'Detalle de Solicitud $code',
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: TextEditingController(text: situation),
                label: 'Tipo de Solicitud',
                readOnly: true,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: TextEditingController(text: emailSubject),
                label: 'Asunto',
                readOnly: true,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: TextEditingController(text: bpName),
                label: 'Tercero',
                readOnly: true,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: TextEditingController(text: userName),
                label: 'Usuario',
                readOnly: true,
              ),
              const SizedBox(height: 16),
              Stack(
                alignment: Alignment.topRight,
                children: [
                  CustomTextField(
                    controller: TextEditingController(text: descriptionClean),
                    label: 'Descripción',
                    readOnly: true,
                    maxLines: 5,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0, right: 4.0),
                    child: IconButton(
                      icon: const Icon(Icons.zoom_out_map),
                      tooltip: 'Ver descripción completa',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext dialogContext) {
                            return CustomModal(
                              title: 'Descripción Completa',
                              width: 600,
                              content: SizedBox(
                                height: 400,
                                child: SingleChildScrollView(
                                  child: Html(
                                    data: descriptionHtml,
                                    style: {"body": Style(margin: Margins.zero, padding: HtmlPaddings.zero)},
                                  ),
                                ),
                              ),
                              actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cerrar'))],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF777D8A);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        showLogoutConfirmation(context);
      },
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: !AccessControl.isAdmin ? 180 : null,
          leading: !AccessControl.isAdmin
              ? const UserInfoLeading()
              : Builder(
                  builder: (ctx) => IconButton(icon: const Icon(Icons.menu_rounded), tooltip: 'Menú Principal', onPressed: () => Scaffold.of(ctx).openDrawer()),
                ),
          title: const Text('Dashboard'),
          actions: [
            if (AccessControl.isAdmin)
              PopupMenuButton<AdminViewMode>(
                tooltip: 'Cambiar modo de vista',
                onSelected: (AdminViewMode mode) {
                  _adminViewModeManager.saveMode(mode);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.admin_panel_settings),
                      const SizedBox(width: 8),
                      Text(_adminViewModeManager.currentMode == AdminViewMode.support ? 'Modo Soporte' : (_adminViewModeManager.currentMode == AdminViewMode.project ? 'Modo Proyecto' : 'Modo Mixto'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
                itemBuilder: (BuildContext context) {
                  final current = _adminViewModeManager.currentMode;
                  final colorScheme = Theme.of(context).colorScheme;
                  PopupMenuItem<AdminViewMode> buildItem(AdminViewMode mode, String text) {
                    final isSelected = current == mode;
                    return PopupMenuItem<AdminViewMode>(
                      value: mode,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(color: isSelected ? colorScheme.primary.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Text(
                              text,
                              style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? colorScheme.primary : colorScheme.onSurface),
                            ),
                            if (isSelected) const Spacer(),
                            if (isSelected) Icon(Icons.check, size: 18, color: colorScheme.primary),
                          ],
                        ),
                      ),
                    );
                  }

                  return [buildItem(AdminViewMode.mixed, 'Modo Mixto'), buildItem(AdminViewMode.support, 'Modo Soporte'), buildItem(AdminViewMode.project, 'Modo Proyecto')];
                },
              ),
            if (AccessControl.isAdmin)
              PopupMenuButton<bool>(
                tooltip: 'Filtrar proyectos',
                onSelected: (bool viewingMine) {
                  _adminViewModeManager.setViewingMine(viewingMine);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_adminViewModeManager.isViewingMine ? Icons.person : Icons.group),
                      const SizedBox(width: 8),
                      Text(_adminViewModeManager.isViewingMine ? 'Mis Proyectos' : 'Todos los Proyectos', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
                itemBuilder: (BuildContext context) {
                  final colorScheme = Theme.of(context).colorScheme;
                  final isViewingMine = _adminViewModeManager.isViewingMine;
                  PopupMenuItem<bool> buildItem(bool isMineOption, String text, IconData icon) {
                    final isSelected = isViewingMine == isMineOption;
                    return PopupMenuItem<bool>(
                      value: isMineOption,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(color: isSelected ? colorScheme.primary.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Icon(icon, size: 20, color: isSelected ? colorScheme.primary : colorScheme.onSurface),
                            const SizedBox(width: 8),
                            Text(
                              text,
                              style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? colorScheme.primary : colorScheme.onSurface),
                            ),
                            if (isSelected) const Spacer(),
                            if (isSelected) Icon(Icons.check, size: 18, color: colorScheme.primary),
                          ],
                        ),
                      ),
                    );
                  }

                  return [buildItem(true, 'Mis Proyectos', Icons.person), buildItem(false, 'Todos los Proyectos', Icons.group)];
                },
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refrescar',
              onPressed: () {
                _controller.initData(forceRefresh: true);
              },
            ),
            if (!AccessControl.isAdmin)
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.red),
                tooltip: 'Cerrar Sesión',
                onPressed: () => showLogoutConfirmation(context),
              ),
          ],
        ),
        drawer: AccessControl.isAdmin ? const CustomDrawer(currentRoute: '/') : null,
        bottomNavigationBar: !AccessControl.isAdmin ? const ProjectBottomNav(currentRoute: '/') : null,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              if (_controller.validationLoading) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const CustomSkeleton(height: 40, width: 250, borderRadius: 8),
                      const SizedBox(height: 40),
                      Wrap(spacing: 20, runSpacing: 20, alignment: WrapAlignment.center, children: List.generate(3, (index) => const CustomSkeleton(height: 180, width: 350, borderRadius: 16))),
                      const SizedBox(height: 40),
                      const SkeletonTable(),
                    ],
                  ),
                );
              }
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Dashboard',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Builder(
                      builder: (context) {
                        bool hasProjectsContent = AccessControl.isProject && _controller.projects.isNotEmpty;
                        bool hasSupportContent = AccessControl.isSupport && (_controller.recentRequests.isNotEmpty || _controller.supportContracts.isNotEmpty || (AccessControl.isAdmin && _controller.supportBPartners.isNotEmpty));

                        if (!hasProjectsContent && !hasSupportContent && !_controller.isLoading) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 60.0),
                            child: Column(
                              children: [
                                Icon(Icons.dashboard_customize_outlined, size: 80, color: textColor.withOpacity(0.4)),
                                const SizedBox(height: 24),
                                Text(
                                  'Tu espacio de trabajo está listo',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.8)),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Actualmente no tienes proyectos activos ni solicitudes de soporte recientes. Cuando interactúes con la plataforma o se te asigne nueva actividad, el panel se actualizará automáticamente.',
                                  style: TextStyle(fontSize: 16, color: textColor.withOpacity(0.6)),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    if (_controller.projects.isNotEmpty && AccessControl.isProject && (AccessControl.isAdmin || _controller.projects.length > 1))
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: CustomContainer(
                          title: 'Proyectos a Visualizar',
                          action: const Icon(Icons.filter_alt_rounded, color: Colors.grey),
                          child: ProjectSelector(selectedProjectIds: _controller.selectedProjectIds, projects: _controller.projects, onSelectionChanged: _controller.updateSelectedProjects),
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (AccessControl.isProject)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final activeProjects = _controller.projects.where((p) => _controller.selectedProjectIds.contains(p['id'])).toList();

                            if (activeProjects.isEmpty) return const SizedBox.shrink();

                            int columns = activeProjects.length == 1 ? 1 : (constraints.maxWidth < 900 ? 2 : 4);
                            double spacing = 20;
                            double itemWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;

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
                                  final projId = proj['id'] is int ? proj['id'] as int : int.tryParse(proj['id'].toString()) ?? 0;
                                  return [
                                    SizedBox(
                                      width: itemWidth,
                                      child: ProjectDurationCard(project: proj, textColor: textColor, hasMetrics: _controller.projectStats[projId]?['hasMetrics'] ?? false),
                                    ),
                                    SizedBox(
                                      width: itemWidth,
                                      child: ProjectDeliverablesCard(projectId: projId, stats: _controller.projectStats[projId] ?? {}, textColor: textColor),
                                    ),
                                  ];
                                }).toList(),
                              ),
                            );
                          },
                        ),
                      ),
                    if (AccessControl.isSupport && AccessControl.isProject && _controller.selectedProjectIds.isNotEmpty) ...[const SizedBox(height: 30), const Divider(indent: 20, endIndent: 20), const SizedBox(height: 30)],
                    const SizedBox(height: 20),
                    if (AccessControl.isAdmin && AccessControl.isSupport)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: CustomContainer(
                          title: 'Filtrar Soporte por Tercero',
                          action: const Icon(Icons.filter_alt_rounded, color: Colors.grey),
                          child: _SupportBpSelector(bPartners: _controller.supportBPartners, selectedBpIds: _controller.selectedSupportBpIds, onSelectionChanged: (ids) => _controller.updateSelectedSupportBps(ids)),
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (AccessControl.isSupport) ...[
                      Builder(
                        builder: (context) {
                          final bpsToRender = AccessControl.isAdmin ? _controller.selectedSupportBpIds : (User.cBPartnerID != null ? [User.cBPartnerID!] : <int>[]);

                          if (AccessControl.isAdmin && bpsToRender.isEmpty && !_controller.isLoading) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40.0),
                                child: Text(
                                  "Selecciona el tercero para ver su informacion",
                                  style: TextStyle(fontSize: 16, color: textColor.withOpacity(0.6), fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          }

                          return Wrap(
                            spacing: 20,
                            runSpacing: 20,
                            alignment: WrapAlignment.center,
                            children: bpsToRender.map((bpId) {
                              final bpContracts = _controller.supportContracts.where((c) => c['C_BPartner_ID'] == bpId).toList();
                              final stats = _controller.requestsStatsByBp[bpId];
                              final bpInfo = _controller.supportBPartners.firstWhere((bp) => bp['id'] == bpId, orElse: () => <String, dynamic>{'Name': 'Tercero $bpId'});
                              final bpName = bpInfo['Name'];

                              final List<Widget> cards = [];

                              if (_controller.isLoading) {
                                cards.add(
                                  const CardCustom(
                                    hover: false,
                                    child: SizedBox(height: 200, width: 250, child: Center(child: CircularProgressIndicator())),
                                  ),
                                );
                              } else {
                                if (bpContracts.isNotEmpty) {
                                  if (bpContracts.length == 1) {
                                    cards.add(
                                      Stack(
                                        children: [
                                          SupportHoursCard(contract: bpContracts.first, isDark: isDark, textColor: textColor, bpName: bpName),
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: IconButton(
                                              icon: const Icon(Icons.copy, size: 20),
                                              color: textColor.withOpacity(0.5),
                                              tooltip: 'Copiar código de contrato',
                                              onPressed: () {
                                                final code = bpContracts.first['DocumentNo']?.toString() ?? '';
                                                Clipboard.setData(ClipboardData(text: code));
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código de contrato copiado')));
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else {
                                    final bool isExpanded = _expandedBps.contains(bpId);

                                    // Botón para alternar la vista
                                    cards.add(
                                      SizedBox(
                                        width: MediaQuery.of(context).size.width,
                                        child: Center(
                                          child: TextButton.icon(
                                            icon: Icon(isExpanded ? Icons.layers : Icons.grid_view),
                                            label: Text(isExpanded ? 'Apilar contratos' : 'Desplegar contratos (${bpContracts.length})'),
                                            onPressed: () {
                                              setState(() {
                                                if (isExpanded) {
                                                  _expandedBps.remove(bpId);
                                                } else {
                                                  _expandedBps.add(bpId);
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    );

                                    if (isExpanded) {
                                      // Vista de Cuadrícula (Individual)
                                      for (var contract in bpContracts) {
                                        cards.add(
                                          Stack(
                                            children: [
                                              SupportHoursCard(contract: contract, isDark: isDark, textColor: textColor, bpName: bpName),
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: IconButton(
                                                  icon: const Icon(Icons.copy, size: 20),
                                                  color: textColor.withOpacity(0.5),
                                                  tooltip: 'Copiar código de contrato',
                                                  onPressed: () {
                                                    final code = contract['DocumentNo']?.toString() ?? '';
                                                    Clipboard.setData(ClipboardData(text: code));
                                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código de contrato copiado')));
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    } else {
                                      // Vista Apilada (Swiper)
                                      cards.add(_SupportContractsSwiper(contracts: bpContracts, isDark: isDark, textColor: textColor, bpName: bpName));
                                    }
                                  }
                                }

                                if (stats != null && (((stats['closed'] as num?)?.toInt() ?? 0) > 0 || ((stats['inProgress'] as num?)?.toInt() ?? 0) > 0)) {
                                  cards.add(SupportRequestsCard(bpId: bpId, bpName: bpName, closedRequestsCount: (stats['closed'] as num?)?.toInt() ?? 0, inProgressRequestsCount: (stats['inProgress'] as num?)?.toInt() ?? 0, textColor: textColor));
                                }
                              }

                              return Wrap(spacing: 20, runSpacing: 20, alignment: WrapAlignment.center, children: cards);
                            }).toList(),
                          );
                        },
                      ),
                    ],
                    if (AccessControl.isSupport && (!AccessControl.isAdmin || _controller.selectedSupportBpIds.isNotEmpty)) const SizedBox(height: 30),
                    if (AccessControl.isSupport && (!AccessControl.isAdmin || _controller.selectedSupportBpIds.isNotEmpty))
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: RecentRequestsTable(requests: _controller.recentRequests, isLoading: _controller.isLoading, onEdit: _showRequestDetails),
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

class _SupportContractsSwiper extends StatefulWidget {
  final List<Map<String, dynamic>> contracts;
  final bool isDark;
  final Color textColor;
  final String bpName;

  const _SupportContractsSwiper({required this.contracts, required this.isDark, required this.textColor, required this.bpName});

  @override
  State<_SupportContractsSwiper> createState() => _SupportContractsSwiperState();
}

class _SupportContractsSwiperState extends State<_SupportContractsSwiper> {
  final CardStackSwiperController _swiperController = CardStackSwiperController();
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 310, // Altura incrementada para evitar overflow y dar espacio a los botones de navegación
      width: 280,
      child: Column(
        children: [
          Expanded(
            child: CardStackSwiper(
              controller: _swiperController,
              onSwipe: (previousIndex, currentIndex, direction) {
                setState(() => _currentIndex = currentIndex ?? 0);
                return true; // Permite que se complete la animación
              },
              onUndo: (previousIndex, currentIndex, direction) {
                setState(() => _currentIndex = currentIndex ?? 0);
                return true;
              },
              cardBuilder: (context, index, _, __) {
                return Stack(
                  children: [
                    SupportHoursCard(contract: widget.contracts[index], isDark: widget.isDark, textColor: widget.textColor, bpName: widget.bpName),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        color: widget.textColor.withOpacity(0.5),
                        tooltip: 'Copiar código de contrato',
                        onPressed: () {
                          final code = widget.contracts[index]['DocumentNo']?.toString() ?? '';
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código de contrato copiado')));
                        },
                      ),
                    ),
                  ],
                );
              },
              cardsCount: widget.contracts.length,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5), shape: BoxShape.circle),
                child: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: _swiperController.undo, tooltip: 'Atrás'),
              ),
              const SizedBox(width: 16),
              Text(
                '${_currentIndex + 1} / ${widget.contracts.length}',
                style: TextStyle(fontWeight: FontWeight.bold, color: widget.textColor),
              ),
              const SizedBox(width: 16),
              Container(
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5), shape: BoxShape.circle),
                child: IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 18), onPressed: () => _swiperController.swipe(CardStackSwiperDirection.right), tooltip: 'Adelante'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SupportBpSelector extends StatelessWidget {
  final List<dynamic> bPartners;
  final List<int> selectedBpIds;
  final ValueChanged<List<int>> onSelectionChanged;

  const _SupportBpSelector({required this.bPartners, required this.selectedBpIds, required this.onSelectionChanged});

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
                height: 350,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Builder(
                      builder: (context) {
                        bool? isAllSelected;
                        if (tempSelectedBpIds.length == sortedBps.length && sortedBps.isNotEmpty) {
                          isAllSelected = true;
                        } else if (tempSelectedBpIds.isEmpty) {
                          isAllSelected = false;
                        }

                        return CheckboxListTile(
                          title: const Text('Todos los terceros', style: TextStyle(fontWeight: FontWeight.bold)),
                          tristate: true,
                          value: isAllSelected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (isAllSelected == true) {
                                tempSelectedBpIds.clear();
                              } else {
                                tempSelectedBpIds.clear();
                                tempSelectedBpIds.addAll(sortedBps.map<int>((bp) => bp['id'] as int));
                              }
                            });
                          },
                        );
                      },
                    ),
                    const Divider(),
                    Expanded(
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
                    ),
                  ],
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop()),
            CustomButton(
              text: 'Filtrar',
              onPressed: () {
                onSelectionChanged(tempSelectedBpIds);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String displayText;

    // Lógica de texto
    if (selectedBpIds.isEmpty) {
      if (bPartners.isEmpty) return const SizedBox.shrink();
      displayText = 'Ningún tercero seleccionado';
    } else if (selectedBpIds.length == 1) {
      final bp = bPartners.firstWhere((p) => p['id'] == selectedBpIds.first, orElse: () => {'Name': 'Tercero no encontrado'});
      displayText = bp['Name'] ?? 'Tercero sin nombre';
    } else if (selectedBpIds.length == bPartners.length) {
      displayText = 'Todos los terceros seleccionados';
    } else {
      displayText = '${selectedBpIds.length} terceros seleccionados';
    }

    final color = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: bPartners.length > 1 ? () => _showMultiSelectBps(context) : null,
      borderRadius: BorderRadius.circular(8.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        // Agregamos el Row para incluir el texto y el icono
        child: Row(
          mainAxisSize: MainAxisSize.min, // Para que no ocupe todo el ancho
          children: [
            // Icono de filtro al principio, con el mismo color
            Icon(Icons.filter_list_alt, size: 20, color: color),
            const SizedBox(width: 8.0), // Espacio entre icono y texto
            Expanded(
              child: Text(
                displayText,
                style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
