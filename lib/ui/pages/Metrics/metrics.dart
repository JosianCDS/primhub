import 'package:flutter/material.dart';
import 'package:primhub/ui/pages/Metrics/custom_chart.dart';
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
  List<double> _moduleValues = [];
  List<String> _moduleLabels = [];
  List<String> _moduleFullLabels = [];

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
  void dispose() {
    _adminViewModeManager.removeListener(_onViewModeChanged);
    super.dispose();
  }

  void _onViewModeChanged() {
    setState(() {});
    if (AccessControl.canViewProjectCharts && _projects.isEmpty) {
      _loadProjects();
    }
    if (AccessControl.canViewSupportCharts && _supportStatusLabels.isEmpty) {
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
      // Nota: Asegúrate de que fetchProjectsForDropdown traiga el campo 'Value'
      final projects = await ProjectsLogic().fetchProjectsForDropdown();
      if (mounted) {
        setState(() {
          _projects = projects ?? [];
          if (_projects.isNotEmpty && _selectedProjectId == null) {
            _selectedProjectId = _projects.first['id'];
          }
        });
        _loadMetrics();
      }
    } catch (e) {
      debugPrint("Error cargando proyectos: $e");
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
      final Map<String, double> moduleCounts = {};
      final Map<String, double> moduleTotalCounts = {};
      final Map<String, int> compliancePieData = {'TERMINADA': 0, 'PENDIENTE': 0, 'ESPERA DE CLIENTE': 0};
      final Map<String, String> debugStatusMapping = {};
      int totalForCompliance = 0;
      int ignoredByGroup = 0;

      for (var req in requests) {
        final statusData = req['R_Status_ID'] as Map?;
        final groupData = req['R_Group_ID'] as Map?;
        final typeData = req['R_RequestType_ID'] as Map?;

        // Limpieza de nombres (quitar 10_, 20_, etc)
        String rawStatusName = statusData?['Name'] ?? statusData?['identifier'] ?? 'Sin Estado';
        String statusName = rawStatusName.contains('_') ? rawStatusName.split('_').last.trim() : rawStatusName.trim();

        String groupName = groupData?['Name'] ?? groupData?['identifier'] ?? 'Sin Grupo';
        String typeName = typeData?['Name'] ?? typeData?['identifier'] ?? 'Otros';
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
            moduleTotalCounts[typeName] = (moduleTotalCounts[typeName] ?? 0) + 1;

            // Para el gráfico de barras por módulo, usamos la misma lógica de resolución
            if (!isOpen || statusName.toLowerCase().contains('archivada')) {
              moduleCounts[typeName] = (moduleCounts[typeName] ?? 0) + 1;
            }
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
          _moduleFullLabels = moduleTotalCounts.keys.toList();
          _moduleLabels = _moduleFullLabels.map((l) => l.length > 8 ? '${l.substring(0, 8)}.' : l).toList();
          _moduleValues = _moduleFullLabels.map((k) => (moduleTotalCounts[k]! > 0) ? (moduleCounts[k] ?? 0) / moduleTotalCounts[k]! * 100 : 0.0).toList();
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

    Widget complianceChart = _buildChartCard('Porcentaje de Cumplimiento', 300, _complianceValues.isEmpty ? _buildEmptyView() : _buildDonutWithLegend(_complianceValues, _complianceLabels, mappedComplianceColors));

    Widget statusChart = _buildChartCard('Solicitudes por estado', 300, _statusValues.isEmpty ? _buildEmptyView() : _buildDonutWithLegend(_statusValues, _statusLabels, pieColors));

    Widget moduleChart = _buildChartCard('Cumplimiento por Módulo (%)', 300, _moduleValues.isEmpty ? _buildEmptyView() : CustomBarChart(labels: _moduleLabels, fullLabels: _moduleFullLabels, values: _moduleValues, colors: [const Color(0xFF673AB7)], leftAxisSuffix: '%', tooltipSuffix: '%'));

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
        moduleChart,
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

  Widget _buildDonutWithLegend(List<double> values, List<String> labels, List<Color> colors, {String suffix = 'sol.'}) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: CustomDonutChart(values: values, labels: labels, colors: colors),
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

  Widget _buildProjectFilters() {
    return Row(
      children: [
        const Text("Proyecto:", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 15),
        Expanded(
          child: CustomDropdown<int?>(
            value: _selectedProjectId,
            items: _projects.map((p) => DropdownMenuItem<int>(value: p['id'], child: Text(p['Name'] ?? 'Sin Nombre'))).toList(),
            onChanged: (val) {
              setState(() => _selectedProjectId = val);
              _loadMetrics();
            },
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
