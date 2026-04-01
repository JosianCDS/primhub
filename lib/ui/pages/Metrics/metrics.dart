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

  Future<void> _loadSupportBPartners() async {
    if (AccessControl.isAdmin) {
      final bps = await ContractApi.getBPartnersWithSupportContracts();
      if (mounted) {
        setState(() {
          _supportBPartners = bps;
        });
        try {
          final bps = await ProjectsLogic().fetchBPartners();
          if (mounted) {
            setState(() {
              _supportBPartners = bps.map<Map<String, dynamic>>((e) => {'id': e['id'] ?? e['C_BPartner_ID'], 'Name': e['Name'] ?? 'Sin Nombre'}).toList();
            });
          }
        } catch (_) {}
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
          _projects = projects ?? [];
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
      print("DEBUG: Iniciando carga para Proyecto ID: '$_selectedProjectId'");

      final requests = await GraphicsFunctions.fetchMetricsData(projectId: _selectedProjectId!);

      print("DEBUG: Registros recibidos de API (Processed=false): ${requests.length}");

      final Map<String, int> statusCounts = {};
      final Map<String, int> compliancePieData = {'TERMINADA': 0, 'PENDIENTE': 0, 'ESPERA DE CLIENTE': 0};
      final Map<String, Map<String, int>> moduleStatusCounts = {};
      final Map<String, String> debugStatusMapping = {};
      int totalForCompliance = 0;
      int ignoredByGroup = 0;

      for (var req in requests) {
        final statusData = req['R_Status_ID'] as Map?;
        final groupData = req['R_Group_ID'] as Map?;
        final typeData = req['R_RequestType_ID'] as Map?;
        final categoryData = req['R_Category_ID'] as Map?;

        // Limpieza de nombres (quitar 10_, 20_, etc)
        String rawStatusName = statusData?['Name'] ?? statusData?['identifier'] ?? 'Sin Estado';
        String statusName = rawStatusName.contains('_') ? rawStatusName.split('_').last.trim() : rawStatusName.trim();

        String categoryName = categoryData?['Name'] ?? categoryData?['identifier'] ?? 'Sin Módulo';
        bool isOpen = (statusData?['IsOpen'] == 'Y' || statusData?['IsOpen'] == true);

        // Validación robusta por ID de Grupo (1000006 = Requerimiento de cliente)
        // Evita depender del texto que puede cambiar o no expandirse correctamente
        final dynamic rawGroup = req['R_Group_ID'];
        final String groupId = rawGroup is Map ? rawGroup['id']?.toString() ?? '' : rawGroup?.toString() ?? '';
        final bool isClientReq = groupId == '1000006';

        if (isClientReq) {
          totalForCompliance++;

          // --- LÓGICA DE AGRUPACIÓN PARA EL PIE CHART ---
          String category = 'PENDIENTE';
          String lowerStatus = rawStatusName.toLowerCase();

          // Prioridad 1: Aislamos estrictamente "Espera" para que no sea absorbida por las cerradas
          if (lowerStatus.contains('espera de cliente') || lowerStatus.contains('espera del cliente')) {
            category = 'ESPERA DE CLIENTE';
            // Prioridad 2: Si está cerrada (!isOpen) o tiene un nombre final, es TERMINADA (Aquí caerán las 19 de evaluación)
          } else if (!isOpen || lowerStatus.contains('archivada') || lowerStatus.contains('aprobada') || lowerStatus.contains('implementada') || lowerStatus.contains('entregad')) {
            category = 'TERMINADA';
          }

          compliancePieData[category] = (compliancePieData[category] ?? 0) + 1;

          if (!debugStatusMapping.containsKey(rawStatusName)) {
            debugStatusMapping[rawStatusName] = category;
            print("DEBUG MAPPING: Estado Original: '$rawStatusName' -> Asignado a: $category");
          }

          if (!statusName.toLowerCase().contains('anulada')) {
            statusCounts[statusName] = (statusCounts[statusName] ?? 0) + 1;

            moduleStatusCounts.putIfAbsent(categoryName, () => {'TERMINADA': 0, 'PENDIENTE': 0, 'ESPERA DE CLIENTE': 0});
            moduleStatusCounts[categoryName]![category] = (moduleStatusCounts[categoryName]![category] ?? 0) + 1;
          }
        } else {
          ignoredByGroup++;
        }
      }

      print("--- DEBUG RESULTADOS FINALES ---");
      print("Total calculado (Objetivo ~264): $totalForCompliance");
      print("Detalle de estados: $statusCounts");
      print("--- DEBUG CUMPLIMIENTO (PIE CHART) ---");
      compliancePieData.forEach((key, value) => print(" -$key: $value"));
      print("--------------------------------");

      if (mounted) {
        setState(() {
          _statusLabels = statusCounts.keys.toList();
          _statusValues = statusCounts.values.map((v) => v.toDouble()).toList();
          _complianceLabels = compliancePieData.keys.where((k) => compliancePieData[k]! > 0).toList();
          _complianceValues = _complianceLabels.map((k) => compliancePieData[k]!.toDouble()).toList();

          _moduleFullLabels = moduleStatusCounts.keys.toList();
          _moduleLabels = _moduleFullLabels.map((l) => l.length > 8 ? '${l.substring(0, 8)}.' : l).toList();

          _moduleTerminadaValues = [];
          _modulePendienteValues = [];
          _moduleEsperaValues = [];
          _modulePercentageValues = [];

          for (String mod in _moduleFullLabels) {
            int term = moduleStatusCounts[mod]!['TERMINADA'] ?? 0;
            int pend = moduleStatusCounts[mod]!['PENDIENTE'] ?? 0;
            int esp = moduleStatusCounts[mod]!['ESPERA DE CLIENTE'] ?? 0;
            int total = term + pend + esp;

            _moduleTerminadaValues.add(term.toDouble());
            _modulePendienteValues.add(pend.toDouble());
            _moduleEsperaValues.add(esp.toDouble());

            double pct = total > 0 ? (term / total) * 100 : 0.0;
            _modulePercentageValues.add(pct);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print("DEBUG ERROR EN METRICS: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSupportMetrics() async {
    setState(() => _isLoadingSupport = true);
    try {
      String filter = "IsActive eq true";
      if (!AccessControl.isAdmin && User.cBPartnerID != null) {
        filter += " and C_BPartner_ID eq ${User.cBPartnerID}";
      } else if (AccessControl.isAdmin && _supportSelectedBpId != null) {
        filter += " and C_BPartner_ID eq $_supportSelectedBpId";
      }

      final rawRequests = await fetchRequest(filter: filter, top: 500);

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

        String priorityStr = req['Priority'] is Map ? (req['Priority']['identifier'] ?? 'Media') : (req['Priority']?.toString() ?? '5');
        String status = req['R_Status_Name'] ?? (req['R_Status_ID'] is Map ? req['R_Status_ID']['identifier'] : 'Desconocido') ?? 'Desconocido';

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

        String cleanStatus = status.contains('_') ? status.split('_').last.trim() : status.trim();

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

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width >= 1100;
    return Scaffold(
      appBar: AppBar(
        title: const Text('BI - Gestión iDempiere'),
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
                _selectedProjectId = null; // Fuerza a la UI a reiniciar la selección visualmente
                _projects = []; // Evita retener proyectos de la vista anterior
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMetrics),
        ],
      ),
      drawer: const CustomDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (AccessControl.canViewProjectCharts) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Métricas de Proyecto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
              _buildProjectFilters(),
              const SizedBox(height: 20),
              _isLoading
                  ? const Center(
                      child: Padding(padding: EdgeInsets.all(50.0), child: CircularProgressIndicator()),
                    )
                  : _buildDashboardGrid(isLargeScreen),
            ] else ...[
              const SizedBox.shrink(),
            ],
            if (AccessControl.canViewProjectCharts && AccessControl.canViewSupportCharts) const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(thickness: 1)),
            if (AccessControl.canViewSupportCharts) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Métricas de Soporte', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
              _buildSupportFilters(),
              const SizedBox(height: 20),
              _isLoadingSupport
                  ? const Center(
                      child: Padding(padding: EdgeInsets.all(50.0), child: CircularProgressIndicator()),
                    )
                  : _buildSupportDashboardGrid(isLargeScreen),
            ],
            if (!AccessControl.canViewProjectCharts && !AccessControl.canViewSupportCharts)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(50.0),
                  child: Text("No hay métricas disponibles para la vista actual.", style: TextStyle(color: Colors.grey)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardGrid(bool isLargeScreen) {
    final List<Color> pieColors = [const Color(0xFF42A5F5), const Color(0xFF66BB6A), const Color(0xFFFFA726), const Color(0xFFAB47BC), const Color(0xFFEF5350), const Color(0xFF26A69A), const Color(0xFFEC407A), const Color(0xFFFFCA28), const Color(0xFF5C6BC0), const Color(0xFF8D6E63)];

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
                // NOTA: Este gráfico agrupa estados. Navegar por 'TERMINADA' es complejo
                // ya que implicaría filtrar por múltiples estados ('Archivada', 'Aprobada', etc.)
                // lo cual la página de destino no soporta actualmente.
                // Por ahora, solo el gráfico de 'Solicitudes por estado' será interactivo.
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
                context.push('/project-requests', extra: {'projectId': _selectedProjectId, 'filterStatus': label});
              },
            ),
    );

    Widget moduleStackedChart = _buildChartCard(
      'Estado de Solicitudes por Módulo',
      300,
      _modulePercentageValues.isEmpty
          ? _buildEmptyView()
          : Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [_buildLegendDot('Terminada', ColorTheme.success), const SizedBox(width: 8), _buildLegendDot('Pendiente', ColorTheme.atention), const SizedBox(width: 8), _buildLegendDot('Espera de Cliente', Colors.blue)]),
                const SizedBox(height: 10),
                Expanded(
                  child: CustomStackedBarChart(labels: _moduleLabels, fullLabels: _moduleFullLabels, seriesValues: [_moduleTerminadaValues, _modulePendienteValues, _moduleEsperaValues], seriesNames: const ['Terminada', 'Pendiente', 'Espera de Cliente'], colors: const [ColorTheme.success, ColorTheme.atention, Colors.blue]),
                ),
              ],
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
                context.push('/project-requests', extra: {'projectId': _selectedProjectId, 'filterType': label});
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
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: CustomDonutChart(values: values, labels: labels, colors: colors, onSliceTapped: onSliceTapped),
        ),
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(labels.length, (i) {
                final val = values[i];
                final total = values.reduce((a, b) => a + b);
                final pct = total > 0 ? (val / total * 100) : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${labels[i]}\n${val.toInt()} $suffix (${pct.toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 11, height: 1.2))),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChartCard(String title, double height, Widget child) => CustomContainer(
    title: title,
    child: SizedBox(height: height, child: child),
  );

  Widget _buildEmptyView() => const Center(
    child: Text("Sin datos relevantes para este proyecto", style: TextStyle(color: Colors.grey)),
  );

  Widget _buildLegendDot(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 10)),
      ],
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
