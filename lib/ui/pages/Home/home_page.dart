import 'package:flutter/material.dart';
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
import '../../Shared_Custom/cardcustom.dart' show CardCustom;
import '../../widgets/custom_drawer.dart';
import 'package:primhub/ui/widgets/project_bottom_nav.dart';
import 'package:primhub/ui/widgets/project_sidebar.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:primhub/ui/Shared_Custom/custom_skeleton.dart';
import 'package:primhub/ui/Shared_Custom/user_info_leading.dart';
import 'package:primhub/ui/Shared_Custom/help_icon.dart';
import 'package:flutter/services.dart'; // Para Clipboard
import 'package:primhub/api/global_cache.dart';
import 'package:primhub/ui/pages/Projects/dialogs/project_calendar_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeController _controller;
  final _adminViewModeManager = AdminViewModeManager();
  bool _isEnforcedDelayActive = false; // Desactivado el retardo obligatorio

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

  void _showAdminModeSelectionDialog(BuildContext context) {
    final current = _adminViewModeManager.currentMode;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return CustomModal(
          title: 'Seleccionar Modo de Vista',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Modo Mixto'),
                trailing: current == AdminViewMode.mixed
                    ? Icon(Icons.check, color: colorScheme.primary)
                    : null,
                onTap: () {
                  _adminViewModeManager.saveMode(AdminViewMode.mixed);
                  Navigator.pop(dialogContext);
                },
              ),
              ListTile(
                title: const Text('Modo Soporte'),
                trailing: current == AdminViewMode.support
                    ? Icon(Icons.check, color: colorScheme.primary)
                    : null,
                onTap: () {
                  _adminViewModeManager.saveMode(AdminViewMode.support);
                  Navigator.pop(dialogContext);
                },
              ),
              ListTile(
                title: const Text('Modo Proyecto'),
                trailing: current == AdminViewMode.project
                    ? Icon(Icons.check, color: colorScheme.primary)
                    : null,
                onTap: () {
                  _adminViewModeManager.saveMode(AdminViewMode.project);
                  Navigator.pop(dialogContext);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  void _showProjectFilterSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return CustomModal(
          title: 'Filtrar Proyectos',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Mis Proyectos'),
                trailing: _adminViewModeManager.isViewingMine
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  _adminViewModeManager.setViewingMine(true);
                  Navigator.pop(dialogContext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.group),
                title: const Text('Todos los Proyectos'),
                trailing: !_adminViewModeManager.isViewingMine
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  _adminViewModeManager.setViewingMine(false);
                  Navigator.pop(dialogContext);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAdminModePopupMenu() {
    return PopupMenuButton<AdminViewMode>(
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
            Text(
              _adminViewModeManager.currentMode == AdminViewMode.support
                  ? 'Modo Soporte'
                  : (_adminViewModeManager.currentMode == AdminViewMode.project
                        ? 'Modo Proyecto'
                        : 'Modo Mixto'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
      itemBuilder: (BuildContext context) {
        final current = _adminViewModeManager.currentMode;
        final colorScheme = Theme.of(context).colorScheme;
        PopupMenuItem<AdminViewMode> buildItem(
          AdminViewMode mode,
          String text,
        ) {
          final isSelected = current == mode;
          return PopupMenuItem<AdminViewMode>(
            value: mode,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                    ),
                  ),
                  if (isSelected) const Spacer(),
                  if (isSelected)
                    Icon(Icons.check, size: 18, color: colorScheme.primary),
                ],
              ),
            ),
          );
        }

        return [
          buildItem(AdminViewMode.mixed, 'Modo Mixto'),
          buildItem(AdminViewMode.support, 'Modo Soporte'),
          buildItem(AdminViewMode.project, 'Modo Proyecto'),
        ];
      },
    );
  }

  Widget _buildProjectFilterPopupMenu() {
    return PopupMenuButton<bool>(
      tooltip: 'Filtrar proyectos',
      onSelected: (bool viewingMine) {
        _adminViewModeManager.setViewingMine(viewingMine);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _adminViewModeManager.isViewingMine
                  ? Icons.person
                  : Icons.group,
            ),
            const SizedBox(width: 8),
            Text(
              _adminViewModeManager.isViewingMine
                  ? 'Mis Proyectos'
                  : 'Todos los Proyectos',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
      itemBuilder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;
        final isViewingMine = _adminViewModeManager.isViewingMine;
        PopupMenuItem<bool> buildItem(
          bool isMineOption,
          String text,
          IconData icon,
        ) {
          final isSelected = isViewingMine == isMineOption;
          return PopupMenuItem<bool>(
            value: isMineOption,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                    ),
                  ),
                  if (isSelected) const Spacer(),
                  if (isSelected)
                    Icon(Icons.check, size: 18, color: colorScheme.primary),
                ],
              ),
            ),
          );
        }

        return [
          buildItem(true, 'Mis Proyectos', Icons.person),
          buildItem(false, 'Todos los Proyectos', Icons.group),
        ];
      },
    );
  }

  List<Widget> _buildAdminAppBarActions(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    if (isMobile) {
      return [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'admin_mode') _showAdminModeSelectionDialog(context);
            if (value == 'project_filter')
              _showProjectFilterSelectionDialog(context);
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'admin_mode',
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: Text(
                  'Modo: ${_adminViewModeManager.currentMode == AdminViewMode.support ? 'Soporte' : (_adminViewModeManager.currentMode == AdminViewMode.project ? 'Proyecto' : 'Mixto')}',
                ),
              ),
            ),
            PopupMenuItem<String>(
              value: 'project_filter',
              child: ListTile(
                leading: Icon(
                  _adminViewModeManager.isViewingMine
                      ? Icons.person
                      : Icons.group,
                ),
                title: Text(
                  _adminViewModeManager.isViewingMine
                      ? 'Mis Proyectos'
                      : 'Todos',
                ),
              ),
            ),
          ],
        ),
      ];
    }
    return [
      _buildAdminModePopupMenu(),
      _buildProjectFilterPopupMenu(),
    ];
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
                                    style: {
                                      "body": Style(
                                        margin: Margins.zero,
                                        padding: HtmlPaddings.zero,
                                      ),
                                    },
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(),
                                  child: const Text('Cerrar'),
                                ),
                              ],
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showAllContractsModal(
    BuildContext context,
    List<Map<String, dynamic>> allContracts,
    String bpName,
  ) {
    // 1. Separar contratos por año y ordenarlos
    final currentYear = DateTime.now().year;
    final List<Map<String, dynamic>> currentYearContracts = [];
    final List<Map<String, dynamic>> pastContracts = [];

    for (var contract in allContracts) {
      final contractYear = DateTime.tryParse(
        contract['DateOrdered'] ?? '',
      )?.year;
      if (contractYear == currentYear) {
        currentYearContracts.add(contract);
      } else {
        pastContracts.add(contract);
      }
    }

    // Ordenar ambas listas de más reciente a más viejo
    void sortByDate(List<Map<String, dynamic>> list) {
      list.sort((a, b) {
        final dateA = DateTime.tryParse(a['DateOrdered'] ?? '');
        final dateB = DateTime.tryParse(b['DateOrdered'] ?? '');
        if (dateA == null || dateB == null) return 0;
        return dateB.compareTo(dateA); // Descending order
      });
    }

    sortByDate(currentYearContracts);
    sortByDate(pastContracts);

    showDialog(
      context: context,
      builder: (context) {
        bool showPast = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildContractList(
              List<Map<String, dynamic>> contracts, {
              bool highlight = false,
            }) {
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: contracts.length,
                itemBuilder: (context, index) {
                  final contract = contracts[index];
                  final String documentNo = contract['DocumentNo'] ?? 'N/A';
                  final String dateOrdered =
                      contract['DateOrdered']?.toString().split('T').first ??
                      'N/A';
                  final double contractedHours =
                      (contract['contractedHours'] as num?)?.toDouble() ?? 0.0;

                  return ListTile(
                    leading: Icon(
                      Icons.article_outlined,
                      color: highlight
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(documentNo),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: documentNo));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Código de contrato copiado al portapapeles',
                                ),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Icon(Icons.copy, size: 16),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text('Fecha: $dateOrdered')],
                    ),
                    trailing: Text(
                      DurationFormatter.format(contractedHours),
                      style: TextStyle(
                        fontWeight: highlight
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  );
                },
              );
            }

            return CustomModal(
              title: 'Contratos de Soporte para $bpName',
              width: 500,
              height: 450,
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contratos Activos durante este año',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    currentYearContracts.isEmpty
                        ? const Text(
                            'No hay contratos para el año actual.',
                            style: TextStyle(color: Colors.grey),
                          )
                        : buildContractList(
                            currentYearContracts,
                            highlight: true,
                          ),
                    const SizedBox(height: 16),
                    if (!showPast && pastContracts.isNotEmpty)
                      Center(
                        child: TextButton.icon(
                          icon: const Icon(Icons.history),
                          label: const Text('Ver todos'),
                          onPressed: () => setModalState(() => showPast = true),
                        ),
                      )
                    else if (showPast) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Contratos Pasados',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      pastContracts.isEmpty
                          ? const Text(
                              'No hay contratos pasados.',
                              style: TextStyle(color: Colors.grey),
                            )
                          : buildContractList(pastContracts),
                    ],
                  ],
                ),
              ),
              actions: [
                CustomButton(
                  text: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            );
          },
        );
      },
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
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    tooltip: 'Menú Principal',
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
          title: const Text('Dashboard'),
          actions: [
            if (AccessControl.isAdmin) ..._buildAdminAppBarActions(context),
            if (_controller.isSyncingBackground)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            const HelpIcon(),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refrescar',
              onPressed: () {
                GlobalCache.performSmartSync(context, () async {
                  await _controller.initData(forceRefresh: true);
                });
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
        drawer: AccessControl.isAdmin
            ? const CustomDrawer(currentRoute: '/')
            : null,
        bottomNavigationBar:
            (MediaQuery.of(context).size.width < 900 && !AccessControl.isAdmin)
            ? const ProjectBottomNav(currentRoute: '/')
            : null,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (MediaQuery.of(context).size.width >= 900 &&
                !AccessControl.isAdmin)
              const ProjectSideBar(currentRoute: '/'),
            Expanded(
              child: SafeArea(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          Builder(
                            builder: (context) {
                              bool hasProjectsContent =
                                  AccessControl.isProject &&
                                  _controller.projects.isNotEmpty;
                              bool hasSupportContent =
                                  AccessControl.isSupport &&
                                  (_controller.recentRequests.isNotEmpty ||
                                      _controller
                                          .supportProductChips
                                          .isNotEmpty ||
                                      (AccessControl.isAdmin &&
                                          _controller
                                              .supportBPartners
                                              .isNotEmpty));

                              if (!hasProjectsContent &&
                                  !hasSupportContent &&
                                  !_controller.isLoading && 
                                  !_controller.validationLoading && 
                                  !_isEnforcedDelayActive) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0,
                                    vertical: 40.0,
                                  ),
                                  child: Center(
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        maxWidth: 600,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 40.0,
                                        vertical: 48.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surface,
                                        borderRadius: BorderRadius.circular(24),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Theme.of(
                                              context,
                                            ).shadowColor.withOpacity(0.08),
                                            blurRadius: 24,
                                            offset: const Offset(0, 12),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline
                                              .withOpacity(0.1),
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(24),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.rocket_launch_rounded,
                                              size: 72,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 32),
                                          Text(
                                            'Tu espacio de trabajo está listo',
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                                ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Actualmente no tienes proyectos activos ni solicitudes recientes.',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'En cuanto se te asigne un proyecto o interactúes con la plataforma, este panel se actualizará automáticamente con tu información.',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant
                                                      .withOpacity(0.8),
                                                  height: 1.5,
                                                ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 32),
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              setState(() {
                                                _controller.initData();
                                              });
                                            },
                                            icon: const Icon(Icons.refresh),
                                            label: const Text(
                                              'Actualizar Panel',
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 24,
                                                    vertical: 12,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          if (_controller.projects.isNotEmpty &&
                              AccessControl.isProject &&
                              (AccessControl.isAdmin ||
                                  _controller.projects.length > 1))
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: CustomContainer(
                                title: 'Proyectos a Visualizar',
                                action: const Icon(
                                  Icons.filter_alt_rounded,
                                  color: Colors.grey,
                                ),
                                child: ProjectSelector(
                                  selectedProjectIds:
                                      _controller.selectedProjectIds,
                                  projects: _controller.projects,
                                  onSelectionChanged:
                                      _controller.updateSelectedProjects,
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                          if (AccessControl.isProject)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final activeProjects = _controller.projects
                                      .where(
                                        (p) => _controller.selectedProjectIds
                                            .contains(p['id']),
                                      )
                                      .toList();

                                  if (activeProjects.isEmpty)
                                    return const SizedBox.shrink();

                                  int columns = (constraints.maxWidth / 360).floor();
                                  if (columns < 1) columns = 1;
                                  if (columns > activeProjects.length) columns = activeProjects.length;

                                  double spacing = 20;
                                  double itemWidth =
                                      (constraints.maxWidth -
                                          (spacing * (columns - 1))) /
                                      columns;

                                  if (itemWidth > 420) {
                                    itemWidth = 420;
                                  }
                                  if (itemWidth > constraints.maxWidth) {
                                    itemWidth = constraints.maxWidth;
                                  }

                                  if (itemWidth <= 0) itemWidth = 100;

                                  return Center(
                                    child: Wrap(
                                      spacing: spacing,
                                      runSpacing: spacing,
                                      alignment: WrapAlignment.center,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: activeProjects.map((proj) {
                                        final projId = proj['id'] is int
                                            ? proj['id'] as int
                                            : int.tryParse(
                                                    proj['id'].toString(),
                                                  ) ??
                                                  0;
                                        final hasMetrics =
                                            _controller
                                                .projectStats[projId]?['hasMetrics'] ??
                                            false;
                                        return SizedBox(
                                          width: itemWidth,
                                          child: ProjectFullCard(
                                            project: proj,
                                            stats:
                                                _controller
                                                    .projectStats[projId] ??
                                                {},
                                            hasMetrics: hasMetrics,
                                            onCalendarTap: () => showDialog(
                                              context: context,
                                              builder: (context) =>
                                                  ProjectCalendarDialog(
                                                    project: proj,
                                                  ),
                                            ),
                                            onMetricsTap: () => context.push(
                                              '/metrics',
                                              extra: {'projectId': projId},
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          if (AccessControl.isSupport &&
                              AccessControl.isProject &&
                              _controller.selectedProjectIds.isNotEmpty) ...[
                            const SizedBox(height: 30),
                            const Divider(indent: 20, endIndent: 20),
                            const SizedBox(height: 30),
                          ],
                          const SizedBox(height: 20),
                          if (AccessControl.isAdmin && AccessControl.isSupport)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: CustomContainer(
                                title: 'Filtrar Soporte por Tercero',
                                action: const Icon(
                                  Icons.filter_alt_rounded,
                                  color: Colors.grey,
                                ),
                                child: _SupportBpSelector(
                                  bPartners: _controller.supportBPartners,
                                  selectedBpIds:
                                      _controller.selectedSupportBpIds,
                                  onSelectionChanged: (ids) =>
                                      _controller.updateSelectedSupportBps(ids),
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                          if (AccessControl.isSupport) ...[
                            if (_controller.validationLoading || _isEnforcedDelayActive)
                              Column(
                                children: [
                                  Wrap(
                                    spacing: 20,
                                    runSpacing: 20,
                                    alignment: WrapAlignment.center,
                                    children: List.generate(
                                      3,
                                      (index) => const CustomSkeleton(
                                        height: 180,
                                        width: 350,
                                        borderRadius: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                  const SkeletonTable(),
                                ],
                              )
                            else
                              Builder(
                                builder: (context) {
                                  final bpsToRender = AccessControl.isAdmin
                                      ? _controller.selectedSupportBpIds
                                      : (User.cBPartnerID != null
                                            ? [User.cBPartnerID!]
                                            : <int>[]);

                                  if (AccessControl.isAdmin &&
                                      bpsToRender.isEmpty &&
                                      !_controller.isLoading) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 40.0,
                                      ),
                                      child: Text(
                                        "Selecciona el tercero para ver su informacion",
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color: textColor.withOpacity(0.6),
                                            ),
                                      ),
                                    ),
                                  );
                                }

                                return Column(
                                  children: [
                                    Wrap(
                                      spacing: 20,
                                      runSpacing: 20,
                                      alignment: WrapAlignment.center,
                                      children: _controller.supportProductChips
                                          .where((chip) {
                                            final rawBp = chip['C_BPartner_ID'];
                                            final chipBpId = rawBp is Map
                                                ? (rawBp['id'] as num?)?.toInt()
                                                : (rawBp as num?)?.toInt();

                                            final isActive =
                                                chip['IsActive'] == 'Y' ||
                                                chip['IsActive'] == true;
                                            return bpsToRender.contains(
                                                  chipBpId,
                                                ) &&
                                                isActive;
                                          })
                                          .map((chip) {
                                            final rawBp = chip['C_BPartner_ID'];
                                            final chipBpId = rawBp is Map
                                                ? (rawBp['id'] as num?)?.toInt()
                                                : (rawBp as num?)?.toInt();
                                            final bpInfo = _controller
                                                .supportBPartners
                                                .firstWhere(
                                                  (bp) => bp['id'] == chipBpId,
                                                  orElse: () =>
                                                      <String, dynamic>{
                                                        'Name':
                                                            'Tercero $chipBpId',
                                                      },
                                                );
                                            final bpName = bpInfo['Name'];

                                            // Stats globales del BP para los contadores de solicitudes (no por chip, ya que no hay link directo usualmente)
                                            final stats = _controller
                                                .requestsStatsByBp[chipBpId];

                                            return SizedBox(
                                              width: 350,
                                              child: UnifiedSupportCard(
                                                isLoading:
                                                    _controller.isLoading,
                                                bpName: bpName,
                                                productLabel:
                                                    chip['Description'],
                                                frequency:
                                                    chip['FrequencyType'] is Map
                                                    ? chip['FrequencyType']['identifier']
                                                    : chip['FrequencyType'],
                                                serviceStartDate:
                                                    chip['service_start_date'],
                                                serviceFinishDate:
                                                    chip['service_finish_date'],
                                                acquiredHours:
                                                    (chip['Qty'] as num?)
                                                        ?.toDouble() ??
                                                    0.0,
                                                inProgressHours:
                                                    (chip['inProgressHours']
                                                            as num?)
                                                        ?.toDouble() ??
                                                    0.0,
                                                consumedHours:
                                                    (chip['consumedHours']
                                                            as num?)
                                                        ?.toDouble() ??
                                                    0.0,
                                                inProgressRequestsCount:
                                                    (chip['inProgressRequestsCount']
                                                            as num?)
                                                        ?.toInt() ??
                                                    0,
                                                closedRequestsCount:
                                                    (chip['closedRequestsCount']
                                                            as num?)
                                                        ?.toInt() ??
                                                    0,
                                                onInProgressTap: () {
                                                  context.push(
                                                    '/my-requests',
                                                    extra: {
                                                      'bpId': chipBpId,
                                                      'chipId': chip['id'],
                                                      'showHistory': false,
                                                    },
                                                  );
                                                },
                                                onClosedTap: () {
                                                  context.push(
                                                    '/support',
                                                    extra: {
                                                      'bpId': chipBpId,
                                                      'chipId': chip['id'],
                                                    },
                                                  );
                                                },
                                                onAvailableHoursTap: () {
                                                  context.push(
                                                    '/support',
                                                    extra: {
                                                      'bpId': chipBpId,
                                                      'chipId': chip['id'],
                                                    },
                                                  );
                                                },
                                                onShowAllContracts: () =>
                                                    _showAllContractsModal(
                                                      context,
                                                      _controller
                                                          .supportProductChips
                                                          .where((c) {
                                                            final rawBp =
                                                                c['C_BPartner_ID'];
                                                            final cBpId =
                                                                rawBp is Map
                                                                ? (rawBp['id']
                                                                          as num?)
                                                                      ?.toInt()
                                                                : (rawBp as num?)
                                                                      ?.toInt();
                                                            return cBpId ==
                                                                chipBpId;
                                                          })
                                                          .toList(),
                                                      bpName,
                                                    ),
                                              ),
                                            );
                                          })
                                          .toList(),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                          if (AccessControl.isSupport &&
                              (!AccessControl.isAdmin ||
                                  _controller.selectedSupportBpIds.isNotEmpty) && 
                              !(_controller.validationLoading || _isEnforcedDelayActive)) ...[
                            const SizedBox(height: 30),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: RecentRequestsTable(
                                requests: _controller.recentRequests,
                                isLoading: _controller.isLoading,
                                onEdit: _showRequestDetails,
                              ),
                            ),
                          ],
                          const SizedBox(height: 100),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportBpSelector extends StatelessWidget {
  final List<dynamic> bPartners;
  final List<int> selectedBpIds;
  final ValueChanged<List<int>> onSelectionChanged;

  // Constructor con const para optimización
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
        String searchQuery = ''; // Variable de estado para la búsqueda
        return CustomModal(
          title: 'Seleccionar Terceros',
          width: 500,
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              // Filtrar la lista de terceros basada en la búsqueda
              final filteredBps = sortedBps.where((bp) {
                return (bp['Name'] ?? '').toLowerCase().contains(
                  searchQuery.toLowerCase(),
                );
              }).toList();

              return SizedBox(
                height: 350,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Campo de búsqueda
                    CustomTextField(
                      hintText: 'Buscar tercero...',
                      prefixIcon: const Icon(Icons.search),
                      onChanged: (val) => setState(() => searchQuery = val),
                    ),
                    const SizedBox(height: 10),
                    Builder(
                      builder: (context) {
                        bool? isAllSelected;
                        if (tempSelectedBpIds.length == filteredBps.length &&
                            filteredBps.isNotEmpty) {
                          isAllSelected = true;
                        } else if (tempSelectedBpIds.isEmpty) {
                          isAllSelected = false;
                        }

                        return CheckboxListTile(
                          title: const Text(
                            'Todos los terceros',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          tristate: true,
                          value: isAllSelected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (isAllSelected == true) {
                                tempSelectedBpIds.clear();
                              } else {
                                tempSelectedBpIds.clear();
                                tempSelectedBpIds.addAll(
                                  filteredBps.map<int>((bp) => bp['id'] as int),
                                ); // Usar filteredBps aquí
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
                          // Usar filteredBps aquí
                          children: filteredBps.map((bp) {
                            final bool isSelected = tempSelectedBpIds.contains(
                              bp['id'],
                            );
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
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
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

    final bool isSyncing =
        GlobalCache.bPartners.isEmpty && !GlobalCache.isDataLoaded;

    // Lógica de texto
    if (isSyncing) {
      displayText = 'Sincronizando terceros...';
    } else if (selectedBpIds.isEmpty) {
      if (bPartners.isEmpty) return const SizedBox.shrink();
      displayText = 'Ningún tercero seleccionado';
    } else if (selectedBpIds.length == 1) {
      final bp = bPartners.firstWhere(
        (p) => p['id'] == selectedBpIds.first,
        orElse: () => {'Name': 'Tercero no encontrado'},
      );
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
                style: TextStyle(
                  fontSize: 16,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSyncing)
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
