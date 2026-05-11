import 'package:flutter/material.dart';
import 'package:primhub/ui/pages/Metrics/custom_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/ui/Shared_Custom/custom_container.dart';
import '../../../theme/colors.dart';
import '../../widgets/custom_drawer.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/admin_view_mode.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/api/contract_api.dart';
import 'package:primhub/api/global_cache.dart';
import 'package:primhub/ui/widgets/project_bottom_nav.dart';
import 'package:primhub/api/api_utils.dart';
import 'package:primhub/ui/Shared_Custom/custom_skeleton.dart';
import 'package:primhub/ui/Shared_Custom/user_info_leading.dart';

// Importante: Asegúrate de que esta ruta sea la correcta para tu clase GraphicsFunctions
import 'graphic_functions.dart';

class MetricsPage extends StatefulWidget {
  const MetricsPage({super.key});
  @override
  State<MetricsPage> createState() => _MetricsPageState();
}

class _MetricsPageState extends State<MetricsPage> {
  bool _isLoading = true;
  int? _selectedProjectId;
  List<dynamic> _projects = [];

  final _adminViewModeManager = AdminViewModeManager();

  bool _isInit = true;

  bool _isLoadingSupport = true;
  List<double> _supportPriorityValues = [];
  List<String> _supportPriorityLabels = [];
  List<double> _supportStatusValues = [];
  List<String> _supportStatusLabels = [];

  int? _supportSelectedYear;
  int? _supportSelectedBpId;
  List<Map<String, dynamic>> _supportBPartners = [];

  // Datos para los gráficos
  List<double> _statusValues = [];
  List<String> _statusLabels = [];
  List<double> _complianceValues = [];
  List<String> _complianceLabels = [];
  List<double> _modulePercentageValues = [];
  List<String> _moduleLabels = [];
  List<String> _moduleFullLabels = [];
  List<double> _moduleTerminadaValues = [];
  List<double> _modulePendienteValues = [];
  List<double> _moduleEsperaValues = [];

  @override
  void initState() {
    super.initState();
    _adminViewModeManager.addListener(_onViewModeChanged);
    if (AccessControl.canViewProjectCharts) {
      _loadProjects();
    }
    if (AccessControl.canViewSupportCharts) {
      _loadSupportBPartners();
      _loadSupportMetrics();
    }
    GlobalCache.backgroundSyncNotifier.addListener(_onBackgroundSyncChanged);
  }

  void _onBackgroundSyncChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      Object? extra;
      try {
        extra = GoRouterState.of(context).extra;
      } catch (_) {}

