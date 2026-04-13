import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/contract_api.dart';
import 'package:primhub/api/admin_view_mode.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/api/validation_manager.dart';
import 'package:primhub/ui/pages/Support/calendar.dart';
import 'package:primhub/ui/pages/Support/Requests/create_request_dialog.dart';
import 'package:primhub/ui/pages/Support/Requests/edit_request_dialog.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';
import 'package:primhub/ui/pages/Support/Request_Widgets/request_stats_card.dart';
import 'package:primhub/ui/pages/Support/Request_Widgets/request_filter_bar.dart';
import 'package:primhub/ui/pages/Support/Request_Widgets/requests_data_table.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import '../../../widgets/custom_drawer.dart';
import 'package:primhub/ui/pages/Home/Home_Controller/home_controller.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/api/global_cache.dart';

class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({super.key});

  @override
  State<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  List<Map<String, dynamic>> _requests = [];
  List<dynamic> _rawRequests = [];
  List<dynamic> _allFetchedRequests = [];
  List<Map<String, dynamic>> _allContracts = [];
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
  String? _selectedSalesRep;
  String? _selectedUser;
  final TextEditingController _searchController = TextEditingController();

  int? _bpId;
  List<Map<String, dynamic>> _bPartners = [];
  List<dynamic> _users = [];

  final _adminViewModeManager = AdminViewModeManager();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _currentPage = 0));
    _adminViewModeManager.addListener(_onViewModeChanged);
  }

  void _onViewModeChanged() {
    _initData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      Object? extra;
      try {
        extra = GoRouterState.of(context).extra;
      } catch (_) {}

      final args = extra ?? ModalRoute.of(context)?.settings.arguments;

      if (args is Map) {
        if (args['showHistory'] == true) _showHistory = true;
        if (args['bpId'] != null) _bpId = args['bpId'];
        if (args['selectedStatus'] != null) {
          _selectedStatus = args['selectedStatus'];
          // Si tocamos un estado final, aseguramos que se vea la bitácora
          if (_selectedStatus!.toLowerCase().contains('close') || _selectedStatus!.toLowerCase().contains('cerrad')) _showHistory = true;
        }
        if (args['selectedLevel'] != null) _selectedLevel = args['selectedLevel'];
        _selectedYear = null; // Reiniciar año para que el gráfico aplique libremente
      }
      _isInit = false;
      _initData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _adminViewModeManager.removeListener(_onViewModeChanged);
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);

    await GlobalCache.syncData();

    if (AccessControl.isAdmin) {
      _bPartners = GlobalCache.bPartners;
      _users = GlobalCache.users;

      // Auto-configurar el filtro visual local si entramos desde un atajo
      if (_bpId != null && _selectedBP == null) {
        final found = _bPartners.firstWhere((bp) => bp['id'] == _bpId, orElse: () => <String, dynamic>{});
        if (found.isNotEmpty) {
          _selectedBP = found['Name'];
        }
      }
    }
    _allContracts = GlobalCache.contracts;
    if (_bpId != null && AccessControl.isAdmin) {
      _allContracts = _allContracts.where((c) => c['C_BPartner_ID'] == _bpId).toList();
    }
    _statusIdMap = GlobalCache.statuses;

    final double total = _allContracts.fold(0.0, (sum, contract) => sum + ((contract['contractedHours'] as num?)?.toDouble() ?? 0.0));

    if (mounted) {
      setState(() {
        _contractedHours = total > 0 ? total : null;
      });
    }

    // 3. Procesar la data (sin volver a consultar la red)
    await _refreshRequest(fetchNetwork: false);
  }

  Future<void> _refreshRequest({bool fetchNetwork = true}) async {
    if (fetchNetwork) {
      await GlobalCache.syncData(force: true);
    }

    List<dynamic> allFetchedRequests = GlobalCache.requests;
    if (AccessControl.isAdmin && _bpId != null) {
      allFetchedRequests = allFetchedRequests.where((r) => r['C_BPartner_ID'] is Map ? r['C_BPartner_ID']['id'] == _bpId : r['C_BPartner_ID'] == _bpId).toList();
    }
    _allFetchedRequests = allFetchedRequests;

    // === LA CLAVE: Filtrar las que NO son de proyecto ===
    final supportRequestsOnly = _allFetchedRequests.where((req) {
      final recordUU = req['Record_UU'];
      return recordUU == null || recordUU.toString().isEmpty;
    }).toList();

    // 2. Process ALL support requests to populate the filter bar and serve as the base for the table
    final processedAll = await processRequests(supportRequestsOnly, _statusIdMap);

    if (mounted) {
      setState(() {
        _rawRequests = processedAll['rawRequests'];
        _requests = processedAll['requests']; // Full list for UI
      });
      _updateStatsLocally();
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateStatsLocally() {
    double contractedForStats = 0.0;
    double consumedForStats = 0.0;
    double estimatedForStats = 0.0;

    if (_selectedBP != null) {
      final bpRequests = _requests.where((r) => r['bpName'] == _selectedBP).toList();
      for (var r in bpRequests) {
        double qty = double.tryParse(r['qtyPlan']?.toString() ?? '0.0') ?? 0.0;
        if (r['status'] == '9_Final Close' || r['statusId'] == 103) {
          consumedForStats += qty;
        } else {
          estimatedForStats += qty;
        }
      }

      final foundBp = _bPartners.firstWhere((bp) => bp['Name'] == _selectedBP, orElse: () => {});
      int? bpIdForContract;
      if (foundBp.isNotEmpty) {
        bpIdForContract = foundBp['id'];
      } else if (User.cBPartnerID != null && User.name == _selectedBP) {
        bpIdForContract = User.cBPartnerID;
      }

      if (bpIdForContract != null) {
        contractedForStats = _allContracts.where((c) => c['C_BPartner_ID'] == bpIdForContract).fold(0.0, (sum, c) => sum + ((c['contractedHours'] as num?)?.toDouble() ?? 0.0));
      }
    } else {
      for (var r in _requests) {
        double qty = double.tryParse(r['qtyPlan']?.toString() ?? '0.0') ?? 0.0;
        if (r['status'] == '9_Final Close' || r['statusId'] == 103) {
          consumedForStats += qty;
        } else {
          estimatedForStats += qty;
        }
      }
      contractedForStats = _allContracts.fold(0.0, (sum, contract) => sum + ((contract['contractedHours'] as num?)?.toDouble() ?? 0.0));
    }

    setState(() {
      _consumedHours = consumedForStats;
      _estimatedHours = estimatedForStats;
      _contractedHours = contractedForStats > 0 ? contractedForStats : null;
    });
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

  Future<void> _showExceptionDialog() async {
    if (!AccessControl.isAdmin) return;

    final Set<int> tempSelectedIds = Set.from(ValidationManager.hourValidationExceptions);
    List<dynamic> allBPartners = [];
    bool isFetching = true;

    await showDialog(
      context: context,
      builder: (context) {
        String searchQuery = '';
        return CustomModal(
          title: 'Gestionar Excepciones de Horas',
          width: 500,
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              if (isFetching && allBPartners.isEmpty) {
                ProjectsLogic().fetchBPartners().then((bps) {
                  if (context.mounted) {
                    setState(() {
                      allBPartners = bps;
                      isFetching = false;
                    });
                  }
                });
              }

              final filteredBps = allBPartners.where((bp) => (bp['Name'] ?? '').toString().toLowerCase().contains(searchQuery.toLowerCase())).toList();

              return SizedBox(
                height: 400,
                child: isFetching
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Buscar tercero...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onChanged: (val) => setState(() => searchQuery = val),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: filteredBps.isEmpty
                                ? const Center(child: Text('No se encontraron terceros.'))
                                : ListView.builder(
                                    itemCount: filteredBps.length,
                                    itemBuilder: (context, index) {
                                      final bp = filteredBps[index];
                                      final rawId = bp['id'] ?? bp['C_BPartner_ID'];
                                      final intId = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;
                                      return CheckboxListTile(title: Text(bp['Name'] ?? 'Tercero $intId'), value: tempSelectedIds.contains(intId), onChanged: (bool? value) => setState(() => value == true ? tempSelectedIds.add(intId) : tempSelectedIds.remove(intId)));
                                    },
                                  ),
                          ),
                        ],
                      ),
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            CustomButton(
              text: 'Guardar',
              onPressed: () {
                ValidationManager.setExceptions(tempSelectedIds);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excepciones de validación de horas actualizadas.')));
              },
            ),
          ],
        );
      },
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
      if (_selectedSalesRep != null && alert['salesRepName'] != _selectedSalesRep) return false;
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
              InkWell(
                onTap: _showExceptionDialog,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined),
                      SizedBox(width: 8),
                      Text('Excepción de Horas', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _initData();
                },
                icon: const Icon(Icons.refresh),
                tooltip: 'Refrescar',
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
                    RequestStatsCard(contractedHours: _contractedHours, consumedHours: _consumedHours, estimatedHours: _estimatedHours),
                    RequestFilterBar(
                      searchController: _searchController,
                      selectedYear: _selectedYear,
                      selectedBP: _selectedBP,
                      selectedSituation: _selectedSituation,
                      selectedUser: _selectedUser,
                      selectedLevel: _selectedLevel,
                      selectedStatus: _selectedStatus,
                      selectedSalesRep: _selectedSalesRep,
                      isAscending: _isAscending,
                      rowsPerPage: _rowsPerPage,
                      showHistory: _showHistory,
                      requests: _requests,
                      users: _users,
                      bPartners: _bPartners,
                      statusIdMap: _statusIdMap,
                      onYearChanged: (val) => setState(() {
                        _selectedYear = val;
                        _currentPage = 0;
                      }),
                      onBPChanged: (val) {
                        setState(() {
                          _selectedBP = val;
                          _currentPage = 0;
                          _isLoading = true;
                          if (val != null) {
                            final found = _bPartners.firstWhere((bp) => bp['Name'] == val, orElse: () => <String, dynamic>{});
                            if (found.isNotEmpty) {
                              _bpId = found['id'];
                            }
                          } else {
                            _bpId = null;
                          }
                        });
                        _initData();
                      },
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
                      onSalesRepChanged: (val) => setState(() {
                        _selectedSalesRep = val;
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
                      onClearFilters: () {
                        setState(() {
                          _selectedBP = null;
                          _selectedLevel = null;
                          _selectedStatus = null;
                          _selectedSituation = null;
                          _selectedSalesRep = null;
                          _selectedUser = null;
                          _searchController.clear();
                          _isAscending = false;
                          _currentPage = 0;
                          _bpId = null; // Reiniciar memoria de navegación
                          _isLoading = true;
                        });
                        _initData();
                      },
                      onAddRequest: () async {
                        if (await showDialog(
                              context: context,
                              builder: (context) => CreateRequestDialog(bPartners: _bPartners, selectedBPartnerId: _bpId),
                            ) ==
                            true)
                          _initData();
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
                          : RequestsDataTable(requests: paginatedAlerts, onEdit: _editRequest, onRefresh: _initData),
                    ),
                    if (totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(icon: const Icon(Icons.chevron_left), onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null),
                            Text('Página ${_currentPage + 1} de $totalPages', style: const TextStyle(fontWeight: FontWeight.bold)),
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
