import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/api/contract_api.dart';
import 'package:primhub/ui/pages/request/create_request_dialog.dart';
import 'package:primhub/ui/pages/request/request_functions.dart';
import 'package:primhub/ui/shared/custom_button.dart';
import 'package:primhub/ui/shared/cardcustom.dart';
import 'package:primhub/ui/shared/custom_container.dart';
import 'package:primhub/ui/shared/custom_inputs.dart';
import 'package:primhub/ui/shared/custom_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_drawer.dart';
import 'package:primhub/ui/shared/duration_formatter.dart';

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
  List<dynamic> _allRequests = [];
  bool _isLoading = true;
  int _openRequestsCount = 0;
  int _inProgressRequestsCount = 0;
  int _closedRequestsCount = 0;
  bool _isAdmin = true;
  double? _contractedHours;
  double _consumedHours = 0.0;

  // State for validation card
  bool _validationLoading = true;
  bool _hasSupport = false;
  bool _hasProject = false;
  int? _cBPartnerID;
  String? _partnerName;
  String? _projectPartnerName;
  List<dynamic> _projects = [];
  int _projectCount = 0;
  String _username = '';

  @override
  void initState() {
    super.initState();
    _checkRole();
    _initData();
    _loadCurrentUser();
  }

  void _loadCurrentUser() {
    try {
      final payload = Token.decodePayload(Token.token);
      setState(() {
        _username = payload['sub'] ?? '';
      });
    } catch (_) {}
  }

  Future<void> _initData() async {
    await _loadValidationData();
    await _loadContractedHours();
    await _loadRecentRequests();
  }

  Future<void> _checkRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted)
      setState(
        () => _isAdmin = (prefs.getString('user_role') ?? 'ADMIN') == 'ADMIN',
      );
  }

  Future<void> _loadValidationData() async {
    if (mounted) setState(() => _validationLoading = true);
    final prefs = await SharedPreferences.getInstance();

    int? cBPartnerID = User.cBPartnerID;
    String? partnerName;
    String? projectPartnerName;

    if (cBPartnerID != null) {
      try {
        // 1. Obtener Nombre del Tercero
        final pResponse = await http.get(
          Uri.parse(
            '${Endpoint.cBPartner}?\$filter=C_BPartner_ID eq $cBPartnerID',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': Token.token,
          },
        );
        if (pResponse.statusCode == 200) {
          final data = json.decode(utf8.decode(pResponse.bodyBytes));
          if (data['records'] != null && (data['records'] as List).isNotEmpty) {
            partnerName = data['records'][0]['Name'];
          }
        }

        // 2. Obtener Nombre del Tercero en el Proyecto (si existe alguno)
        final projResponse = await http.get(
          Uri.parse(
            '${Endpoint.project}?\$filter=C_BPartner_ID eq $cBPartnerID',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': Token.token,
          },
        );
        if (projResponse.statusCode == 200) {
          final data = json.decode(utf8.decode(projResponse.bodyBytes));
          if (data['records'] != null && (data['records'] as List).isNotEmpty) {
            projectPartnerName =
                data['records'][0]['C_BPartner_ID']?['identifier'];
            _projects = data['records'];
            _projectCount = (data['records'] as List).length;
          }
        }
      } catch (e) {
        debugPrint('Error fetching validation names: $e');
      }
    }

    if (mounted) {
      setState(() {
        _hasSupport = prefs.getBool('has_support') ?? false;
        _hasProject = prefs.getBool('has_project') ?? false;
        _cBPartnerID = cBPartnerID;
        _partnerName = partnerName;
        _projectPartnerName = projectPartnerName;
        _projects = _projects;
        _projectCount = _projectCount;
        _validationLoading = false;
      });
    }
  }

  Future<void> _loadRecentRequests() async {
    final requests = await fetchRequest();

    int open = 0;
    int others = 0;
    int closed = 0;
    double totalConsumed = 0.0;

    for (var req in requests) {
      // Solo contar consumo si está cerrado
      if (req['R_Status_Name'] != '9_Final Close' &&
          req['R_Status_ID'] != 103) {
        // Si no está cerrado, no suma consumo
      } else {
        // Lógica de consumo para todos los tickets cerrados
        double hours = (req['QtyPlan'] as num?)?.toDouble() ?? 0.0;
        totalConsumed += hours;
      }

      if (req['R_Status_Name'] == '9_Final Close' ||
          req['R_Status_ID'] == 103) {
        closed++;
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
        _closedRequestsCount = closed;
        _consumedHours = totalConsumed;
        _allRequests = requests
            .where(
              (r) =>
                  r['R_Status_Name'] != '9_Final Close' &&
                  r['R_Status_ID'] != 103,
            )
            .toList();
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    var filtered = List<dynamic>.from(_allRequests);

    _recentRequests = filtered.take(5).map((r) {
      String level = r['Priority_Name'] ?? 'Baja';
      Color baseColor = Colors.green;
      if (level == 'Urgente')
        baseColor = Colors.purple;
      else if (level == 'Alta')
        baseColor = Colors.red;
      else if (level == 'Media')
        baseColor = Colors.amber.shade800;
      else if (level == 'Menor')
        baseColor = Colors.grey;

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
        'description': r['Summary'] ?? '',
        'time': formattedTime,
        'level': level,
        'levelColor': baseColor,
        'levelBgColor': baseColor.withOpacity(0.2),
        'status': r['R_Status_Name'] ?? '1_Open',
      };
    }).toList();
  }

  Future<void> _loadContractedHours() async {
    final total = await ContractApi.getContractedHours();
    if (mounted && total != null) {
      setState(() {
        _contractedHours = total;
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
                  items: ['Urgente', 'Alta', 'Media', 'Baja', 'Menor']
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
                    if (currentPriority == 'Urgente') {
                      req['levelColor'] = Colors.purple;
                    } else if (currentPriority == 'Alta') {
                      req['levelColor'] = Colors.red;
                    } else if (currentPriority == 'Media') {
                      req['levelColor'] = Colors.amber.shade800;
                    } else if (currentPriority == 'Menor') {
                      req['levelColor'] = Colors.grey;
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

  Widget _buildValidationStep(String title, String subtitle, bool success) {
    return ListTile(
      leading: Icon(
        success ? Icons.check_circle : Icons.cancel,
        color: success ? Colors.green : Colors.red,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildSupportHoursCard(bool isDark, Color textColor, double progress) {
    return CardCustom(
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
              Text(
                'Horas De soporte Disponibles',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Text(
                _contractedHours == null
                    ? '...'
                    : DurationFormatter.format(
                        _contractedHours! - _consumedHours,
                      ),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: const Color(0xff4F47E5),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
              duration: const Duration(seconds: 2),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                backgroundColor: isDark
                    ? Colors.grey.shade800
                    : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress > 1.0
                      ? Colors.red
                      : const Color.fromARGB(255, 200, 42, 42),
                ),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _contractedHours == null
                ? 'Cargando contrato...'
                : 'Contrato de ${DurationFormatter.format(_contractedHours!)}.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'renovacion: 31/12/2026',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Frecuencia: ${ProductChip.frecuencyID ?? 'No definida'}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Producto Contratado: ${ProductChip.mProductID ?? 'N/A'}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportRequestsCard(bool isDark, Color textColor) {
    return CardCustom(
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
              Text(
                'Solicitudes ya atendidas',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Text(
                '$_closedRequestsCount',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: const Color(0xffD97708),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '$_inProgressRequestsCount están en revisión/progreso.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildProjectDurationCard(
    bool isDark,
    Color textColor,
    Map<String, dynamic> project,
  ) {
    String title = 'Días Transcurridos';
    String value = '0';
    String subtitle = 'Sin fecha de contrato';
    String projectName = project['Name'] ?? 'Proyecto';
    String? dateContract = project['DateContract'];
    String? dateFinish = project['DateFinish'];

    if (dateContract != null) {
      DateTime start = DateTime.parse(dateContract);
      DateTime end = DateTime.now();
      bool isClosed = false;

      if (dateFinish != null && dateFinish.isNotEmpty) {
        end = DateTime.parse(dateFinish);
        isClosed = true;
      }

      int days = end.difference(start).inDays;
      value = days.toString();

      if (isClosed) {
        title = 'Proyecto Cerrado';
        subtitle =
            'Del ${start.day}/${start.month}/${start.year} al ${end.day}/${end.month}/${end.year}';
      } else {
        subtitle = 'Desde ${start.day}/${start.month}/${start.year}';
      }
    }

    return CardCustom(
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
              Icons.calendar_today,
              color: Color.fromRGBO(79, 71, 229, 1),
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  projectName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor.withOpacity(0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: const Color(0xff4F47E5),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectDeliverablesCard(bool isDark, Color textColor) {
    return CardCustom(
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
              Icons.folder_special,
              color: Color.fromRGBO(217, 119, 8, 1),
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Entregables ya Creados',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Text(
                '$_projectCount',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: const Color(0xffD97708),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Proyectos activos asociados.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF777D8A);
    double progress = 0.0;
    if (_contractedHours != null && _contractedHours! > 0) {
      progress = _consumedHours / _contractedHours!;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('PrimHub')),

      drawer: const CustomDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Text(
                'Bienvenido/a $_username',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
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
                        Text(
                          'Accesos Rápidos',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 40),
                        /*
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
                      */
                        CustomButton(
                          text: 'Buscar en Manuales',
                          icon: Icons.search,
                          onPressed: null,
                          backgroundColor: Colors.grey.shade200,
                          textColor: Colors.black87,
                          borderRadius: 30,
                        ),
                      ],
                    ),
                  ),
                  if (_hasSupport) ...[
                    _buildSupportHoursCard(isDark, textColor, progress),
                    _buildSupportRequestsCard(isDark, textColor),
                  ],
                  if (_hasProject) ...[
                    ..._projects.map(
                      (proj) =>
                          _buildProjectDurationCard(isDark, textColor, proj),
                    ),
                    _buildProjectDeliverablesCard(isDark, textColor),
                  ],
                ],
              ),
              const SizedBox(height: 30),
              /*
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
            */
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
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : Column(
                                children: _recentRequests.map((req) {
                                  return InkWell(
                                    onTap: null,
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
                                            req['description'] ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.grey[400]
                                                  : Colors.grey[700],
                                              fontSize: 14,
                                            ),
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
      ),
    );
  }
}
