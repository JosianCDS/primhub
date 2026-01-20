import 'package:flutter/material.dart';
import 'package:primhub/ui/pages/request/create_request_dialog.dart';
import 'package:primhub/ui/pages/request/request_functions.dart';
import 'package:primhub/ui/shared/custom_button.dart';
import 'package:primhub/ui/shared/cardcustom.dart';
import 'package:primhub/ui/shared/custom_chart.dart';
import 'package:primhub/ui/shared/custom_container.dart';
import 'package:primhub/ui/shared/custom_inputs.dart';
import 'package:primhub/ui/shared/custom_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_drawer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedChartFilter = 'Todos';
  final Map<String, List<double>> _areaData = {
    'Soporte': [15, 25, 20, 40, 35, 50, 45],
    'Desarrollo': [10, 30, 45, 35, 55, 40, 60],
    'Ventas': [5, 15, 10, 20, 25, 30, 25],
  };
  final List<String> _chartLabels = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];

  List<Map<String, dynamic>> _recentRequests = [];
  bool _isLoading = true;
  int _openRequestsCount = 0;
  int _inProgressRequestsCount = 0;
  bool _isAdmin = true;

  @override
  void initState() {
    super.initState();
    _checkRole();
    _loadRecentRequests();
  }

  Future<void> _checkRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted)
      setState(
        () => _isAdmin = (prefs.getString('user_role') ?? 'ADMIN') == 'ADMIN',
      );
  }

  Future<void> _loadRecentRequests() async {
    final requests = await fetchRequest();

    int open = 0;
    int others = 0;
    for (var req in requests) {
      if (req['R_Status_Name'] == '9_Final Close') {
        continue; // No contar las cerradas definitivamente
      } else if (req['R_Status_Name'] == '1_Open') {
        open++;
      } else {
        others++;
      }
    }

    // Ordenar por fecha descendente para asegurar que son las más recientes
    requests.sort((a, b) {
      final dateA = DateTime.tryParse(a['Created'] ?? '') ?? DateTime(0);
      final dateB = DateTime.tryParse(b['Created'] ?? '') ?? DateTime(0);
      return dateB.compareTo(dateA);
    });

    if (mounted) {
      setState(() {
        _openRequestsCount = open;
        _inProgressRequestsCount = others;
        _recentRequests = requests
            .where((r) => r['R_Status_Name'] != '9_Final Close')
            .take(3)
            .map((r) {
              String level = r['Priority_Name'] ?? 'Baja';
              Color baseColor = Colors.green;
              if (level == 'Alta')
                baseColor = Colors.red;
              else if (level == 'Media')
                baseColor = Colors.amber.shade800;

              String formattedTime = r['Created'] ?? '';
              try {
                if (formattedTime.isNotEmpty) {
                  final DateTime date = DateTime.parse(formattedTime).toLocal();
                  formattedTime =
                      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                }
              } catch (_) {}

              return {
                'code': r['DocumentNo'] ?? r['id'].toString(),
                'situation': r['R_RequestType_Name'] ?? 'Solicitud',
                'time': formattedTime,
                'level': level,
                'levelColor': baseColor,
                'levelBgColor': baseColor.withOpacity(0.2),
                'status': r['R_Status_Name'] ?? '1_Open',
              };
            })
            .toList();
        _isLoading = false;
      });
    }
  }

  Color _getAreaColor(String area) {
    switch (area) {
      case 'Soporte':
        return Colors.blue;
      case 'Desarrollo':
        return Colors.orange;
      case 'Ventas':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _editRequest(Map<String, dynamic> req) {
    String currentPriority = req['level'];
    String currentStatus = req['status'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return CustomModal(
            title: 'Editar Solicitud ${req['code']}',
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomDropdown<String>(
                  label: 'Nivel de Prioridad',
                  value: currentPriority,
                  items: ['Alta', 'Media', 'Baja']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null)
                      setStateDialog(() => currentPriority = val);
                  },
                ),
                const SizedBox(height: 16),
                CustomDropdown<String>(
                  label: 'Estado',
                  value: currentStatus,
                  items:
                      [
                            '1_Open',
                            '2_Waiting on customer',
                            '3_Closed',
                            '9_Final Close',
                          ]
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                  onChanged: (val) {
                    if (val != null) setStateDialog(() => currentStatus = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              CustomButton(
                text: 'Guardar',
                onPressed: () {
                  setState(() {
                    req['level'] = currentPriority;
                    req['status'] = currentStatus;
                    if (currentPriority == 'Alta') {
                      req['levelColor'] = Colors.red;
                    } else if (currentPriority == 'Media') {
                      req['levelColor'] = Colors.amber.shade800;
                    } else {
                      req['levelColor'] = Colors.green;
                    }
                    req['levelBgColor'] = req['levelColor'].withOpacity(0.2);
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Aplicación')),

      drawer: const CustomDrawer(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              'Bienvenido a PrimHub',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.spaceEvenly,
              children: [
                CardCustom(
                  hover: true,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color.fromRGBO(223, 231, 255, 1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.access_time,
                          color: Color.fromRGBO(79, 71, 229, 1),
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Horas De soporte',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF777D8A),
                            ),
                          ),
                          Text(
                            '32.5',
                            style: Theme.of(context).textTheme.displayMedium
                                ?.copyWith(
                                  color: const Color(0xff4F47E5),
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Contrato de 50 horas.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xff9DA3AF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'renovacion: 31/12/1015',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xff9DA3AF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                CardCustom(
                  hover: true,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color.fromRGBO(254, 244, 199, 1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.sync,
                          color: Color.fromRGBO(217, 119, 8, 1),
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Solicitudes Abiertas',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff777D8A),
                            ),
                          ),
                          Text(
                            '$_openRequestsCount',
                            style: Theme.of(context).textTheme.displayMedium
                                ?.copyWith(
                                  color: const Color(0xffD97708),
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '$_inProgressRequestsCount en revisión/progreso.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xff9DA3AF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
                CardCustom(
                  hover: true,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Accesos Rápidos',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff777D8A),
                        ),
                      ),
                      const SizedBox(height: 40),
                      CustomButton(
                        text: 'Crear Nueva Solicitud',
                        icon: Icons.add_circle_outline,
                        onPressed: () async {
                          final result = await showDialog(
                            context: context,
                            builder: (context) => const CreateRequestDialog(),
                          );
                          if (result == true) {
                            _loadRecentRequests(); // Recargar lista si se creó exitosamente
                          }
                        },
                        borderRadius: 30,
                      ),
                      const SizedBox(height: 20),
                      CustomButton(
                        text: 'Buscar en Manuales',
                        icon: Icons.search,
                        onPressed: () =>
                            Navigator.pushNamed(context, '/knowledge-base'),
                        backgroundColor: Colors.grey.shade200,
                        textColor: Colors.black87,
                        borderRadius: 30,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: CustomContainer(
                height: 400,
                width: 900,
                title: 'Rendimiento por Área',
                action: DropdownButton<String>(
                  value: _selectedChartFilter,
                  underline: Container(),
                  icon: const Icon(Icons.filter_list),
                  items: ['Todos', 'Soporte', 'Desarrollo', 'Ventas']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedChartFilter = val!;
                    });
                  },
                ),
                child: CustomAreaChart(
                  data: _selectedChartFilter == 'Todos'
                      ? _areaData.values.toList()
                      : [_areaData[_selectedChartFilter]!],
                  colors: _selectedChartFilter == 'Todos'
                      ? [Colors.blue, Colors.orange, Colors.green]
                      : [_getAreaColor(_selectedChartFilter)],
                  labels: _chartLabels,
                ),
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: CustomContainer(
                title: 'Solicitudes Recientes',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 1000),
                      child: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(50.0),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : Column(
                              children: _recentRequests.map((req) {
                                return InkWell(
                                  onTap: _isAdmin
                                      ? () => _editRequest(req)
                                      : null,
                                  hoverColor: Colors.blue.withOpacity(0.1),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12.0,
                                      horizontal: 8.0,
                                    ),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.black12,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              '${req['code']}: ',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            Text(
                                              '${req['situation']} ',
                                              style: const TextStyle(
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: req['levelBgColor'],
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                              ),
                                              child: Text(
                                                req['level'],
                                                style: TextStyle(
                                                  color: req['levelColor'],
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          req['time'],
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: CustomButton(
                        text: 'Ver todas las solicitudes',
                        onPressed: () =>
                            Navigator.pushNamed(context, '/my-requests'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