      if (extra is Map && extra['projectId'] != null) {
        _selectedProjectId = extra['projectId'];
      }
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _adminViewModeManager.removeListener(_onViewModeChanged);
    GlobalCache.backgroundSyncNotifier.removeListener(_onBackgroundSyncChanged);
    super.dispose();
  }

  void _onViewModeChanged() {
    setState(() {});
    if (AccessControl.canViewProjectCharts) {
      _loadProjects();
    }
    if (AccessControl.canViewSupportCharts) {
      _loadSupportBPartners();
      _loadSupportMetrics();
    }
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
                trailing: current == AdminViewMode.mixed ? Icon(Icons.check, color: colorScheme.primary) : null,
                onTap: () {
                  _adminViewModeManager.saveMode(AdminViewMode.mixed);
                  Navigator.pop(dialogContext);
                },
              ),
              ListTile(
                title: const Text('Modo Soporte'),
                trailing: current == AdminViewMode.support ? Icon(Icons.check, color: colorScheme.primary) : null,
                onTap: () {
                  _adminViewModeManager.saveMode(AdminViewMode.support);
                  Navigator.pop(dialogContext);
                },
              ),
              ListTile(
                title: const Text('Modo Proyecto'),
                trailing: current == AdminViewMode.project ? Icon(Icons.check, color: colorScheme.primary) : null,
                onTap: () {
                  _adminViewModeManager.saveMode(AdminViewMode.project);
                  Navigator.pop(dialogContext);
                },
              ),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cerrar'))],
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
                trailing: _adminViewModeManager.isViewingMine ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
                onTap: () {
                  _adminViewModeManager.setViewingMine(true);
                  Navigator.pop(dialogContext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.group),
                title: const Text('Todos los Proyectos'),
                trailing: !_adminViewModeManager.isViewingMine ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
                onTap: () {
                  _adminViewModeManager.setViewingMine(false);
                  Navigator.pop(dialogContext);
                },
              ),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cerrar'))],
        );
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
            if (value == 'project_filter') _showProjectFilterSelectionDialog(context);
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'admin_mode',
              child: ListTile(leading: const Icon(Icons.admin_panel_settings), title: Text('Modo: ${_adminViewModeManager.currentMode == AdminViewMode.support ? 'Soporte' : (_adminViewModeManager.currentMode == AdminViewMode.project ? 'Proyecto' : 'Mixto')}')),
            ),
            PopupMenuItem<String>(
              value: 'project_filter',
              child: ListTile(leading: Icon(_adminViewModeManager.isViewingMine ? Icons.person : Icons.group), title: Text(_adminViewModeManager.isViewingMine ? 'Mis Proyectos' : 'Todos')),
            ),
          ],
        ),
      ];
    }
    return [_buildAdminModePopupMenu(), _buildProjectFilterPopupMenu()];
  }

  Future<void> _loadSupportBPartners() async {
    if (AccessControl.isAdmin) {
      // Aprovechamos los terceros ya cacheados si están disponibles
      if (GlobalCache.isDataLoaded && GlobalCache.bPartners.isNotEmpty) {
        if (mounted) {
          setState(() {
            _supportBPartners = GlobalCache.bPartners.map<Map<String, dynamic>>((e) => {'id': e['id'] ?? e['C_BPartner_ID'], 'Name': e['Name'] ?? 'Sin Nombre'}).toList();
          });
        }
      } else {
        final bps = await ContractApi.getBPartnersWithProductChips();
        if (mounted) {
          setState(() {
            _supportBPartners = bps;
          });
          try {
            final extraBps = await ProjectsLogic().fetchBPartners();
            if (mounted) {
              setState(() {
                _supportBPartners = extraBps.map<Map<String, dynamic>>((e) => {'id': e['id'] ?? e['C_BPartner_ID'], 'Name': e['Name'] ?? 'Sin Nombre'}).toList();
              });
            }
          } catch (_) {}
        }
      }
    }
  }

  Future<void> _loadProjects() async {
    try {
      int? bPartnerIdForQuery;
      if (AccessControl.isAdmin) {
        bPartnerIdForQuery = _adminViewModeManager.isViewingMine ? (User.cBPartnerID ?? -1) : null;
      } else if (AccessControl.isProject) {
        bPartnerIdForQuery = User.cBPartnerID;
      }

      final projects = await ProjectsLogic().fetchProjectsForDropdown(bPartnerId: bPartnerIdForQuery);
      if (mounted) {
        setState(() {
          _projects = projects;
          if (_projects.isNotEmpty) {
            if (_selectedProjectId == null || !_projects.any((p) => p['id'] == _selectedProjectId)) {
              _selectedProjectId = _projects.first['id'];
            }
          } else {
            _selectedProjectId = null;
          }
        });
        if (_selectedProjectId != null) {
          _loadMetrics();
        } else {
          setState(() {
            _isLoading = false;
            _statusLabels = [];
            _statusValues = [];
            _complianceLabels = [];
            _complianceValues = [];
            _moduleLabels = [];
            _modulePercentageValues = [];
            _moduleTerminadaValues = [];
            _modulePendienteValues = [];
            _moduleEsperaValues = [];
            _moduleFullLabels = [];
          });
        }
      }
    } catch (e) {
      debugPrint("Error cargando proyectos: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _projects = [];
        });
      }
    }
  }

  Future<void> _loadMetrics() async {
    if (_selectedProjectId == null) return;
    setState(() => _isLoading = true);

    try {
      // 1. Obtener los datos crudos
      final requests = await GraphicsFunctions.fetchMetricsData(projectId: _selectedProjectId!);

      // 2. Calcular las métricas usando la clase dedicada
      final metrics = ProjectMetricsCalculator.calculate(requests);

      if (mounted) {
        setState(() {
          // 3. Actualizar el estado de la UI con los datos procesados
          _statusLabels = metrics.statusData.labels;
          _statusValues = metrics.statusData.values;

          _complianceLabels = metrics.complianceData.labels;
          _complianceValues = metrics.complianceData.values;

          _moduleLabels = metrics.moduleStatusData.labels;
          _moduleFullLabels = metrics.moduleStatusData.fullLabels;
          _moduleTerminadaValues = metrics.moduleStatusData.seriesValues[0];
          _modulePendienteValues = metrics.moduleStatusData.seriesValues[1];
          _moduleEsperaValues = metrics.moduleStatusData.seriesValues[2];

          _modulePercentageValues = metrics.modulePercentageData.values;

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("DEBUG ERROR EN METRICS: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSupportMetrics() async {
    setState(() => _isLoadingSupport = true);
    try {
      List<Map<String, dynamic>> rawRequests = [];

      if (GlobalCache.isDataLoaded) {
        // Extraer desde la caché pre-cargada
        rawRequests = GlobalCache.requests.where((req) {
          bool isActive = req['IsActive'] == true || req['IsActive'] == 'Y';
          if (!isActive) return false;

          int? bpId = req['C_BPartner_ID'] is Map ? req['C_BPartner_ID']['id'] : req['C_BPartner_ID'];

          if (!AccessControl.isAdmin && User.cBPartnerID != null) {
            if (bpId != User.cBPartnerID) return false;
          } else if (AccessControl.isAdmin && _supportSelectedBpId != null) {
            if (bpId != _supportSelectedBpId) return false;
          }
          return true;
        }).toList();
      } else {
        String filter = "IsActive eq true";
        if (!AccessControl.isAdmin && User.cBPartnerID != null) {
          filter += " and C_BPartner_ID eq ${User.cBPartnerID}";
        } else if (AccessControl.isAdmin && _supportSelectedBpId != null) {
          filter += " and C_BPartner_ID eq $_supportSelectedBpId";
        }
        String expand = "R_Status_ID(\$select=Name,IsOpen),Priority(\$select=Name)";
        rawRequests = await fetchRequest(filter: filter, top: 500, expand: expand);
      }

      final Map<String, double> priorityCounts = {};
      final Map<String, double> statusCounts = {};

      for (var req in rawRequests) {
        // Excluir solicitudes vinculadas a proyectos (tareas)
        if (req['Record_UU'] != null && req['Record_UU'].toString().isNotEmpty) continue;

        // Filtro local por Año
        if (_supportSelectedYear != null) {
          String created = req['Created'] ?? '';
          if (created.length >= 4) {
            int? year = int.tryParse(created.substring(0, 4));
            if (year != _supportSelectedYear) continue;
          }
        }

        // Extracción robusta de Estado
        final statusObj = req['R_Status_ID'];
        final statusData = statusObj is Map ? statusObj : null;
        String rawStatusName = req['R_Status_Name'] ?? '';

        if (statusData != null) {
          rawStatusName = statusData['Name'] ?? statusData['identifier'] ?? rawStatusName;
        }

        if (rawStatusName.isEmpty && statusObj is int) {
          // Buscar en caché global si solo llega el ID entero
          rawStatusName = GlobalCache.statuses.keys.firstWhere((k) => GlobalCache.statuses[k] == statusObj, orElse: () => 'Desconocido');
        }

        if (rawStatusName.isEmpty) rawStatusName = 'Desconocido';

        String cleanStatus = rawStatusName.contains('_') ? rawStatusName.split('_').last.trim() : rawStatusName.trim();
        String lowerStatus = rawStatusName.toLowerCase();

        // Excluir "Anuladas" para no ensuciar las métricas de soporte
        if (lowerStatus.contains('anulada')) {
          continue;
        }

        // Prioridad robusta
        String priorityStr = req['Priority'] is Map ? (req['Priority']['identifier'] ?? req['Priority']['Name'] ?? 'Media') : (req['Priority']?.toString() ?? '5');

        String priority = 'Media';
        final pLower = priorityStr.toLowerCase();
        if (pLower.contains('urgente') || priorityStr == '1')
          priority = 'Urgente';
        else if (pLower.contains('alta') || priorityStr == '3')
          priority = 'Alta';
        else if (pLower.contains('media') || priorityStr == '5')
          priority = 'Media';
        else if (pLower.contains('baja') || priorityStr == '7')
          priority = 'Baja';
        else if (pLower.contains('menor') || priorityStr == '9')
          priority = 'Menor';
        else
          priority = priorityStr;

        priorityCounts[priority] = (priorityCounts[priority] ?? 0) + 1;
        statusCounts[cleanStatus] = (statusCounts[cleanStatus] ?? 0) + 1;
      }

      if (mounted) {
        setState(() {
          _supportPriorityLabels = ['Urgente', 'Alta', 'Media', 'Baja', 'Menor'].where((p) => priorityCounts.containsKey(p)).toList();
          _supportPriorityValues = _supportPriorityLabels.map((p) => priorityCounts[p]!).toList();
          _supportStatusLabels = statusCounts.keys.toList();
          _supportStatusValues = statusCounts.values.toList();
          _isLoadingSupport = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSupport = false);
    }
  }

  void _showBPartnerSearchModal() {
    showDialog(
      context: context,
      builder: (context) {
        String searchQuery = "";
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredBps = _supportBPartners.where((bp) {
              final name = (bp['Name'] ?? '').toString().toLowerCase();
              return name.contains(searchQuery.toLowerCase());
            }).toList();

            return CustomModal(
              title: 'Seleccionar Tercero',
              width: 500,
              content: SizedBox(
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar tercero...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) => setModalState(() => searchQuery = val),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredBps.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  title: const Text('Todos los Terceros', style: TextStyle(fontWeight: FontWeight.bold)),
                                  onTap: () {
                                    setState(() => _supportSelectedBpId = null);
                                    _loadSupportMetrics();
                                    Navigator.pop(context);
                                  },
                                ),
                                const Divider(),
                              ],
                            );
                          }
                          final bp = filteredBps[index - 1];
                          return ListTile(
                            title: Text(bp['Name'] ?? 'Sin Nombre'),
                            onTap: () {
                              setState(() => _supportSelectedBpId = bp['id']);
                              _loadSupportMetrics();
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar'))],
            );
          },
        );
      },
    );
  }

  void _showProjectSearchModal() {
    showDialog(
      context: context,
      builder: (context) {
        String searchQuery = "";
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredProjects = _projects.where((p) {
              final name = (p['Name'] ?? '').toString().toLowerCase();
              return name.contains(searchQuery.toLowerCase());
            }).toList();

            return CustomModal(
              title: 'Seleccionar Proyecto',
              width: 500,
              content: SizedBox(
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar proyecto...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) => setModalState(() => searchQuery = val),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredProjects.length,
                        itemBuilder: (context, index) {
                          final p = filteredProjects[index];
                          return ListTile(
                            title: Text(p['Name'] ?? 'Sin Nombre'),
                            onTap: () {
                              setState(() => _selectedProjectId = p['id']);
                              _loadMetrics();
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar'))],
            );
          },
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
            Text(_adminViewModeManager.currentMode == AdminViewMode.support ? 'Modo Soporte' : (_adminViewModeManager.currentMode == AdminViewMode.project ? 'Modo Proyecto' : 'Mixto'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
    );
  }

  Widget _buildProjectFilterPopupMenu() {
    return PopupMenuButton<bool>(
      tooltip: 'Filtrar proyectos',
      onSelected: (bool viewingMine) {
        _selectedProjectId = null;
        _projects = [];
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width >= 1100;
    return Scaffold(
      appBar: AppBar(
        leadingWidth: !AccessControl.isAdmin ? 180 : null,
        leading: !AccessControl.isAdmin
            ? const UserInfoLeading()
            : Builder(
                builder: (ctx) => IconButton(icon: const Icon(Icons.menu_rounded), tooltip: 'Menú Principal', onPressed: () => Scaffold.of(ctx).openDrawer()),
              ),
        title: const Text('Indicadores (BI)'),
        actions: [
          if (AccessControl.isAdmin) ..._buildAdminAppBarActions(context),
          if (GlobalCache.backgroundSyncNotifier.value)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary)),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => GlobalCache.performSmartSync(context, () async {
              if (AccessControl.canViewProjectCharts) await _loadMetrics();
              if (AccessControl.canViewSupportCharts) await _loadSupportMetrics();
            }),
          ),
          if (!AccessControl.isAdmin)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              tooltip: 'Cerrar Sesión',
              onPressed: () => showLogoutConfirmation(context),
            ),
        ],
      ),
      drawer: AccessControl.isAdmin ? const CustomDrawer(currentRoute: '/metrics') : null,
      bottomNavigationBar: !AccessControl.isAdmin ? const ProjectBottomNav(currentRoute: '/metrics') : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (AccessControl.canViewProjectCharts) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Métricas de Proyecto', style: Theme.of(context).textTheme.titleLarge),
                ),
              ),
              _buildProjectFilters(),
              const SizedBox(height: 20),
              _isLoading
                  ? Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: CustomSkeleton(height: 300, borderRadius: 12)),
                            SizedBox(width: 20),
                            Expanded(child: CustomSkeleton(height: 300, borderRadius: 12)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: CustomSkeleton(height: 300, borderRadius: 12)),
                            SizedBox(width: 20),
                            Expanded(child: CustomSkeleton(height: 300, borderRadius: 12)),
                          ],
                        ),
                      ],
                    )
                  : _buildDashboardGrid(isLargeScreen),
            ] else ...[
              const SizedBox.shrink(),
            ],
            if (AccessControl.canViewProjectCharts && AccessControl.canViewSupportCharts) const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(thickness: 1)),
            if (AccessControl.canViewSupportCharts) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Métricas de Soporte', style: Theme.of(context).textTheme.titleLarge),
                ),
              ),
              _buildSupportFilters(),
              const SizedBox(height: 20),
              _isLoadingSupport
                  ? Row(
                      children: [
                        Expanded(child: CustomSkeleton(height: 300, borderRadius: 12)),
                        const SizedBox(width: 20),
                        Expanded(child: CustomSkeleton(height: 300, borderRadius: 12)),
                      ],
                    )
                  : _buildSupportDashboardGrid(isLargeScreen),
            ],
            if (!AccessControl.canViewProjectCharts && !AccessControl.canViewSupportCharts)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(50.0),
                  child: Text("No hay métricas disponibles para la vista actual.", style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardGrid(bool isLargeScreen) {
    final List<Color> pieColors = [const Color(0xFF42A5F5), const Color(0xFF66BB6A), const Color(0xFFFFA726), const Color(0xFFAB47BC), const Color(0xFFEF5350), const Color(0xFF26A69A), const Color(0xFFEC407A), const Color(0xFFFFCA28), const Color(0xFF5C6BC0), const Color(0xFF8D6E63)];

    int? hoveredStackedSeriesIndex;

    final List<Color> mappedComplianceColors = _complianceLabels.map((l) {
      if (l == 'TERMINADA') return ColorTheme.success; // Verde
      if (l == 'PENDIENTE') return ColorTheme.atention; // Naranja
      return Colors.blue; // ESPERA DE CLIENTE (Azul)
    }).toList();

    Widget complianceChart = _buildChartCard(
      'Porcentaje de Cumplimiento',
      300,
      _complianceValues.isEmpty
          ? _buildEmptyView()
          : _buildDonutWithLegend(
              _complianceValues,
              _complianceLabels,
              mappedComplianceColors,
              onSliceTapped: (label) {
                context.push('/metric-requests', extra: {'projectId': _selectedProjectId, 'filterCompliance': label});
              },
            ),
    );

    Widget statusChart = _buildChartCard(
      'Solicitudes por estado',
      300,
      _statusValues.isEmpty
          ? _buildEmptyView()
          : _buildDonutWithLegend(
              _statusValues,
              _statusLabels,
              pieColors,
              onSliceTapped: (label) {
                context.push('/metric-requests', extra: {'projectId': _selectedProjectId, 'filterStatus': label});
              },
            ),
    );

    Widget moduleStackedChart = _buildChartCard(
      'Estado de Solicitudes por Módulo',
      300,
      _modulePercentageValues.isEmpty
          ? _buildEmptyView()
          : StatefulBuilder(
              builder: (context, setStateLegend) {
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildInteractiveLegendDot(context, 'Terminada', ColorTheme.success, hoveredStackedSeriesIndex == 0, hoveredStackedSeriesIndex != null, () => setStateLegend(() => hoveredStackedSeriesIndex = 0), () => setStateLegend(() => hoveredStackedSeriesIndex = null), () => context.push('/metric-requests', extra: {'projectId': _selectedProjectId, 'filterCompliance': 'TERMINADA'})),
                        const SizedBox(width: 8),
                        _buildInteractiveLegendDot(context, 'Pendiente', ColorTheme.atention, hoveredStackedSeriesIndex == 1, hoveredStackedSeriesIndex != null, () => setStateLegend(() => hoveredStackedSeriesIndex = 1), () => setStateLegend(() => hoveredStackedSeriesIndex = null), () => context.push('/metric-requests', extra: {'projectId': _selectedProjectId, 'filterCompliance': 'PENDIENTE'})),
                        const SizedBox(width: 8),
                        _buildInteractiveLegendDot(
                          context,
                          'Espera de Cliente',
                          Colors.blue,
                          hoveredStackedSeriesIndex == 2,
                          hoveredStackedSeriesIndex != null,
                          () => setStateLegend(() => hoveredStackedSeriesIndex = 2),
                          () => setStateLegend(() => hoveredStackedSeriesIndex = null),
                          () => context.push('/metric-requests', extra: {'projectId': _selectedProjectId, 'filterCompliance': 'ESPERA DE CLIENTE'}),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: CustomStackedBarChart(
                        labels: _moduleLabels,
                        fullLabels: _moduleFullLabels,
                        seriesValues: [_moduleTerminadaValues, _modulePendienteValues, _moduleEsperaValues],
                        seriesNames: const ['Terminada', 'Pendiente', 'Espera de Cliente'],
                        colors: const [ColorTheme.success, ColorTheme.atention, Colors.blue],
                        hoveredSeriesIndex: hoveredStackedSeriesIndex,
                        onBarTapped: (category, series) {
                          context.push('/metric-requests', extra: {'projectId': _selectedProjectId, 'filterType': category, 'filterCompliance': series.toUpperCase()});
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );

    Widget modulePctChart = _buildChartCard(
      'Avance del Proyecto por Módulo (%)',
      300,
      _modulePercentageValues.isEmpty
          ? _buildEmptyView()
          : CustomBarChart(
              labels: _moduleLabels,
              fullLabels: _moduleFullLabels,
              values: _modulePercentageValues,
              colors: const [Color(0xFF673AB7)],
              leftAxisSuffix: '%',
              tooltipSuffix: '%',
              onBarTapped: (label) {
                context.push('/metric-requests', extra: {'projectId': _selectedProjectId, 'filterType': label});
              },
            ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isLargeScreen)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: complianceChart),
              const SizedBox(width: 20),
              Expanded(child: statusChart),
            ],
          )
        else ...[
          complianceChart,
          const SizedBox(height: 20),
          statusChart,
        ],
        const SizedBox(height: 20),
        if (isLargeScreen)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: moduleStackedChart),
              const SizedBox(width: 20),
              Expanded(child: modulePctChart),
            ],
          )
        else ...[
          moduleStackedChart,
          const SizedBox(height: 20),
          modulePctChart,
        ],
      ],
    );
  }

  Widget _buildSupportDashboardGrid(bool isLargeScreen) {
    final List<Color> donutColors2 = [const Color(0xFF5C6BC0), const Color(0xFF8D6E63), const Color(0xFFEC407A), const Color(0xFFFFCA28), const Color(0xFF29B6F6), const Color(0xFF9CCC65)];

    Widget statusChart = _buildChartCard('Estado de Solicitudes', 300, _supportStatusValues.isEmpty ? _buildEmptyView() : _buildDonutWithLegend(_supportStatusValues, _supportStatusLabels, donutColors2));

    final List<Color> priorityColors = _supportPriorityLabels.map((p) {
      if (p == 'Urgente') return ColorTheme.error;
      if (p == 'Alta') return Colors.orange;
      if (p == 'Media') return ColorTheme.atention;
      if (p == 'Baja') return Colors.blue;
      return Colors.grey;
    }).toList();

    Widget priorityChart = _buildChartCard('Solicitudes por Prioridad', 300, _supportPriorityValues.isEmpty ? _buildEmptyView() : CustomBarChart(labels: _supportPriorityLabels, values: _supportPriorityValues, colors: priorityColors, tooltipSuffix: 'sol.'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isLargeScreen)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: statusChart),
              const SizedBox(width: 20),
              Expanded(child: priorityChart),
            ],
          )
        else ...[
          statusChart,
          const SizedBox(height: 20),
          priorityChart,
        ],
      ],
    );
  }

  Widget _buildDonutWithLegend(List<double> values, List<String> labels, List<Color> colors, {String suffix = 'sol.', Function(String label)? onSliceTapped}) {
    return _DonutWithLegendWidget(values: values, labels: labels, colors: colors, suffix: suffix, onSliceTapped: onSliceTapped);
  }

  Widget _buildChartCard(String title, double height, Widget child) => CustomContainer(
    title: title,
    child: SizedBox(height: height, child: child),
  );

  Widget _buildEmptyView() => const Center(
    child: Text("Sin datos relevantes para este proyecto", style: TextStyle(color: Colors.grey)),
  );

  Widget _buildInteractiveLegendDot(BuildContext context, String text, Color color, bool isHovered, bool isAnyHovered, VoidCallback onEnter, VoidCallback onExit, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onEnter(),
      onExit: (_) => onExit(),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          decoration: BoxDecoration(color: isHovered ? color.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isHovered ? 14 : 10,
                height: isHovered ? 14 : 10,
                decoration: BoxDecoration(color: isAnyHovered && !isHovered ? Colors.grey.withOpacity(0.3) : color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(fontSize: 11, fontWeight: isHovered ? FontWeight.bold : FontWeight.normal, color: isAnyHovered && !isHovered ? Theme.of(context).colorScheme.onSurface.withOpacity(0.4) : Theme.of(context).colorScheme.onSurface),
                child: Text(text),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectFilters() {
    return Row(
      children: [
        const Text("Proyecto:", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 15),
        Expanded(
          child: InkWell(
            onTap: _projects.isEmpty ? null : _showProjectSearchModal,
            child: InputDecorator(
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(_selectedProjectId == null ? 'Seleccione un Proyecto' : (_projects.firstWhere((p) => p['id'] == _selectedProjectId, orElse: () => {'Name': 'Desconocido'})['Name'] ?? 'Sin Nombre'), overflow: TextOverflow.ellipsis),
                  ),
                  const Icon(Icons.search, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSupportFilters() {
    return Row(
      children: [
        Expanded(
          child: CustomDropdown<int?>(
            label: 'Año',
            value: _supportSelectedYear,
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Todos los Años')),
              ...List.generate(5, (index) => DateTime.now().year - index).map((year) => DropdownMenuItem<int?>(value: year, child: Text(year.toString()))),
            ],
            onChanged: (val) {
              setState(() => _supportSelectedYear = val);
              _loadSupportMetrics();
            },
          ),
        ),
        if (AccessControl.isAdmin) ...[
          const SizedBox(width: 16),
          Expanded(
            child: InkWell(
              onTap: _supportBPartners.isEmpty ? null : _showBPartnerSearchModal,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Tercero',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(_supportSelectedBpId == null ? 'Todos los Terceros' : (_supportBPartners.firstWhere((bp) => bp['id'] == _supportSelectedBpId, orElse: () => {'Name': 'Desconocido'})['Name'] ?? 'Sin Nombre'), overflow: TextOverflow.ellipsis),
                    ),
                    const Icon(Icons.search, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DonutWithLegendWidget extends StatefulWidget {
  final List<double> values;
  final List<String> labels;
  final List<Color> colors;
  final String suffix;
  final Function(String label)? onSliceTapped;

  const _DonutWithLegendWidget({required this.values, required this.labels, required this.colors, this.suffix = 'sol.', this.onSliceTapped});

  @override
  State<_DonutWithLegendWidget> createState() => _DonutWithLegendWidgetState();
}

class _DonutWithLegendWidgetState extends State<_DonutWithLegendWidget> {
  int? _hoveredIndex;
  final ScrollController _scrollController = ScrollController();
  bool _showTopArrow = false;
  bool _showBottomArrow = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateArrows);
    // Evaluar las flechas justo después del primer renderizado
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  @override
  void didUpdateWidget(covariant _DonutWithLegendWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateArrows);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateArrows() {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;

    final showTop = position.pixels > 0;
    final showBottom = position.pixels < position.maxScrollExtent;

    if (_showTopArrow != showTop || _showBottomArrow != showBottom) {
      setState(() {
        _showTopArrow = showTop;
        _showBottomArrow = showBottom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: CustomDonutChart(values: widget.values, labels: widget.labels, colors: widget.colors, onSliceTapped: widget.onSliceTapped, hoveredIndex: _hoveredIndex),
        ),
        Expanded(
          flex: 6,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: NotificationListener<ScrollUpdateNotification>(
                  onNotification: (notification) {
                    _updateArrows();
                    return false;
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(widget.labels.length, (i) {
                        final val = widget.values[i];
                        final total = widget.values.reduce((a, b) => a + b);
                        final pct = total > 0 ? (val / total * 100) : 0.0;

                        final isHovered = _hoveredIndex == i;
                        final isAnyHovered = _hoveredIndex != null;
                        final textLabel = '${widget.labels[i]}\n${val.toInt()} ${widget.suffix} (${pct.toStringAsFixed(1)}%)';

                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => setState(() => _hoveredIndex = i),
                          onExit: (_) => setState(() => _hoveredIndex = null),
                          child: GestureDetector(
                            onTap: () {
                              if (widget.onSliceTapped != null) widget.onSliceTapped!(widget.labels[i]);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                              margin: const EdgeInsets.only(bottom: 4.0),
                              decoration: BoxDecoration(color: isHovered ? widget.colors[i % widget.colors.length].withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: isHovered ? 16 : 12,
                                    height: isHovered ? 16 : 12,
                                    decoration: BoxDecoration(color: isAnyHovered && !isHovered ? Colors.grey.withOpacity(0.3) : widget.colors[i % widget.colors.length], shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 200),
                                      style: TextStyle(fontSize: 11, height: 1.2, fontWeight: isHovered ? FontWeight.bold : FontWeight.normal, color: isAnyHovered && !isHovered ? Theme.of(context).colorScheme.onSurface.withOpacity(0.4) : Theme.of(context).colorScheme.onSurface),
                                      child: Text(textLabel),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              if (_showTopArrow) Positioned(top: 0, right: 10, child: _buildScrollArrow(Icons.keyboard_arrow_up_rounded)),
              if (_showBottomArrow) Positioned(bottom: 0, right: 10, child: _buildScrollArrow(Icons.keyboard_arrow_down_rounded)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScrollArrow(IconData icon) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
