import 'package:flutter/material.dart';
import 'package:primhub/ui/Shared_Custom/custom_chart.dart';
import 'package:primhub/ui/Shared_Custom/custom_container.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/api/admin_view_mode.dart';
import '../../../theme/colors.dart';
import '../../../api/access_control.dart';
import '../../widgets/custom_drawer.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'dart:math';

// 1. Modelo de Datos para representar los Estados del Proyecto
class ProjectStatusCount {
  final String statusName;
  final int count;

  ProjectStatusCount({required this.statusName, required this.count});
}

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
  double _projectCompliance = 0.0;
  List<double> _statusValues = [];
  List<String> _statusLabels = [];
  List<double> _moduleValues = [];
  List<String> _moduleLabels = [];
  List<String> _moduleFullLabels = [];

  // Diccionarios de iDempiere
  Map<int, String> _statusIdToName = {};
  Map<int, bool> _statusIdToIsOpen = {};
  Map<int, String> _groupIdToName = {};
  Map<int, String> _typeIdToName = {};

  int? _selectedProjectId;
  List<dynamic> _projects = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadLookups();
    await _loadProjects();
  }

  Future<void> _loadLookups() async {
    try {
      // Removemos el parametro 'select' para evitar que iDempiere omita las llaves primarias
      final results = await Future.wait([fetchRequest(model: 'R_Status'), fetchRequest(model: 'R_Group'), fetchRequest(model: 'R_RequestType')]);

      if (mounted) {
        setState(() {
          _statusIdToName = {};
          _statusIdToIsOpen = {};
          for (var s in results[0]) {
            int? id = _parseId(s['id']) ?? _parseId(s['R_Status_ID']);
            if (id != null) {
              _statusIdToName[id] = s['Name'] ?? '';
              _statusIdToIsOpen[id] = (s['IsOpen'] == true || s['IsOpen'] == 'Y');
            }
          }
          _groupIdToName = {};
          for (var g in results[1]) {
            int? id = _parseId(g['id']) ?? _parseId(g['R_Group_ID']);
            if (id != null) _groupIdToName[id] = g['Name'] ?? '';
          }
          _typeIdToName = {};
          for (var t in results[2]) {
            int? id = _parseId(t['id']) ?? _parseId(t['R_RequestType_ID']);
            if (id != null) _typeIdToName[id] = t['Name'] ?? '';
          }
        });
      }
    } catch (e) {}
  }

  int? _parseId(dynamic val) {
    if (val == null) return null;
    if (val is Map) return val['id'];
    if (val is int) return val;
    return int.tryParse(val.toString());
  }

  Future<void> _loadProjects() async {
    try {
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
    } catch (e) {}
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoading = true);
    try {
      String filter = "IsActive eq true";
      if (_selectedProjectId != null) {
        filter += " and C_Project_ID eq $_selectedProjectId";
      }

      final requests = await fetchRequest(filter: filter);

      final Map<String, double> priorityTotals = {'Urgente': 0, 'Alta': 0, 'Media': 0, 'Baja': 0, 'Menor': 0};
      final Map<String, double> typeCounts = {};
      final Map<String, int> statusCounts = {}; // Agrupación y Valores (count)
      final Map<String, double> moduleCounts = {};
      final Map<String, double> moduleTotalCounts = {};

      int totalForCompliance = 0;
      int resolvedForCompliance = 0;

      for (var req in requests) {
        int? sId = _parseId(req['R_Status_ID']);
        int? gId = _parseId(req['R_Group_ID']);
        int? tId = _parseId(req['R_RequestType_ID']);

        // Extracción robusta con fallback al 'identifier' de iDempiere si el diccionario falla
        String statusName = _statusIdToName[sId] ?? '';
        if (statusName.isEmpty && req['R_Status_ID'] is Map) statusName = req['R_Status_ID']['identifier'] ?? 'Sin Estado';
        if (statusName.isEmpty) statusName = 'Sin Estado';

        String groupName = _groupIdToName[gId] ?? '';
        if (groupName.isEmpty && req['R_Group_ID'] is Map) groupName = req['R_Group_ID']['identifier'] ?? '';

        String typeName = _typeIdToName[tId] ?? '';
        if (typeName.isEmpty && req['R_RequestType_ID'] is Map) typeName = req['R_RequestType_ID']['identifier'] ?? 'Otros';
        if (typeName.isEmpty) typeName = 'Otros';

        bool isOpen = _statusIdToIsOpen[sId] ?? true;

        // Prioridad
        String pStr = req['Priority']?.toString() ?? '5';
        String priority = pStr == '1'
            ? 'Urgente'
            : pStr == '3'
            ? 'Alta'
            : pStr == '5'
            ? 'Media'
            : pStr == '7'
            ? 'Baja'
            : 'Menor';

        // --- Lógica de iDempiere ---
        // Normalizamos strings para evitar desajustes por espacios o mayúsculas (case-insensitive)
        final String normalizedGroup = groupName.trim().toLowerCase();
        final String normalizedStatus = statusName.trim().toLowerCase();

        final bool isClientRequirement = normalizedGroup == 'requerimiento de cliente';

        // 1. KPI de Cumplimiento General (basado en SQL 2)
        if (isClientRequirement) {
          totalForCompliance++;
          if (!isOpen) {
            resolvedForCompliance++;
          }
        }

        // 2. Gráficos de Módulos y Estados (basado en SQL 3)
        // Excluye "Anulada" analizando la versión normalizada
        if (isClientRequirement && normalizedStatus != 'anulada') {
          // Almacenamos el statusName original para mantener la capitalización correcta en la vista
          statusCounts[statusName] = (statusCounts[statusName] ?? 0) + 1;
          moduleTotalCounts[typeName] = (moduleTotalCounts[typeName] ?? 0) + 1;
          if (!isOpen) {
            moduleCounts[typeName] = (moduleCounts[typeName] ?? 0) + 1;
          }
        }

        // --- Otros Gráficos ---
        typeCounts[typeName] = (typeCounts[typeName] ?? 0) + 1;
        priorityTotals[priority] = (priorityTotals[priority] ?? 0) + ((req['QtyPlan'] as num?)?.toDouble() ?? 0.0);
      }

      if (mounted) {
        setState(() {
          _consumedByPriority = priorityTotals.values.toList();
          _typeLabels = typeCounts.keys.toList();
          _typeValues = typeCounts.values.toList();
          _typeColors = List.generate(_typeLabels.length, (i) => Colors.primaries[i % Colors.primaries.length]);

          // Implementación del Modelo de Datos para "Solicitudes de proyecto por estado"
          final projectStatusData = statusCounts.entries.map((e) => ProjectStatusCount(statusName: e.key, count: e.value)).toList();

          _statusLabels = projectStatusData.map((e) => e.statusName).toList();
          _statusValues = projectStatusData.map((e) => e.count.toDouble()).toList();
          _moduleFullLabels = moduleTotalCounts.keys.toList();
          _moduleLabels = _moduleFullLabels.map((l) => l.length > 5 ? '${l.substring(0, 5)}.' : l).toList();
          _moduleValues = _moduleFullLabels.map((k) => (moduleTotalCounts[k]! > 0) ? (moduleCounts[k] ?? 0) / moduleTotalCounts[k]! * 100 : 0.0).toList();
          _projectCompliance = totalForCompliance > 0 ? (resolvedForCompliance / totalForCompliance) * 100 : 0.0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width >= 1100;
    return Scaffold(
      appBar: AppBar(
        title: const Text('BI - Gestión iDempiere'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMetrics)],
      ),
      drawer: const CustomDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilters(context),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(
                    child: Padding(padding: EdgeInsets.all(50.0), child: CircularProgressIndicator()),
                  )
                : _buildDashboardGrid(context, isLargeScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardGrid(BuildContext context, bool isLargeScreen) {
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        _buildSummaryCard(),
        _buildChartCard('Estados (Requerimientos)', 250, _statusValues.isEmpty ? _buildEmptyView() : CustomDonutChart(values: _statusValues, labels: _statusLabels, colors: [ColorTheme.success, ColorTheme.atention, ColorTheme.error, Colors.blueGrey])),
        _buildChartCard('Cumplimiento por Módulo (%)', 300, _moduleValues.isEmpty ? _buildEmptyView() : CustomBarChart(labels: _moduleLabels, fullLabels: _moduleFullLabels, values: _moduleValues, colors: [const Color(0xFF673AB7)])),
        _buildChartCard('Horas por Prioridad', 300, CustomBarChart(labels: const ['Urgente', 'Alta', 'Media', 'Baja', 'Menor'], values: _consumedByPriority, colors: [ColorTheme.error, ColorTheme.atention, Colors.orange, ColorTheme.success, Colors.grey])),
      ].map((c) => FractionallySizedBox(widthFactor: isLargeScreen ? 0.48 : 1.0, child: c)).toList(),
    );
  }

  Widget _buildSummaryCard() => CustomContainer(
    title: '% Cumplimiento General',
    child: Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: CircularProgressIndicator(value: _projectCompliance / 100, strokeWidth: 10, color: _projectCompliance > 80 ? ColorTheme.success : ColorTheme.atention, backgroundColor: Colors.grey[200]),
          ),
          Text("${_projectCompliance.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );

  Widget _buildChartCard(String title, double height, Widget child) => CustomContainer(
    title: title,
    child: SizedBox(height: height, child: child),
  );
  Widget _buildEmptyView() => const Center(
    child: Text("Sin datos para este proyecto/año", style: TextStyle(color: Colors.grey)),
  );

  Widget _buildFilters(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text("Filtros:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(
          width: 300,
          child: CustomDropdown<int?>(
            label: 'Proyecto',
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
}
