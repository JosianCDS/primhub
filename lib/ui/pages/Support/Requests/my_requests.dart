// /home/alexander/Descargas/primhub/lib/ui/pages/Support/my_requests.dart

import 'package:flutter/material.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/contract_api.dart';
import 'package:primhub/ui/pages/Support/calendar.dart';
import 'package:primhub/ui/pages/Support/Requests/create_request_dialog.dart';
import 'package:primhub/ui/pages/Support/Requests/edit_request_dialog.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';
import 'package:primhub/ui/pages/Support/Request_Widgets/request_stats_card.dart';
import 'package:primhub/ui/pages/Support/Request_Widgets/request_filter_bar.dart';
import 'package:primhub/ui/pages/Support/Request_Widgets/requests_data_table.dart';
import 'package:primhub/ui/shared/custom_modal.dart';
import 'package:primhub/ui/shared/custom_button.dart';
import '../../../widgets/custom_drawer.dart';

class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({super.key});

  @override
  State<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  List<Map<String, dynamic>> _requests = [];
  List<dynamic> _rawRequests = [];
  bool _isLoading = true;
  bool _isAscending = false;
  bool _showHistory = false;
  bool _isInit = true;
  double? _contractedHours;
  double _consumedHours = 0.0;
  double _estimatedHours = 0.0;
  Map<String, int> _statusIdMap = {};
  int _currentPage = 0;
  int _rowsPerPage = 25;
  int? _selectedYear = 2026;
  String? _selectedBP;
  String? _selectedLevel;
  String? _selectedStatus;
  String? _selectedSituation;
  String? _selectedUser;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initData();
    _searchController.addListener(() => setState(() => _currentPage = 0));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    final total = await ContractApi.getContractedHours();
    final statuses = await fetchStatuses();
    if (mounted) {
      setState(() {
        _contractedHours = total;
        _statusIdMap = statuses;
      });
    }
    await _refreshRequest();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['showHistory'] == true) _showHistory = true;
      _isInit = false;
    }
  }

  Future<void> _refreshRequest() async {
    String? filter;
    if (AccessControl.limitToCurrentYear) {
      final currentYear = DateTime.now().year;
      filter = "Created ge '$currentYear-01-01T00:00:00Z' and Created le '-12-31T23:59:59Z'";
    }
    final requests = await fetchRequest(filter: filter);
    final processed = await processRequests(requests, _statusIdMap);

    if (mounted) {
      setState(() {
        _rawRequests = processed['rawRequests'];
        _requests = processed['requests'];
        _consumedHours = processed['consumedHours'];
        _estimatedHours = processed['estimatedHours'];
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteRequest(dynamic id) async {
    if (!AccessControl.canManageRequests) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tienes permisos para eliminar solicitudes.')));
      return;
    }
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => CustomModal(
        title: 'Confirmar Eliminación',
        content: const Text('¿Está seguro de que desea eliminar esta solicitud?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          CustomButton(text: 'Eliminar', backgroundColor: Colors.red, onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final success = await deleteRequestApi(id);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud eliminada correctamente')));
          _refreshRequest();
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al eliminar'), backgroundColor: Colors.red));
        }
      }
    }
  }

  void _editRequest(Map<String, dynamic> req) async {
    if (!AccessControl.canManageRequests) return;
    showDialog(
      context: context,
      builder: (context) => EditRequestDialog(request: req, statusIdMap: _statusIdMap, priorityMap: priorityMap, onSave: _initData, onDelete: () => _deleteRequest(req['realId'])),
    );
  }

  List<Map<String, dynamic>> _getFilteredRequests() {
    return _requests.where((alert) {
      bool isClosed = alert['status'] == '9_Final Close' || alert['statusId'] == 103;
      if (_showHistory != isClosed) return false;
      if (_selectedLevel != null && alert['level'] != _selectedLevel) return false;
      if (_selectedStatus != null && alert['status'] != _selectedStatus) return false;
      if (_selectedBP != null && alert['bpName'] != _selectedBP) return false;
      if (_selectedYear != null && alert['time'] != null && alert['time'].toString().isNotEmpty) {
        try {
          if (int.parse(alert['time'].toString().substring(0, 4)) != _selectedYear) return false;
        } catch (_) {}
      }
      if (_selectedSituation != null && alert['situation'] != _selectedSituation) return false;
      if (_selectedUser != null && alert['userName'] != _selectedUser) return false;
      if (_searchController.text.isNotEmpty && !alert['id'].toString().toLowerCase().contains(_searchController.text.toLowerCase())) return false;
      return true;
    }).toList()..sort((a, b) {
      final timeA = a['time'] ?? '';
      final timeB = b['time'] ?? '';
      return _isAscending ? timeA.compareTo(timeB) : timeB.compareTo(timeA);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredAlerts = _getFilteredRequests();
    final int totalItems = filteredAlerts.length;
    final int totalPages = (totalItems / _rowsPerPage).ceil();
    if (_currentPage >= totalPages) _currentPage = totalPages > 0 ? totalPages - 1 : 0;
    final int startIndex = _currentPage * _rowsPerPage;
    final int endIndex = (startIndex + _rowsPerPage < totalItems) ? startIndex + _rowsPerPage : totalItems;
    final paginatedAlerts = totalItems > 0 ? filteredAlerts.sublist(startIndex, endIndex) : <Map<String, dynamic>>[];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis Solicitudes De Soporte'),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: const [
              Tab(text: 'Listado'),
              Tab(text: 'Calendario'),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _initData();
                },
                icon: const Icon(Icons.refresh),
              ),
            ),
          ],
        ),
        drawer: const CustomDrawer(),
        body: SafeArea(
          child: TabBarView(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_contractedHours != null) RequestStatsCard(contractedHours: _contractedHours, consumedHours: _consumedHours, estimatedHours: _estimatedHours),
                    RequestFilterBar(
                      searchController: _searchController,
                      selectedYear: _selectedYear,
                      selectedBP: _selectedBP,
                      selectedSituation: _selectedSituation,
                      selectedUser: _selectedUser,
                      selectedLevel: _selectedLevel,
                      selectedStatus: _selectedStatus,
                      isAscending: _isAscending,
                      rowsPerPage: _rowsPerPage,
                      showHistory: _showHistory,
                      requests: _requests,
                      statusIdMap: _statusIdMap,
                      onYearChanged: (val) => setState(() {
                        _selectedYear = val;
                        _currentPage = 0;
                      }),
                      onBPChanged: (val) => setState(() {
                        _selectedBP = val;
                        _currentPage = 0;
                      }),
                      onSituationChanged: (val) => setState(() {
                        _selectedSituation = val;
                        _currentPage = 0;
                      }),
                      onUserChanged: (val) => setState(() {
                        _selectedUser = val;
                        _currentPage = 0;
                      }),
                      onLevelChanged: (val) => setState(() {
                        _selectedLevel = val;
                        _currentPage = 0;
                      }),
                      onStatusChanged: (val) => setState(() {
                        _selectedStatus = val;
                        _currentPage = 0;
                      }),
                      onSortChanged: () => setState(() {
                        _isAscending = !_isAscending;
                        _currentPage = 0;
                      }),
                      onRowsPerPageChanged: (val) => setState(() {
                        _rowsPerPage = val!;
                        _currentPage = 0;
                      }),
                      onClearFilters: () => setState(() {
                        _selectedLevel = null;
                        _selectedStatus = null;
                        _selectedSituation = null;
                        _selectedUser = null;
                        _searchController.clear();
                        _isAscending = false;
                        _currentPage = 0;
                      }),
                      onAddRequest: () async {
                        if (await showDialog(context: context, builder: (context) => const CreateRequestDialog()) == true) _initData();
                      },
                      onToggleHistory: () => setState(() {
                        _showHistory = !_showHistory;
                        _selectedStatus = null;
                      }),
                    ),
                    const SizedBox(height: 20),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 1000),
                      child: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(50.0),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : RequestsDataTable(requests: paginatedAlerts, onEdit: _editRequest),
                    ),
                    if (totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(icon: const Icon(Icons.chevron_left), onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null),
                            Text('Página ${_currentPage + 1} de  ( registros)', style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(icon: const Icon(Icons.chevron_right), onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              CalendarTab(requests: _rawRequests),
            ],
          ),
        ),
      ),
    );
  }
}
