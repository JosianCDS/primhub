import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/api/contract_api.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/api/admin_view_mode.dart';
import 'package:primhub/api/validation_manager.dart';
import 'package:primhub/ui/Shared_Custom/cardcustom.dart';
import 'package:primhub/ui/Shared_Custom/custom_container.dart';
import 'package:primhub/ui/Shared_Custom/custom_table.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/widgets/project_sidebar.dart';
import '../../widgets/custom_drawer.dart';
import 'package:primhub/ui/widgets/duration_formatter.dart';
import 'Requests/request_functions.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/api/global_cache.dart';
import 'package:primhub/ui/widgets/project_bottom_nav.dart';
import 'package:primhub/api/api_utils.dart';
import 'package:primhub/ui/Shared_Custom/custom_skeleton.dart';
import 'package:primhub/ui/Shared_Custom/user_info_leading.dart';
import 'package:primhub/ui/pages/Support/Request_Widgets/support_summary_premium.dart';
import 'package:primhub/ui/Shared_Custom/help_icon.dart';
import 'package:primhub/ImagesManagment/fecthAttachments.dart';
import 'package:primhub/ImagesManagment/postAttachments.dart';
import 'package:primhub/ImagesManagment/downloadAttachments.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/api/api_http.dart' as http;
import 'package:primhub/ui/pages/Projects/Projects_Widgets/file_preview_manager.dart';

class SupportDashboardPage extends StatefulWidget {
  const SupportDashboardPage({super.key});

  @override
  State<SupportDashboardPage> createState() => _SupportDashboardPageState();
}

class _SupportDashboardPageState extends State<SupportDashboardPage> {
  List<Map<String, dynamic>> _supportRecords = [];
  bool _isLoading = true;
  bool _isLoadingBPartners = false;
  double _totalConsumedHours = 0.0;
  double? _contractedHours;
  double _inProgressHours = 0.0;
  int _inProgressRequestsCount = 0;
  int _completedRequestsCount = 0;
  List<Map<String, dynamic>> _processedChips = [];

  bool _isInit = true;

  // Filtro de Tercero
  List<Map<String, dynamic>> _bPartners = [];
  Map<String, int> _statusIdMap = {};
  int? _selectedBpId;
  List<Map<String, dynamic>> _productChips = []; // Fichas crudas del API
  List<Map<String, dynamic>> _allRequests =
      []; // Todas las solicitudes procesadas
  int? _selectedSummaryChipId; // Chip seleccionado para el resumen superior
  final _adminViewModeManager = AdminViewModeManager();

  // Paginación y Filtros
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 0;
  int _rowsPerPage = 25;
  bool _isAscending = false;
  List<int> _selectedYears = [DateTime.now().year];

  @override
  void initState() {
    super.initState();
    _adminViewModeManager.addListener(_onViewModeChanged);
    GlobalCache.backgroundSyncNotifier.addListener(_onBackgroundSyncChanged);
    _searchController.addListener(() => setState(() => _currentPage = 0));
  }

  int get _activeFilterCount {
    int count = 0;
    // Ya no contamos el BPartner aquí porque tiene su selector global arriba
    if (_searchController.text.isNotEmpty) count++;
    if (_selectedYears.isNotEmpty &&
        (_selectedYears.length > 1 ||
            (_selectedYears.first != DateTime.now().year))) {
      count++;
    }
    return count;
  }

