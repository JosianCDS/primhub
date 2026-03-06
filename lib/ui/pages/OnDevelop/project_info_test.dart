import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/api/token.dart';
import 'package:primhub/endpoint/endpoint.dart';
import '../../widgets/custom_drawer.dart';

class ProjectInfoTestPage extends StatefulWidget {
  const ProjectInfoTestPage({super.key});

  @override
  State<ProjectInfoTestPage> createState() => _ProjectInfoTestPageState();
}

class _ProjectInfoTestPageState extends State<ProjectInfoTestPage> {
  List<dynamic> _projectList = [];
  List<dynamic> _productChipList = [];
  List<dynamic> _orderList = [];
  List<dynamic> _requestList = [];
  bool _isLoading = false;
  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchProjects(), _fetchProductChip(), _fetchOrders(), _fetchRequests()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchProjects({bool useExpand = true}) async {
    if (User.cBPartnerID == null) {
      setState(() => _debugInfo = 'C_BPartner_ID es null. No se puede consultar.');
      return;
    }

    String baseUrl = '${Endpoint.project}?\$filter=C_BPartner_ID eq ${User.cBPartnerID}';
    String url = baseUrl;

    if (useExpand) {
      url += '&\$expand=C_ProjectPhase(\$expand=C_ProjectTask),C_ProjectTask';
    }

    setState(() => _debugInfo = 'Consultando: $url ...');

    try {
      var response = await http.get(Uri.parse(url), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});

      // Si falla por C_ProjectTask (Error 500 específico), intentamos solo con Fases
      if (response.statusCode == 500 && useExpand && response.body.contains('C_ProjectTask')) {
        setState(() => _debugInfo += '\nFallo expansión C_ProjectTask. Reintentando solo con Fases...');
        url = '$baseUrl&\$expand=C_ProjectPhase(\$expand=C_ProjectTask)';
        response = await http.get(Uri.parse(url), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});
      }

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _projectList = data['records'];
          _debugInfo += '\nÉxito. Registros encontrados: ${_projectList.length}';
        });
      } else {
        setState(() => _debugInfo += '\nError ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching projects: $e');
      setState(() => _debugInfo += '\nExcepción: $e');
    }
  }

  Future<void> _fetchProductChip() async {
    try {
      final response = await http.get(Uri.parse('${Endpoint.productChip}?\$filter=C_BPartner_ID eq ${User.cBPartnerID}'), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) setState(() => _productChipList = data['records']);
      }
    } catch (e) {
      debugPrint('Error fetching product chip: $e');
    }
  }

  Future<void> _fetchOrders() async {
    try {
      final response = await http.get(Uri.parse('${Endpoint.order}?\$filter=AD_User_ID eq ${User.userID}&\$expand=C_OrderLine'), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) setState(() => _orderList = data['records']);
      }
    } catch (e) {
      debugPrint('Error fetching orders: $e');
    }
  }

  Future<void> _fetchRequests() async {
    try {
      final response = await http.get(Uri.parse('${Endpoint.request}?\$filter=C_BPartner_ID eq ${User.cBPartnerID}&\$top=20'), headers: {'Content-Type': 'application/json', 'Authorization': Token.token});
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) setState(() => _requestList = data['records']);
      }
    } catch (e) {
      debugPrint('Error fetching requests: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Prueba Info Proyecto'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refrescar',
              onPressed: _initData,
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Proyectos'),
              Tab(text: 'Fases de Proyecto'),
              Tab(text: 'Product Chip'),
              Tab(text: 'Ordenes'),
              Tab(text: 'Solicitudes'),
            ],
          ),
        ),
        drawer: const CustomDrawer(),
        body: _isLoading ? const Center(child: CircularProgressIndicator()) : TabBarView(children: [_buildProjectList(), _buildProjectPhasesTab(), _buildDebugList(_productChipList), _buildDebugList(_orderList), _buildDebugList(_requestList)]),
      ),
    );
  }

  Widget _buildProjectList() {
    if (_projectList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No se encontraron proyectos.'),
            const SizedBox(height: 8),
            Text('Criterio: C_BPartner_ID = ${User.cBPartnerID}'),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _debugInfo,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => _fetchProjects(useExpand: true), child: const Text('Recargar')),
            const SizedBox(height: 8),
            TextButton(onPressed: () => _fetchProjects(useExpand: false), child: const Text('Intentar sin Expandir (Debug)')),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _projectList.length,
      itemBuilder: (context, index) {
        final project = _projectList[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(project['Name'] ?? 'Sin Nombre', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Tercero: ${project['C_BPartner_ID']?['identifier'] ?? 'N/A'}'),
                const SizedBox(height: 4),
                Text('Descripción: ${project['Description'] ?? 'Sin descripción'}'),
                const SizedBox(height: 8),
                const Divider(),
                const Text('Detalles Financieros y Logísticos:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text('PlannedAmt: ${project['PlannedAmt'] ?? '0'}'),
                Text('PlannedMarginAmt: ${project['PlannedMarginAmt'] ?? '0'}'),
                Text('CommittedAmt: ${project['CommittedAmt'] ?? '0'}'),
                Text('PlannedQty: ${project['PlannedQty'] ?? '0'}'),
                Text('CommittedQty: ${project['CommittedQty'] ?? '0'}'),
                Text('ProjInvoiceRule: ${project['ProjInvoiceRule'] ?? 'N/A'}'),
                Text('ProjectLineLevel: ${project['ProjectLineLevel']?['identifier'] ?? 'N/A'}'),
                const SizedBox(height: 4),
                Text('Moneda: ${project['C_Currency_ID']?['identifier'] ?? 'N/A'}'),
                Text('Dirección: ${project['C_BPartner_Location_ID']?['identifier'] ?? 'N/A'}'),
                Text('Término Pago: ${project['C_PaymentTerm_ID']?['identifier'] ?? 'N/A'}'),
                Text('Usuario: ${project['AD_User_ID']?['identifier'] ?? 'N/A'}'),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildProjectPhasesTab() {
    if (_projectList.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('No se encontraron proyectos.'), const SizedBox(height: 8), Text('Criterio: C_BPartner_ID = ${User.cBPartnerID}')]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _projectList.length,
      itemBuilder: (context, index) {
        final project = _projectList[index];
        final phases = project['C_ProjectPhase'] as List? ?? [];
        final directTasks = project['C_ProjectTask'] as List? ?? [];
        final lineLevel = project['ProjectLineLevel']?['id'] ?? 'N/A';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(project['Name'] ?? 'Sin Nombre', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              'Nivel: $lineLevel | Fases: ${phases.length} | Tareas Directas: ${directTasks.length}',
              style: TextStyle(color: lineLevel == 'P' ? Colors.blue : (lineLevel == 'A' ? Colors.orange : Colors.green), fontWeight: FontWeight.bold),
            ),
            children: [
              if (phases.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Fases del Proyecto:', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ...phases.map((phase) => _buildPhaseItem(phase)),
              ],
              if (directTasks.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Tareas Directas:', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ...directTasks.map((task) => _buildTaskItem(task)),
              ],
              if (phases.isEmpty && directTasks.isEmpty) const Padding(padding: EdgeInsets.all(16.0), child: Text('Este proyecto no tiene fases ni tareas registradas.')),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhaseItem(Map<String, dynamic> phase) {
    final tasks = phase['C_ProjectTask'] as List? ?? [];

    String getValue(dynamic val) {
      if (val == null) return 'N/A';
      if (val is Map) return val['identifier']?.toString() ?? val['id']?.toString() ?? val.toString();
      return val.toString();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16.0, bottom: 8.0, right: 8.0),
      child: Card(
        elevation: 0,
        color: Colors.grey.withOpacity(0.1),
        child: ExpansionTile(
          title: Text(phase['Name'] ?? 'Fase sin nombre', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text('${tasks.length} Tareas'),
          leading: const Icon(Icons.folder_open, color: Colors.orange),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildRow('ID Fase', getValue(phase['C_Phase_ID'] ?? phase['id'])),
                  _buildRow('Descripción', getValue(phase['Description'])),
                  _buildRow('Completo', getValue(phase['IsComplete'])),
                  _buildRow('Activo', getValue(phase['IsActive'])),
                  _buildRow('Fecha Inicio', getValue(phase['StartDate'])),
                  _buildRow('Fecha Fin', getValue(phase['EndDate'])),
                  _buildRow('Regla Fact.', getValue(phase['ProjInvoiceRule'])),
                  _buildRow('Monto Planeado', getValue(phase['PlannedAmt'])),
                  _buildRow('Monto Comprometido', getValue(phase['CommittedAmt'])),
                  _buildRow('Orden', getValue(phase['C_Order_ID'])),
                  _buildRow('Cliente', getValue(phase['AD_Client_ID'])),
                  _buildRow('Organización', getValue(phase['AD_Org_ID'])),
                  _buildRow('Proyecto', getValue(phase['C_Project_ID'])),
                ],
              ),
            ),
            if (tasks.isNotEmpty) const Divider(),
            ...tasks.map((task) => _buildTaskItem(task)),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 32.0, right: 16.0),
      leading: const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
      title: Text(task['Name'] ?? 'Tarea sin nombre', style: const TextStyle(fontSize: 13)),
      subtitle: task['Description'] != null ? Text(task['Description'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)) : null,
      dense: true,
    );
  }

  Widget _buildDebugList(List<dynamic> list) {
    if (list.isEmpty) return const Center(child: Text('No hay datos.'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(padding: const EdgeInsets.all(12.0), child: _buildJsonViewer(item)),
        );
      },
    );
  }

  Widget _buildJsonViewer(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data.entries.map((e) {
        if (e.value is Map) {
          return _buildRow(e.key, e.value.toString());
        } else if (e.value is List) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${e.key}:', style: const TextStyle(fontWeight: FontWeight.bold)),
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: (e.value as List)
                      .map(
                        (i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(i.toString(), style: const TextStyle(fontSize: 10)),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          );
        }
        return _buildRow(e.key, e.value.toString());
      }).toList(),
    );
  }

  Widget _buildRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$key: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
