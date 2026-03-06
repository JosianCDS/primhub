import 'package:flutter/material.dart';
import 'package:primhub/ui/Shared_Custom/custom_chart.dart';
import 'package:primhub/ui/Shared_Custom/custom_container.dart';
import 'package:primhub/api/token.dart';
import '../../../theme/colors.dart';
import '../../../api/access_control.dart';
import '../../widgets/custom_drawer.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/ui/pages/Metrics/project_requests_page.dart';

class MetricsPage extends StatefulWidget {
  const MetricsPage({super.key});

  @override
  State<MetricsPage> createState() => _MetricsPageState();
}

class _MetricsPageState extends State<MetricsPage> {
  bool _isLoading = true;

  // --- Datos Gráficos ---
  List<double> _consumedByPriority = [0, 0, 0, 0, 0];
  List<double> _typeValues = [];
  List<String> _typeLabels = [];
  List<Color> _typeColors = [];
  List<String> _lineLabels = [];
  List<List<double>> _lineData = [[], []];

  double _projectCompliance = 0.0;
  List<double> _statusValues = [];
  List<String> _statusLabels = [];
  List<double> _moduleValues = [];
  List<String> _moduleLabels = [];
  List<String> _moduleFullLabels = [];

  // Filtros
  int _selectedYear = DateTime.now().year;
  String? _selectedPriority;
  int? _selectedProjectId;
  bool _showResolved = true;
  bool _showUnresolved = true;

  List<dynamic> _projects = [];
  List<String> _currentProjectTaskUUIDs = []; // Almacenar UUIDs actuales