  void _onBackgroundSyncChanged() async {
    if (!GlobalCache.backgroundSyncNotifier.value && mounted) {
      // Asegurar que _refreshData se llama después del frame actual para evitar setState durante la construcción.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshData();
      });
    }
  }

  void _onViewModeChanged() async {
    // Asegurar que _initData se llama después del frame actual para evitar setState durante la construcción.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initData();
    });
  }

  @override
  void dispose() {
    _adminViewModeManager.removeListener(_onViewModeChanged);
    GlobalCache.backgroundSyncNotifier.removeListener(_onBackgroundSyncChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      Object? extra;
      try {
        extra = GoRouterState.of(context).extra;
      } catch (_) {}

      final args = extra as Map<String, dynamic>?;
      if (args != null) {
        if (args['bpId'] != null) _selectedBpId = args['bpId'];
        if (args['chipId'] != null) _selectedSummaryChipId = args['chipId'];
        if (args['search'] != null) _searchController.text = args['search'];
      } else {
        _selectedBpId = AccessControl.isAdmin ? null : User.cBPartnerID;
      }
      // Diferir la carga de datos hasta después del primer frame para evitar el error "setState() called during build".
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initData();
      });
      _isInit = false;
    }
  }

  Future<void> _initData() async {
    if (AccessControl.isAdmin && _bPartners.isEmpty) {
      setState(() {
        _isLoadingBPartners = true;
      });
    }

    try {
      // Forzar sincronización de GlobalCache para tener los últimos datos (ej. renombramientos de fichas)
      await GlobalCache.syncData(force: true);

      if (AccessControl.isAdmin && _bPartners.isEmpty) {
        // Obtenemos la lista cruda de la API
        // Fetch all BPs with their flags to apply consistent filtering
        final allBps = await ProjectsLogic().fetchBPartners();

        if (mounted) {
          setState(() {
            // Aplicamos el filtro para que sean solo clientes activos y no proveedores
            _bPartners = allBps
                .where((bp) {
                  final name = bp['Name']?.toString() ?? '';

                  final rawVendor = bp['IsVendor'] ?? bp['isVendor'];
                  final isVendorStr = rawVendor?.toString().trim().toLowerCase();
                  bool isVendor = isVendorStr == 'true' || isVendorStr == 'y';

                  final rawCustomer = bp['IsCustomer'] ?? bp['isCustomer'];
                  final isCustomerStr = rawCustomer
                      ?.toString()
                      .trim()
                      .toLowerCase();
                  bool isCustomer =
                      isCustomerStr == 'true' || isCustomerStr == 'y';
                  if (rawCustomer == null) isCustomer = true;

                  // REGLA: No debe empezar con "~" y debe ser Cliente
                  return !name.startsWith('~') &&
                      isCustomer &&
                      !isVendor; // Excluir proveedores
                })
                .map((bp) => Map<String, dynamic>.from(bp as Map))
                .toList();

            // Si el tercero seleccionado previamente ya no está en la lista filtrada, lo limpiamos
            if (_selectedBpId != null &&
                !_bPartners.any((bp) => bp['id'] == _selectedBpId)) {
              _selectedBpId = null;
            }
          });
        }
      }
      await _fetchProductChips(); // Cargar fichas para el BP seleccionado
      _statusIdMap = await fetchStatuses();
      await _refreshData();
    } catch (_) {
      // Manejar excepciones de forma silenciosa o relanzar
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBPartners = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    if (mounted) setState(() => _isLoading = true);
    await _loadContractedHours();
    await _loadSupportData();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProductChips() async {
    if (_selectedBpId == null) {
      if (mounted) setState(() => _productChips = []);
      return;
    }

    // Usamos GlobalCache para ser consistentes con el Home
    final fetchedChips = GlobalCache.productChips.where((chip) {
      final rawBp = chip['C_BPartner_ID'];
      final chipBpId = rawBp is Map
          ? (rawBp['id'] as num?)?.toInt()
          : (rawBp as num?)?.toInt();

      final isActive = chip['IsActive'] == 'Y' || chip['IsActive'] == true;
      return chipBpId == _selectedBpId && isActive;
    }).toList();

    if (mounted) {
      setState(() => _productChips = fetchedChips);
    }
  }

  Future<void> _loadSupportData() async {
    String filter = "";
    List<String> conditions = [];

    if (_selectedBpId != null) {
      conditions.add("(C_BPartner_ID eq $_selectedBpId)");
    } else if (!AccessControl.isAdmin && User.cBPartnerID != null) {
      conditions.add("(C_BPartner_ID eq ${User.cBPartnerID})");
    }

    // Eliminamos el filtro de año por defecto para ver todo el historial de consumo
    // si el usuario desea filtrar por año lo hará desde la UI.
    /*
    if (_selectedYears.isNotEmpty) {
      String yearFilterStr = _selectedYears.map((y) => "year(Created) eq $y").join(" or ");
      conditions.add("($yearFilterStr)");
    }
    */

    filter = conditions.join(" and ");

    // Filtramos solo solicitudes que no sean de proyecto
    // Priorizamos C_Project_ID eq null y mantenemos Record_UU eq null como refuerzo
    final String supportFilter = "(C_Project_ID eq null and Record_UU eq null)";
    filter = filter.isNotEmpty ? "$filter and $supportFilter" : supportFilter;

    final rawRequests = await fetchRequest(
      filter: filter,
      expand: 'C_Order_ID(\$select=DocumentNo)',
    );

    final processedData = await processRequests(rawRequests, _statusIdMap);
    final allRequests = (processedData['requests'] as List<Map<String, dynamic>>)
        .where((req) => req['productChipId'] != null)
        .toList();

    final archivedId = _statusIdMap.entries
        .firstWhere(
          (e) => e.key.toLowerCase().contains('archivada'),
          orElse: () => const MapEntry('', 0),
        )
        .value;

    final List<Map<String, dynamic>> closedRequests = allRequests
        .where((req) => req['isClosed'] == true)
        .toList();
    final List<Map<String, dynamic>> inProgressRequests = allRequests
        .where((req) => req['isClosed'] != true)
        .toList();

    final searchedRequests = closedRequests.where((req) {
      if (_searchController.text.isNotEmpty) {
        final search = _searchController.text.toLowerCase();
        return req['id'].toString().toLowerCase().contains(search) ||
            (req['descriptionClean'] ?? '').toString().toLowerCase().contains(
              search,
            );
      }
      return true;
    }).toList();

    if (mounted) {
      setState(() {
        _supportRecords = searchedRequests;
        _allRequests = allRequests;
        _totalConsumedHours =
            (processedData['consumedHours'] as num?)?.toDouble() ?? 0.0;
        _inProgressHours =
            (processedData['inProgressHours'] as num?)?.toDouble() ?? 0.0;
        _inProgressRequestsCount = inProgressRequests.length;
        _completedRequestsCount = closedRequests.length;
      });
      await _loadContractedHours();
    }
  }

  Future<void> _loadContractedHours() async {
    if (mounted) {
      // Ordenar fichas por fecha de creación (FIFO)
      List<Map<String, dynamic>> sortedChips = List.from(_productChips);
      sortedChips.sort((a, b) {
        final dateA = DateTime.tryParse(a['Created'] ?? '') ?? DateTime(0);
        final dateB = DateTime.tryParse(b['Created'] ?? '') ?? DateTime(0);
        return dateA.compareTo(dateB);
      });

      double totalAcquired = 0.0;
      for (var chip in sortedChips) {
        totalAcquired += (chip['Qty'] as num?)?.toDouble() ?? 0.0;
      }

      // Mapeo de consumo y estimación por ID de ficha vinculada
      final Map<int, double> chipConsumedMap = {};
      final Map<int, double> chipEstimatedMap = {};
      double globalUnlinkedConsumed = 0.0;
      double globalUnlinkedEstimated = 0.0;

      for (var req in _allRequests) {
        final chipId = req['productChipId'] as int?;
        final qty = (req['qtySpent'] as num?)?.toDouble() ?? 0.0;
        final bool isClosed = req['isClosed'] == true;

        if (chipId != null) {
          if (isClosed) {
            chipConsumedMap[chipId] = (chipConsumedMap[chipId] ?? 0.0) + qty;
          } else {
            chipEstimatedMap[chipId] = (chipEstimatedMap[chipId] ?? 0.0) + qty;
          }
        }
        // Las solicitudes sin chipId se ignoran para el resumen global de consumo según instrucción
      }

      // El total consumido global ahora es la suma de los consumos vinculados
      double totalConsumedLinked = chipConsumedMap.values.fold(
        0.0,
        (a, b) => a + b,
      );
      double totalEstimatedLinked = chipEstimatedMap.values.fold(
        0.0,
        (a, b) => a + b,
      );

      double remainingToDeduct = 0.0; // Ya no hay consumo global FIFO
      double remainingEstimatedToDeduct = 0.0;
      List<Map<String, dynamic>> processed = [];

      for (var chip in sortedChips) {
        final int chipId = chip['id'];
        double totalQty = (chip['Qty'] as num?)?.toDouble() ?? 0.0;

        // Consumo directo vinculado
        double consumedFromThis = chipConsumedMap[chipId] ?? 0.0;
        double estimatedFromThis = chipEstimatedMap[chipId] ?? 0.0;

        // Si hay saldo después del consumo directo, deducir consumo global FIFO
        double remainingCapacity = totalQty - consumedFromThis;
        double additionalConsumption = 0.0;
        double additionalEstimation = 0.0;

        if (remainingToDeduct > 0 && remainingCapacity > 0) {
          if (remainingToDeduct >= remainingCapacity) {
            additionalConsumption = remainingCapacity;
            remainingToDeduct -= remainingCapacity;
            remainingCapacity = 0;
          } else {
            additionalConsumption = remainingToDeduct;
            remainingCapacity -= remainingToDeduct;
            remainingToDeduct = 0;
          }
        }

        if (remainingEstimatedToDeduct > 0 && remainingCapacity > 0) {
          if (remainingEstimatedToDeduct >= remainingCapacity) {
            additionalEstimation = remainingCapacity;
            remainingEstimatedToDeduct -= remainingCapacity;
          } else {
            additionalEstimation = remainingEstimatedToDeduct;
            remainingEstimatedToDeduct = 0;
          }
        }

        double totalConsumed = consumedFromThis + additionalConsumption;
        double totalEstimated = estimatedFromThis + additionalEstimation;

        processed.add({
          ...chip,
          'available': totalQty - totalConsumed,
          'consumed': totalConsumed,
          'estimated': totalEstimated,
        });
      }

      setState(() {
        _contractedHours = totalAcquired;
        _totalConsumedHours = totalConsumedLinked;
        _inProgressHours = totalEstimatedLinked;
        _processedChips = processed;
      });
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
                trailing: current == AdminViewMode.mixed
                    ? Icon(Icons.check, color: colorScheme.primary)
                    : null,
                onTap: () {
                  _adminViewModeManager.saveMode(AdminViewMode.mixed);
                  Navigator.pop(dialogContext);
                },
              ),
              ListTile(
                title: const Text('Modo Soporte'),
                trailing: current == AdminViewMode.support
                    ? Icon(Icons.check, color: colorScheme.primary)
                    : null,
                onTap: () {
                  _adminViewModeManager.saveMode(AdminViewMode.support);
                  Navigator.pop(dialogContext);
                },
              ),
              ListTile(
                title: const Text('Modo Proyecto'),
                trailing: current == AdminViewMode.project
                    ? Icon(Icons.check, color: colorScheme.primary)
                    : null,
                onTap: () {
                  _adminViewModeManager.saveMode(AdminViewMode.project);
                  Navigator.pop(dialogContext);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
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
            Text(
              _adminViewModeManager.currentMode == AdminViewMode.support
                  ? 'Modo Soporte'
                  : (_adminViewModeManager.currentMode == AdminViewMode.project
                        ? 'Modo Proyecto'
                        : 'Modo Mixto'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
      itemBuilder: (BuildContext context) {
        final current = _adminViewModeManager.currentMode;
        final colorScheme = Theme.of(context).colorScheme;
        PopupMenuItem<AdminViewMode> buildItem(
          AdminViewMode mode,
          String text,
        ) {
          final isSelected = current == mode;
          return PopupMenuItem<AdminViewMode>(
            value: mode,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                    ),
                  ),
                  if (isSelected) const Spacer(),
                  if (isSelected)
                    Icon(
                      Icons.check,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                ],
              ),
            ),
          );
        }

        return [
          buildItem(AdminViewMode.mixed, 'Modo Mixto'),
          buildItem(AdminViewMode.support, 'Modo Soporte'),
          buildItem(AdminViewMode.project, 'Modo Proyecto'),
        ];
      },
    );
  }

  Widget _buildExceptionInkWell() {
    return InkWell(
      onTap: _showExceptionDialog,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined),
            SizedBox(width: 8),
            Text(
              'Excepción de Horas',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
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
            if (value == 'exception_hours') _showExceptionDialog();
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'admin_mode',
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: Text(
                  'Modo: ${_adminViewModeManager.currentMode == AdminViewMode.support ? 'Soporte' : (_adminViewModeManager.currentMode == AdminViewMode.project ? 'Proyecto' : 'Mixto')}',
                ),
              ),
            ),
            PopupMenuItem<String>(
              value: 'exception_hours',
              child: const ListTile(
                leading: Icon(Icons.shield_outlined),
                title: Text('Excepción de Horas'),
              ),
            ),
          ],
        ),
      ];
    }
    return [
      _buildAdminModePopupMenu(),
      _buildExceptionInkWell(),
    ];
  }

  Future<void> _showExceptionDialog() async {
    if (!AccessControl.isAdmin) return;

    final Set<int> tempSelectedIds = Set.from(
      ValidationManager.hourValidationExceptions,
    );
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
                      // Aplicar el mismo filtro de clientes activos y no proveedores
                      allBPartners = bps.where((bp) {
                        final name = bp['Name']?.toString() ?? '';
                        final rawVendor = bp['IsVendor'] ?? bp['isVendor'];
                        final isVendorStr = rawVendor
                            ?.toString()
                            .trim()
                            .toLowerCase();
                        bool isVendor =
                            isVendorStr == 'true' || isVendorStr == 'y';

                        final rawCustomer =
                            bp['IsCustomer'] ?? bp['isCustomer'];
                        final isCustomerStr = rawCustomer
                            ?.toString()
                            .trim()
                            .toLowerCase();
                        bool isCustomer =
                            isCustomerStr == 'true' || isCustomerStr == 'y';
                        if (rawCustomer == null) isCustomer = true;
                        return !name.startsWith('~') && isCustomer && !isVendor;
                      }).toList();

                      isFetching = false;
                    });
                  }
                });
              }

              final filteredBps = allBPartners
                  .where(
                    (bp) => (bp['Name'] ?? '')
                        .toString()
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase()),
                  )
                  .toList();

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
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onChanged: (val) =>
                                setState(() => searchQuery = val),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: filteredBps.isEmpty
                                ? const Center(
                                    child: Text('No se encontraron terceros.'),
                                  )
                                : ListView.builder(
                                    itemCount: filteredBps.length,
                                    itemBuilder: (context, index) {
                                      final bp = filteredBps[index];
                                      final rawId =
                                          bp['id'] ?? bp['C_BPartner_ID'];
                                      final intId = rawId is int
                                          ? rawId
                                          : int.tryParse(rawId.toString()) ?? 0;
                                      return CheckboxListTile(
                                        title: Text(
                                          bp['Name'] ?? 'Tercero $intId',
                                        ),
                                        value: tempSelectedIds.contains(intId),
                                        onChanged: (bool? value) => setState(
                                          () => value == true
                                              ? tempSelectedIds.add(intId)
                                              : tempSelectedIds.remove(intId),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            CustomButton(
              text: 'Guardar',
              onPressed: () {
                ValidationManager.setExceptions(tempSelectedIds);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> _getFilteredRecords() {
    var filtered = _supportRecords.where((record) {
      if (_searchController.text.isNotEmpty) {
        final search = _searchController.text.toLowerCase();
        final matchId =
            record['id']?.toString().toLowerCase().contains(search) ?? false;
        final matchDesc =
            record['description']?.toString().toLowerCase().contains(search) ??
            false;

        if (!matchId && !matchDesc) {
          return false;
        }
      }

      if (_selectedSummaryChipId != null) {
        final chipId = record['productChipId'];
        if (chipId != _selectedSummaryChipId) {
          return false;
        }
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      final hasChipA = (a['productChipId'] != null) ? 1 : 0;
      final hasChipB = (b['productChipId'] != null) ? 1 : 0;

      if (hasChipA != hasChipB) {
        return hasChipB.compareTo(hasChipA);
      }

      final timeA = a['time'] ?? '';
      final timeB = b['time'] ?? '';
      return _isAscending ? timeA.compareTo(timeB) : timeB.compareTo(timeA);
    });

    return filtered;
  }

  Future<void> _showYearFilterModal() async {
    final List<int> availableYears = List.generate(
      10,
      (i) => DateTime.now().year - i,
    );
    final List<int>? result = await showDialog<List<int>>(
      context: context,
      builder: (context) {
        List<int> tempSelection = List.from(_selectedYears);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CustomModal(
              title: 'Seleccionar Años',
              content: SizedBox(
                height: 300,
                child: ListView(
                  children: [
                    CheckboxListTile(
                      title: const Text('Todos los Años'),
                      value: tempSelection.isEmpty,
                      onChanged: (v) =>
                          setDialogState(() => tempSelection.clear()),
                    ),
                    const Divider(),
                    ...availableYears.map((year) {
                      return CheckboxListTile(
                        title: Text(year.toString()),
                        value: tempSelection.contains(year),
                        onChanged: (bool? selected) {
                          setDialogState(() {
                            if (selected == true) tempSelection.add(year);
                            if (selected == false) tempSelection.remove(year);
                          });
                        },
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancelar'),
                ),
                CustomButton(
                  text: 'Aplicar',
                  onPressed: () => Navigator.pop(context, tempSelection),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;
    setState(() {
      _selectedYears = result..sort((a, b) => b.compareTo(a));
      _currentPage = 0;
    });
    _refreshData();
  }

  Future<void> _showBPartnerFilterModal() async {
    if (!AccessControl.isAdmin) return;

    final selectedId = await showDialog<int?>(
      context: context,
      builder: (context) {
        String searchQuery = '';
        List<dynamic> items = [
          {'id': null, 'Name': 'Todos los Terceros'},
          ..._bPartners,
        ];

        return CustomModal(
          title: 'Filtrar por Tercero',
          width: 500,
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              final filteredItems = items.where((item) {
                return (item['Name'] as String).toLowerCase().contains(
                  searchQuery.toLowerCase(),
                );
              }).toList();

              return SizedBox(
                height: 400,
                child: Column(
                  children: [
                    CustomTextField(
                      hintText: 'Buscar tercero...',
                      prefixIcon: const Icon(Icons.search),
                      onChanged: (val) =>
                          setModalState(() => searchQuery = val),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final int? itemValue = item['id'];
                          return ListTile(
                            title: Text(item['Name']),
                            selected: itemValue == _selectedBpId,
                            onTap: () => Navigator.of(context).pop(itemValue),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(_selectedBpId),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );

    if (selectedId != _selectedBpId) {
      setState(() {
        _selectedBpId = selectedId;
      });
      await _initData(); // Re-inicializar todos los datos para el nuevo tercero
    }
  }

  Widget _buildSmallStat(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final filteredRecords = _getFilteredRecords();
    final int totalItems = filteredRecords.length;
    final int totalPages = (totalItems / _rowsPerPage).ceil();
    if (_currentPage >= totalPages)
      _currentPage = totalPages > 0 ? totalPages - 1 : 0;
    final int startIndex = _currentPage * _rowsPerPage;
    final int endIndex = (startIndex + _rowsPerPage < totalItems)
        ? startIndex + _rowsPerPage
        : totalItems;
    final paginatedRecords = totalItems > 0
        ? filteredRecords.sublist(startIndex, endIndex)
        : <Map<String, dynamic>>[];

    return Scaffold(
      appBar: AppBar(
        leadingWidth: !AccessControl.isAdmin ? 180 : null,
        leading: !AccessControl.isAdmin
            ? const UserInfoLeading()
            : Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  tooltip: 'Menú Principal',
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
        title: const Text('Dashboard De Horas De Soporte'),
        actions: [
          if (AccessControl.isAdmin) ..._buildAdminAppBarActions(context),
          const HelpIcon(),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: () {
              GlobalCache.performSmartSync(context, _refreshData);
            },
          ),
          if (!AccessControl.isAdmin)
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.red),
              tooltip: 'Cerrar Sesión',
              onPressed: () => showLogoutConfirmation(context),
            ),
        ],
      ),
      drawer: AccessControl.isAdmin
          ? const CustomDrawer(currentRoute: '/support')
          : null,
      bottomNavigationBar:
          (MediaQuery.of(context).size.width < 900 && !AccessControl.isAdmin)
          ? const ProjectBottomNav(currentRoute: '/support')
          : null,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (MediaQuery.of(context).size.width >= 900 &&
              !AccessControl.isAdmin)
            const ProjectSideBar(currentRoute: '/support'),
          Expanded(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (AccessControl.isAdmin)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              InkWell(
                                onTap:
                                    (_bPartners.isEmpty || !GlobalCache.isDataLoaded || _isLoadingBPartners)
                                    ? null
                                    : _showBPartnerFilterModal,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withOpacity(
                                          (_bPartners.isEmpty ||
                                                  !GlobalCache.isDataLoaded ||
                                                  _isLoadingBPartners)
                                              ? 0.15
                                              : 0.35,
                                        ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outline.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.business_outlined,
                                        color:
                                            (_bPartners.isEmpty ||
                                                !GlobalCache.isDataLoaded ||
                                                _isLoadingBPartners)
                                            ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                                            : Theme.of(context).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Tercero a Consultar',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.onSurfaceVariant,
                                                  ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    !GlobalCache.isDataLoaded
                                                        ? 'Sincronizando información...'
                                                        : (_isLoadingBPartners
                                                            ? 'Cargando terceros...'
                                                            : (_selectedBpId == null
                                                                  ? 'Selecciona un tercero para ver sus fichas'
                                                                  : (_bPartners.firstWhere(
                                                                          (bp) =>
                                                                              bp['id'] ==
                                                                              _selectedBpId,
                                                                          orElse: () => {
                                                                            'Name':
                                                                                'Tercero Seleccionado',
                                                                          },
                                                                        )['Name'] ??
                                                                        'Tercero $_selectedBpId'))),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyLarge
                                                        ?.copyWith(
                                                          fontWeight: FontWeight.w500,
                                                          color:
                                                              (!GlobalCache.isDataLoaded || _isLoadingBPartners)
                                                              ? Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5)
                                                              : null,
                                                        ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (GlobalCache.isDataLoaded && !_isLoadingBPartners)
                                        Icon(
                                          Icons.search,
                                          color: (_bPartners.isEmpty)
                                              ? Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5)
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                        )
                                      else
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_isLoadingBPartners || !GlobalCache.isDataLoaded)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: SizedBox(
                                    height: 3,
                                    child: LinearProgressIndicator(
                                      backgroundColor: Colors.transparent,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    // --- NUEVA TARJETA DE RESUMEN PREMIUM ---
                    Builder(
                      builder: (context) {
                        double contracted = _contractedHours ?? 0.0;
                        double consumed = _totalConsumedHours;
                        double inProgress = _inProgressHours;
                        double available = contracted - consumed;

                        if (_selectedSummaryChipId != null) {
                          final chip = _processedChips.firstWhere(
                            (c) => c['id'] == _selectedSummaryChipId,
                            orElse: () => {},
                          );
                          if (chip.isNotEmpty) {
                            contracted =
                                (chip['Qty'] as num?)?.toDouble() ?? 0.0;
                            consumed =
                                (chip['consumed'] as num?)?.toDouble() ?? 0.0;
                            inProgress =
                                (chip['estimated'] as num?)?.toDouble() ?? 0.0;
                            available =
                                (chip['available'] as num?)?.toDouble() ?? 0.0;
                          }
                        } else {
                          available = contracted - consumed - inProgress;
                        }

                        return SupportSummaryPremium(
                          contractedHours: contracted,
                          consumedHours: consumed,
                          inProgressHours: inProgress,
                          availableHours: available,
                          processedChips: _processedChips,
                          selectedChipId: _selectedSummaryChipId,
                          isLoading: _isLoading,
                          onChipTap: (id) {
                            setState(() {
                              if (_selectedSummaryChipId == id) {
                                _selectedSummaryChipId = null;
                              } else {
                                _selectedSummaryChipId = id;
                              }
                            });
                          },
                          onRefresh: () => _initData(),
                          allowRename: true,
                          emptyMessage:
                              AccessControl.isAdmin && _selectedBpId == null
                              ? '(Como administrador) seleccione un tercero para ver sus fichas de producto'
                              : null,
                          attachmentAction: (_selectedBpId != null || (!AccessControl.isAdmin && User.cBPartnerID != null))
                              ? IconButton(
                                  icon: const Icon(Icons.attach_file),
                                  tooltip: 'Adjuntos del Tercero',
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (context) => BPartnerAttachmentsDialog(bPartnerId: _selectedBpId ?? User.cBPartnerID!),
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                    CustomContainer(
                      title: 'Registro de Horas Consumidas',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SupportDashboardFilterBar(
                            searchController: _searchController,
                            isAscending: _isAscending,
                            rowsPerPage: _rowsPerPage,
                            selectedYears: _selectedYears,
                            onShowYearFilter: _showYearFilterModal,
                            onSortChanged: () => setState(() {
                              _isAscending = !_isAscending;
                              _currentPage = 0;
                            }),
                            onRowsPerPageChanged: (val) => setState(() {
                              _rowsPerPage = val!;
                              _currentPage = 0;
                            }),
                            onClearFilters: () => setState(() {
                              _searchController.clear();
                              _isAscending = false;
                              _currentPage = 0;
                              _selectedYears = [DateTime.now().year];
                              if (AccessControl.isAdmin) _selectedBpId = null;
                              _refreshData();
                            }),
                            onShowBPartnerFilter: _showBPartnerFilterModal,
                            activeFilterCount: _activeFilterCount,
                            selectedBpId: _selectedBpId,
                          ),
                          // CONTROLES DE PAGINACIÓN (ARRIBA)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${totalItems == 0 ? 0 : (_currentPage * _rowsPerPage) + 1} - ${((_currentPage + 1) * _rowsPerPage < totalItems) ? (_currentPage + 1) * _rowsPerPage : totalItems} de $totalItems',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.chevron_left),
                                      onPressed: _currentPage > 0
                                          ? () => setState(() => _currentPage--)
                                          : null,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.chevron_right),
                                      onPressed: _currentPage < totalPages - 1
                                          ? () => setState(() => _currentPage++)
                                          : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Divider(),
                          const SizedBox(height: 16),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _isLoading
                                ? const SkeletonTable()
                                : _supportRecords.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: Center(
                                      child: Text(
                                        'No hay registros de horas consumidas para este filtro.',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  )
                                : LayoutBuilder(
                                    builder: (context, constraints) {
                                      if (constraints.maxWidth < 800) {
                                        return _MobileRecordList(
                                          records: paginatedRecords,
                                          onRecordTap: (record) =>
                                              _showRequestDetails(
                                                context,
                                                record,
                                              ),
                                        );
                                      } else {
                                        return _DesktopRecordTable(
                                          records: paginatedRecords,
                                          onRecordTap: (record) =>
                                              _showRequestDetails(
                                                context,
                                                record,
                                              ),
                                        );
                                      }
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportDashboardFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final bool isAscending;
  final int rowsPerPage;
  final List<int> selectedYears;
  final VoidCallback onShowYearFilter;
  final VoidCallback onSortChanged;
  final Function(int?) onRowsPerPageChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onShowBPartnerFilter;
  final int activeFilterCount;
  final int? selectedBpId;

  const _SupportDashboardFilterBar({
    super.key,
    required this.searchController,
    required this.isAscending,
    required this.rowsPerPage,
    required this.selectedYears,
    required this.onShowYearFilter,
    required this.onSortChanged,
    required this.onRowsPerPageChanged,
    required this.onClearFilters,
    required this.onShowBPartnerFilter,
    required this.activeFilterCount,
    this.selectedBpId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 400,
          child: CustomTextField(
            controller: searchController,
            hintText: 'Buscar por ticket o actividad...',
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16.0,
          runSpacing: 8.0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Eliminado el botón de "Filtros" (BPartner) para administradores ya que existe el selector global superior.
            if (!AccessControl.isSupport)
              ActionChip(
                avatar: const Icon(Icons.calendar_today, size: 16),
                label: Text(() {
                  if (selectedYears.isEmpty) return 'Año: Todos';
                  if (selectedYears.length == 1) {
                    if (selectedYears.first == DateTime.now().year)
                      return 'Año: Actual';
                    return 'Año: ${selectedYears.first}';
                  }
                  return 'Años: ${selectedYears.length}';
                }()),
                onPressed: onShowYearFilter,
              ),
            ActionChip(
              avatar: Icon(
                isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
              ),
              label: Text(isAscending ? 'Más antiguas' : 'Más recientes'),
              onPressed: onSortChanged,
            ),
            DropdownButton<int>(
              value: rowsPerPage,
              items: [10, 25, 50, 100]
                  .map(
                    (int value) => DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value filas'),
                    ),
                  )
                  .toList(),
              onChanged: onRowsPerPageChanged,
            ),
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              onPressed: onClearFilters,
              tooltip: 'Limpiar filtros',
            ),
          ],
        ),
      ],
    );
  }
}

void _showRequestDetails(BuildContext context, Map<String, dynamic> record) {
  final double h = (record['qtySpent'] as num?)?.toDouble() ?? 0.0;
  final qtyPlanController = TextEditingController(
    text: DurationFormatter.format(h),
  );

  showDialog(
    context: context,
    builder: (context) => CustomModal(
      title: 'Detalle del Ticket ${record['id']}',
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (AccessControl.isAdmin) ...[
              CustomTextField(
                controller: TextEditingController(
                  text: record['emailSubject'] ?? record['descriptionClean'],
                ),
                label: 'Asunto / Actividad',
                readOnly: true,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
            ],
            CustomTextField(
              controller: TextEditingController(
                text: record['dateStartPlan'] ?? '',
              ),
              label: 'Fecha de Cierre',
              readOnly: true,
              prefixIcon: const Icon(Icons.calendar_today),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: qtyPlanController,
              label: 'Horas Consumidas',
              readOnly: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

class _DesktopRecordTable extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final Function(Map<String, dynamic>) onRecordTap;

  const _DesktopRecordTable({required this.records, required this.onRecordTap});

  @override
  Widget build(BuildContext context) {
    return CustomTable(
      columns: [
        const DataColumn(label: Text('Ticket')),
        if (AccessControl.isAdmin) const DataColumn(label: Text('Asunto / Actividad')),
        const DataColumn(label: Text('Estado')),
        const DataColumn(label: Text('Horas Consumidas')),
        const DataColumn(label: Text('Ficha de Producto')),
      ],
      rows: records.map((record) {
        final double h = (record['qtySpent'] as num?)?.toDouble() ?? 0.0;
        final hours = DurationFormatter.format(h);
        return DataRow(
          onSelectChanged: (value) => onRecordTap(record),
          cells: [
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(record['id']?.toString() ?? ''),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(text: record['id']?.toString() ?? ''),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Código copiado al portapapeles'),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.copy, size: 16, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            if (AccessControl.isAdmin)
              DataCell(
                Tooltip(
                  message: () {
                    final text =
                        record['emailSubject'] ??
                        record['descriptionClean'] ??
                        '';
                    return text.length > 2000
                        ? '${text.substring(0, 2000)}...'
                        : text;
                  }(),
                  waitDuration: const Duration(milliseconds: 500),
                  child: SizedBox(
                    width: 300,
                    child: Text(
                      record['emailSubject'] ?? record['descriptionClean'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            DataCell(Text(record['status'] ?? '')),
            DataCell(
              Text(hours, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            DataCell(
              Text(() {
                final chipId = record['productChipId'];
                if (chipId == null) return 'N/A';
                final found = GlobalCache.productChips.firstWhere(
                  (c) => c['id'] == chipId,
                  orElse: () => {},
                );
                if (found.isEmpty) return '#$chipId';
                return found['Description'] ?? found['Name'] ?? '#$chipId';
              }()),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _MobileRecordList extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final Function(Map<String, dynamic>) onRecordTap;

  const _MobileRecordList({required this.records, required this.onRecordTap});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return _SupportRecordCard(
          record: record,
          onTap: () => onRecordTap(record),
        );
      },
    );
  }
}

class _SupportRecordCard extends StatelessWidget {
  final Map<String, dynamic> record;
  final VoidCallback onTap;

  const _SupportRecordCard({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final double h = (record['qtySpent'] as num?)?.toDouble() ?? 0.0;
    final hours = DurationFormatter.format(h);
    final subject =
        record['emailSubject'] ??
        record['descriptionClean'] ??
        'Sin descripción';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ticket #${record['id']}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              if (AccessControl.isAdmin) ...[
                const SizedBox(height: 8),
                Text(
                  subject,
                  style: theme.textTheme.bodyLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    record['status'] ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Chip(
                    label: Text(hours),
                    avatar: Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: colorScheme.secondary,
                    ),
                    backgroundColor: colorScheme.secondaryContainer.withOpacity(
                      0.5,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BPartnerAttachmentsDialog extends StatefulWidget {
  final int bPartnerId;

  const BPartnerAttachmentsDialog({super.key, required this.bPartnerId});

  @override
  State<BPartnerAttachmentsDialog> createState() => _BPartnerAttachmentsDialogState();
}

class _BPartnerAttachmentsDialogState extends State<BPartnerAttachmentsDialog> {
  List<Map<String, dynamic>> _attachments = [];
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadAttachments();
  }

  Future<void> _loadAttachments() async {
    setState(() => _isLoading = true);
    const tableName = 'C_BPartner';
    final String fullTableUrl = '${Endpoint.baseUrl}/api/v1/models/$tableName';
    final attachments = await fetchAttachments(recordID: widget.bPartnerId, tableName: fullTableUrl);
    if (mounted) {
      setState(() {
        _attachments = attachments;
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadAttachment() async {
    if (!AccessControl.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tienes permisos para subir archivos.')));
      return;
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudieron leer los datos del archivo.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isUploading = true);

    const tableName = 'C_BPartner';
    final String fullTableUrl = '${Endpoint.baseUrl}/api/v1/models/$tableName';
    
    final convertedFile = {'title': file.name, 'base64': base64Encode(file.bytes!)};
    
    final success = await postAttachments(
      recordID: widget.bPartnerId, 
      tableName: fullTableUrl, 
      convertedFile: convertedFile,
      shouldUpdateStatus: false,
    );

    if (mounted) {
      setState(() => _isUploading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archivo subido correctamente'), backgroundColor: Colors.green));
        _loadAttachments();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al subir archivo'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const tableName = 'C_BPartner';
    final String fullTableUrl = '${Endpoint.baseUrl}/api/v1/models/$tableName';

    return CustomModal(
      title: 'Adjuntos del Tercero',
      width: 500,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_attachments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: Text('No hay archivos adjuntos para este tercero.')),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              itemCount: _attachments.length,
              itemBuilder: (context, index) {
                final att = _attachments[index];
                return ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: Text(att['name'] ?? 'Sin nombre'),
                  onTap: () {
                    FilePreviewManager.showPreview(context, {'id': widget.bPartnerId, 'Status': 'N/A', 'VersionNo': 'N/A'}, fullTableUrl, att['name'] ?? '', () async {
                      if (!AccessControl.isAdmin) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tienes permisos para borrar adjuntos.')));
                        return;
                      }

                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => CustomModal(
                          title: 'Eliminar Archivo',
                          content: Text('¿Estás seguro de que deseas eliminar "${att['name'] ?? ''}"?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                            CustomButton(text: 'Eliminar', backgroundColor: Colors.red, onPressed: () => Navigator.pop(ctx, true)),
                          ],
                        ),
                      );

                      if (confirm != true) return;

                      try {
                        setState(() => _isLoading = true);
                        final url = Uri.parse('$fullTableUrl/${widget.bPartnerId}/attachments/${Uri.encodeComponent(att['name'] ?? '')}');
                        final response = await http.delete(url, headers: {'Authorization': Token.token});
                        if (response.statusCode == 200 || response.statusCode == 204) {
                          if (mounted) {
                            setState(() {
                              _attachments.removeWhere((item) => item['name'] == att['name']);
                              _isLoading = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adjunto eliminado')));
                            // _loadAttachments(); // Removed to avoid stale cache issues
                          }
                        } else {
                          if (mounted) {
                            setState(() => _isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al eliminar adjunto'), backgroundColor: Colors.red));
                          }
                        }
                      } catch (e) {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    }, () {}, canDelete: AccessControl.isAdmin);
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.download, color: Color(0xFF4F47E5)),
                    tooltip: 'Descargar',
                    onPressed: () => downloadAttachment(context: context, recordID: widget.bPartnerId, tableName: fullTableUrl, fileName: att['name']),
                  ),
                );
              },
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        if (AccessControl.isAdmin) CustomButton(text: 'Subir Archivo', icon: Icons.upload_file, isLoading: _isUploading, onPressed: _uploadAttachment),
      ],
    );
  }
}