  Map<int, String> _statusNameMap = {};

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _fetchStatusesMap();
  }

  Future<void> _loadProjects() async {
    try {
      int? bpId = AccessControl.isProject ? User.cBPartnerID : null;

      final projects = await ProjectsLogic().fetchProjectsForDropdown(bPartnerId: bpId); // Ya filtra por IsActive eq true en la lógica

      if (mounted) {
        setState(() {
          // Limpiamos y asignamos la nueva lista
          _projects = projects ?? [];

          // Seleccionar el primer proyecto por defecto si hay proyectos disponibles
          if (_projects.isNotEmpty) {
            _selectedProjectId = _projects.first['id'];
          }
        });

        _loadMetrics();
      }
    } catch (e) {
      debugPrint('Error loading projects for metrics: $e');
    }
  }

  Future<void> _fetchStatusesMap() async {
    final statuses = await fetchStatuses(); // Returns Map<String, int> (Name -> ID)
    if (mounted) {
      setState(() {
        // Invert map to ID -> Name
        _statusNameMap = statuses.map((key, value) => MapEntry(value, key));
      });
    }
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoading = true);

    try {
      // OPTIMIZACIÓN: Cargar solo las solicitudes del año seleccionado
      String filter = "Created ge '${_selectedYear}-01-01T00:00:00Z' and Created le '${_selectedYear}-12-31T23:59:59Z'";

      // --- INICIO LÓGICA DE FILTRADO DE PROYECTO ---
      if (_selectedProjectId != null) {
        // 1. Obtener la estructura completa del proyecto seleccionado para encontrar los UUIDs de las tareas.
        final projectList = await ProjectsLogic().fetchProjects(context, projectId: _selectedProjectId);
        _currentProjectTaskUUIDs.clear(); // Limpiar lista anterior

        if (projectList.isNotEmpty) {
          final project = projectList.first;
          final List<String> taskUUIDs = [];

          // Recolectar UUIDs de tareas en fases
          final phases = project['C_ProjectPhase'] as List? ?? [];
          for (var phase in phases) {
            final tasks = phase['C_ProjectTask'] as List? ?? [];
            for (var task in tasks) {
              if (task['UUID'] != null && task['UUID'].toString().isNotEmpty) {
                taskUUIDs.add("'${task['UUID']}'");
              }
            }
          }

          // Recolectar UUIDs de tareas directas del proyecto
          final directTasks = project['C_ProjectTask'] as List? ?? [];
          for (var task in directTasks) {
            if (task['UUID'] != null && task['UUID'].toString().isNotEmpty) {
              taskUUIDs.add("'${task['UUID']}'");
            }
          }

          _currentProjectTaskUUIDs = List.from(taskUUIDs); // Guardar para navegación

          // 2. Construir el filtro para la API
          List<String> projectFilters = [];
          // Incluir solicitudes directamente ligadas al proyecto
          projectFilters.add("C_Project_ID eq $_selectedProjectId");

          // Incluir solicitudes ligadas a las tareas del proyecto via Record_UU
          if (taskUUIDs.isNotEmpty) {
            projectFilters.add(taskUUIDs.map((uuid) => "Record_UU eq $uuid").join(' or '));
          }

          filter += " and (${projectFilters.join(' or ')})";
        }
      } else if (AccessControl.isProject && User.cBPartnerID != null) {
        filter += " and C_BPartner_ID eq ${User.cBPartnerID}";
      }

      final requests = await fetchRequest(filter: filter);

      final Map<String, double> priorityTotals = {'Urgente': 0.0, 'Alta': 0.0, 'Media': 0.0, 'Baja': 0.0, 'Menor': 0.0};
      final Map<String, double> typeCounts = {};
      final Map<String, double> statusCounts = {};
      final Map<String, double> moduleCounts = {};
      final Map<String, double> moduleTotalCounts = {};

      int totalForCompliance = 0;
      int resolvedForCompliance = 0;

      for (var req in requests) {
        final priority = req['Priority_Name'] ?? 'Media';
        if (_selectedPriority != null && priority != _selectedPriority) continue;

        // Sincronización: Asegurar que coincida con iDempiere (ID 103 o nombre exacto)
        int? sId = req['R_Status_ID'] is Map ? req['R_Status_ID']['id'] : (req['R_Status_ID'] is int ? req['R_Status_ID'] : null);
        final isResolvedGeneral = req['R_Status_Name'] == '9_Final Close' || sId == 103 || req['R_Status_Name'] == 'Final Close';
        if (isResolvedGeneral && !_showResolved) continue;
        if (!isResolvedGeneral && !_showUnresolved) continue;

        // --- Procesamiento de datos para gráficas ---
        final qty = (req['QtyPlan'] as num?)?.toDouble() ?? 0.0;
        if (priorityTotals.containsKey(priority)) {
          priorityTotals[priority] = priorityTotals[priority]! + qty;
        }

        String typeName = req['R_RequestType_Name'] ?? '';
        if (typeName.isEmpty) {
          final typeObj = req['R_RequestType_ID'];
          if (typeObj is Map) typeName = typeObj['identifier'] ?? typeObj['name'] ?? '';
        }
        if (typeName.isEmpty) typeName = 'Otros';

        typeCounts[typeName] = (typeCounts[typeName] ?? 0) + 1;

        // Filtrar solo solicitudes relacionadas a proyectos (con Record_UU) para este gráfico
        if (req['Record_UU'] != null && req['Record_UU'].toString().isNotEmpty) {
          String statusName = req['R_Status_Name'] ?? '';
          if (statusName.isEmpty) {
            final statusObj = req['R_Status_ID'];
            if (statusObj is Map) {
              statusName = statusObj['identifier'] ?? statusObj['name'] ?? '';
            } else if (statusObj is int) {
              // Try to resolve from map
              statusName = _statusNameMap[statusObj] ?? 'Estado $statusObj';
            }
          }
          if (statusName.isEmpty) statusName = 'Sin Estado';
          statusCounts[statusName] = (statusCounts[statusName] ?? 0) + 1;
        }

        totalForCompliance++;
        // Cumplimiento General: Solo R_Status_ID = 1000018 cuenta como cumplido para este KPI específico
        // Asumiendo que R_Status_ID puede venir como int o map
        int? statusId = req['R_Status_ID'] is Map ? req['R_Status_ID']['id'] : (req['R_Status_ID'] is int ? req['R_Status_ID'] : null);
        if (statusId == 1000018) {
          resolvedForCompliance++;
        }

        // Cumplimiento por Módulo (Porcentaje)
        moduleTotalCounts[typeName] = (moduleTotalCounts[typeName] ?? 0) + 1;
        if (statusId == 1000018) {
          moduleCounts[typeName] = (moduleCounts[typeName] ?? 0) + 1;
        }
      }

      // Lógica de Tendencia Mensual
      final List<DateTime> months = List.generate(12, (i) => DateTime(_selectedYear, i + 1, 1));
      final Map<String, int> receivedCounts = {};
      final Map<String, int> resolvedCounts = {};

      for (var d in months) {
        String key = "${d.year}-${d.month.toString().padLeft(2, '0')}";
        receivedCounts[key] = 0;
        resolvedCounts[key] = 0;
      }

      for (var req in requests) {
        if (req['Created'] != null) {
          final c = DateTime.parse(req['Created']);
          String key = "${c.year}-${c.month.toString().padLeft(2, '0')}";
          if (receivedCounts.containsKey(key)) receivedCounts[key] = receivedCounts[key]! + 1;
        }
        if (req['R_Status_Name'] == '9_Final Close' || req['R_Status_ID'] == 103 || req['R_Status_Name'] == 'Final Close') {
          if (req['CloseDate'] != null) {
            final cl = DateTime.parse(req['CloseDate']);
            String key = "${cl.year}-${cl.month.toString().padLeft(2, '0')}";
            if (resolvedCounts.containsKey(key)) resolvedCounts[key] = resolvedCounts[key]! + 1;
          }
        }
      }

      if (mounted) {
        setState(() {
          _consumedByPriority = priorityTotals.values.toList();
          _typeLabels = typeCounts.keys.toList();
          _typeValues = typeCounts.values.toList();
          _typeColors = List.generate(_typeLabels.length, (i) => Colors.primaries[i % Colors.primaries.length]);

          _lineLabels = months.map((d) => _getMonthNameShort(d.month)).toList();
          _lineData = [months.map((d) => (receivedCounts["${d.year}-${d.month.toString().padLeft(2, '0')}"] ?? 0).toDouble()).toList(), months.map((d) => (resolvedCounts["${d.year}-${d.month.toString().padLeft(2, '0')}"] ?? 0).toDouble()).toList()];

          _projectCompliance = totalForCompliance > 0 ? (resolvedForCompliance / totalForCompliance) * 100 : 0.0;
          _statusLabels = statusCounts.keys.toList();
          _statusValues = statusCounts.values.toList();

          // Calcular porcentaje por módulo
          _moduleLabels = moduleCounts.keys.toList().map((l) => l.length > 3 ? '${l.substring(0, 3)}.' : l).toList();
          _moduleFullLabels = moduleCounts.keys.toList();
          _moduleValues = moduleCounts.keys.map((key) {
            double total = moduleTotalCounts[key] ?? 1;
            double resolved = moduleCounts[key] ?? 0;
            return total > 0 ? (resolved / total) * 100 : 0.0;
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLargeScreen = MediaQuery.of(context).size.width >= 1100;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Indicadores de Negocio (BI)'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadMetrics();
            },
          ),
        ],
      ),
      drawer: const CustomDrawer(),
      body: SafeArea(
        child: Row(
          children: [
            if (isLargeScreen && AccessControl.canFilterMetrics)
              Container(
                width: 300,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  border: Border(right: BorderSide(color: theme.dividerColor)),
                ),
                child: _buildFilters(context),
              ),
            Expanded(
              child: Column(
                children: [
                  if (!isLargeScreen && AccessControl.canFilterMetrics)
                    ExpansionTile(
                      title: const Text("Filtros de búsqueda", style: TextStyle(fontWeight: FontWeight.bold)),
                      children: [_buildFilters(context)],
                    ),
                  Expanded(
                    child: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(padding: const EdgeInsets.all(20.0), child: _buildDashboardGrid(context, isLargeScreen)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardGrid(BuildContext context, bool isLargeScreen) {
    final complianceChart = CustomContainer(
      title: '% Cumplimiento General',
      child: SizedBox(
        height: 220,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: CircularProgressIndicator(value: _projectCompliance / 100, strokeWidth: 12, backgroundColor: Colors.grey.withOpacity(0.1), color: _projectCompliance > 80 ? ColorTheme.success : ColorTheme.atention),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("${_projectCompliance.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const Text("Finalizado", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    final double totalStatusRequests = _statusValues.fold(0, (sum, item) => sum + item);

    final statusChart = _buildChartCard(
      'Solicitudes por Estado',
      220,
      _statusValues.isEmpty ? _buildEmptyView() : CustomDonutChart(values: _statusValues, labels: _statusLabels, colors: [ColorTheme.info, ColorTheme.atention, ColorTheme.error, Colors.blueGrey]),
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Text(
              'Total: ${totalStatusRequests.toInt()}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
    final moduleChart = _buildChartCard('% Cumplimiento por Módulo', 220, _moduleValues.isEmpty ? _buildEmptyView() : CustomBarChart(labels: _moduleLabels, fullLabels: _moduleFullLabels, values: _moduleValues, colors: [const Color(0xFF673AB7)]));
    final barChart = _buildChartCard('Horas por Prioridad', 250, _consumedByPriority.every((e) => e == 0) ? _buildEmptyView() : CustomBarChart(labels: const ['Urgente', 'Alta', 'Media', 'Baja', 'Menor'], values: _consumedByPriority, colors: [ColorTheme.error, ColorTheme.atention, const Color(0xFFFDD835), ColorTheme.success, Colors.grey]));
    final donutChart = _buildChartCard(
      'Volumen por Categoría',
      250,
      _typeValues.isEmpty
          ? _buildEmptyView()
          : Row(
              children: [
                Expanded(
                  flex: 3,
                  child: CustomDonutChart(values: _typeValues, colors: _typeColors),
                ),
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(child: Column(children: List.generate(_typeLabels.length, (i) => _buildLegendItem(_typeColors[i], '${_typeLabels[i]} (${_typeValues[i].toInt()})')))),
                ),
              ],
            ),
    );
    final lineChart = _buildChartCard(
      'Tendencia Mensual',
      300,
      Column(
        children: [
          Expanded(
            child: CustomLineChart(labels: _lineLabels, data: _lineData, colors: const [Color(0xFF4F47E5), Color(0xFF10B981)]),
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [_buildSimpleLegend(const Color(0xFF4F47E5), 'Recibidos'), const SizedBox(width: 20), _buildSimpleLegend(const Color(0xFF10B981), 'Resueltos')]),
        ],
      ),
    );

    List<Widget> visibleCharts = [];
    if (AccessControl.canViewProjectCharts && !AccessControl.isSupport) visibleCharts.addAll([complianceChart, statusChart, moduleChart]);
    if (AccessControl.canViewSupportCharts) visibleCharts.addAll([barChart, donutChart, lineChart]);

    if (!isLargeScreen)
      return Column(
        children: visibleCharts.map((w) => Padding(padding: const EdgeInsets.only(bottom: 16), child: w)).toList(),
      );

    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: visibleCharts.map((chart) {
        if (chart == lineChart || chart == moduleChart) return SizedBox(width: double.infinity, child: chart);
        return FractionallySizedBox(widthFactor: chart == barChart || chart == donutChart ? 0.48 : 0.48, child: chart);
      }).toList(),
    );
  }

  Widget _buildChartCard(String title, double height, Widget child, {Widget? action}) => CustomContainer(
    title: title,
    action: action,
    child: SizedBox(height: height, child: child),
  );

  Widget _buildEmptyView() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.insert_chart_outlined, size: 40, color: Colors.grey.withOpacity(0.5)),
        const SizedBox(height: 8),
        const Text("Sin datos disponibles", style: TextStyle(color: Colors.grey, fontSize: 13)),
      ],
    ),
  );

  Widget _buildFilters(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text("Filtros del Dashboard", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Divider(height: 30),
        const Text("Año de consulta", style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        CustomDropdown<int>(
          value: _selectedYear,
          items: List.generate(5, (i) => DropdownMenuItem(value: DateTime.now().year - i, child: Text((DateTime.now().year - i).toString()))),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedYear = val);
              _loadMetrics();
            }
          },
        ),
        const SizedBox(height: 20),
        const Text("Proyecto", style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        CustomDropdown<int?>(
          value: _selectedProjectId,
          items: [..._projects.map((p) => DropdownMenuItem<int>(value: p['id'], child: Text(p['Name'] ?? 'Sin Nombre')))],
          onChanged: (val) {
            setState(() => _selectedProjectId = val);
            _loadMetrics();
          },
        ),
        const SizedBox(height: 20),
        const Text("Nivel de Prioridad", style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        CustomDropdown<String?>(
          value: _selectedPriority,
          items: [
            const DropdownMenuItem(value: null, child: Text("Todas")),
            ...['Urgente', 'Alta', 'Media', 'Baja', 'Menor'].map((e) => DropdownMenuItem(value: e, child: Text(e))),
          ],
          onChanged: (val) {
            setState(() => _selectedPriority = val);
            _loadMetrics();
          },
        ),
        const SizedBox(height: 20),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Incluir Resueltos"),
          value: _showResolved,
          onChanged: (val) {
            setState(() => _showResolved = val ?? true);
            _loadMetrics();
          },
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Incluir No Resueltos"),
          value: _showUnresolved,
          onChanged: (val) {
            setState(() => _showUnresolved = val ?? true);
            _loadMetrics();
          },
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );
  Widget _buildSimpleLegend(Color color, String text) => Row(
    children: [
      Container(width: 12, height: 3, color: color),
      const SizedBox(width: 8),
      Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    ],
  );
  String _getMonthNameShort(int month) => ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'][month - 1];
}
