import 'dart:async';
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
import 'package:primhub/ui/Shared_Custom/customToast.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import '../../../widgets/custom_drawer.dart';
import 'package:primhub/ui/pages/Home/Home_Controller/home_controller.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/api/global_cache.dart';
import 'package:primhub/ui/widgets/project_bottom_nav.dart';
import 'package:primhub/api/api_utils.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:primhub/ui/Shared_Custom/custom_skeleton.dart';
import 'package:primhub/ui/Shared_Custom/user_info_leading.dart';

/// Enum para identificar los tipos de filtro activos.
enum ActiveFilterType { year, bp, level, status, situation, salesRep, user, search }

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
  int? _selectedYear; // Cambiado a null para que por defecto muestre "Todos los Años"
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
  Timer? _skeletonTimer;
  bool _forceShowContent = false;
  bool _isHistorySkeletonActive = false;

  bool _showCalendar = false; // Nuevo estado para controlar la vista del calendario
  Timer? _historySkeletonTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _currentPage = 0));
    _adminViewModeManager.addListener(_onViewModeChanged);
    GlobalCache.backgroundSyncNotifier.addListener(_onBackgroundSyncChanged);
  }

  void _onBackgroundSyncChanged() {
    if (!GlobalCache.backgroundSyncNotifier.value && mounted) {
      _refreshRequest(fetchNetwork: false);
    }
  }

  void _onViewModeChanged() {
    _initData();
  }

  void _startHistorySkeleton() {
    _isHistorySkeletonActive = true;
    _historySkeletonTimer?.cancel();
    _historySkeletonTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _isHistorySkeletonActive = false);
    });
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

      // Ajustar filas por página para móvil por defecto
      final isMobile = MediaQuery.of(context).size.width < 800;
      if (isMobile) {
        _rowsPerPage = 10;
      }

      if (_showHistory) _startHistorySkeleton();

      _isInit = false;
      _initData();
    }
  }

  @override
  void dispose() {
    _historySkeletonTimer?.cancel();
    _skeletonTimer?.cancel();
    _searchController.dispose();
    _adminViewModeManager.removeListener(_onViewModeChanged);
    GlobalCache.backgroundSyncNotifier.removeListener(_onBackgroundSyncChanged);
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() {
      _isLoading = true;
    });

    await GlobalCache.syncData();

    if (AccessControl.isAdmin) {
      // Ya viene filtrada y unificada directamente desde GlobalCache
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

  int get _activeFilterCount {
    // Calcula el número de filtros activos para mostrar en el botón "Filtros".
    int count = 0;
    if (_selectedYear != null) count++;
    if (_selectedBP != null) count++;
    if (_selectedLevel != null) count++;
    if (_selectedStatus != null) count++;
    if (_selectedSituation != null) count++;
    if (_selectedSalesRep != null) count++;
    if (_selectedUser != null) count++;
    return count;
  }

  /// Construye y devuelve una lista de chips que representan los filtros activos.
  Widget _buildActiveFilterChips() {
    final List<Widget> chips = [];
    final theme = Theme.of(context);

    void addChip(String label, ActiveFilterType type) {
      chips.add(
        InputChip(
          label: Text(label),
          onDeleted: () => _removeFilter(type),
          deleteButtonTooltipMessage: 'Quitar',
          deleteIcon: const Icon(Icons.close, size: 18),
          labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
        ),
      );
    }

    if (_selectedYear != null) {
      addChip('Año: $_selectedYear', ActiveFilterType.year);
    }
    if (_selectedBP != null) {
      addChip('Tercero: $_selectedBP', ActiveFilterType.bp);
    }
    if (_selectedLevel != null) {
      addChip('Nivel: $_selectedLevel', ActiveFilterType.level);
    }
    if (_selectedStatus != null) {
      addChip('Estado: $_selectedStatus', ActiveFilterType.status);
    }
    if (_selectedSituation != null) {
      addChip('Tipo: $_selectedSituation', ActiveFilterType.situation);
    }
    if (_selectedSalesRep != null) {
      addChip('Rep. Comercial: $_selectedSalesRep', ActiveFilterType.salesRep);
    }
    if (_selectedUser != null) {
      addChip('Usuario: $_selectedUser', ActiveFilterType.user);
    }
    if (_searchController.text.isNotEmpty) {
      addChip('Buscar: "${_searchController.text}"', ActiveFilterType.search);
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Wrap(spacing: 8.0, runSpacing: 8.0, children: chips),
    );
  }

  /// Elimina un filtro específico y actualiza la UI.
  void _removeFilter(ActiveFilterType type) {
    setState(() {
      switch (type) {
        case ActiveFilterType.year:
          _selectedYear = null;
          break;
        case ActiveFilterType.bp:
          _selectedBP = null;
          _bpId = null; // También limpia el ID del tercero
          break;
        case ActiveFilterType.level:
          _selectedLevel = null;
          break;
        case ActiveFilterType.status:
          _selectedStatus = null;
          break;
        case ActiveFilterType.situation:
          _selectedSituation = null;
          break;
        case ActiveFilterType.salesRep:
          _selectedSalesRep = null;
          break;
        case ActiveFilterType.user:
          _selectedUser = null;
          break;
        case ActiveFilterType.search:
          _searchController.clear();
          break;
      }
      _currentPage = 0; // Reinicia la paginación
    });
    // Si se cambió el tercero, necesitamos reinicializar los datos para obtener los contratos correctos.
    // De lo contrario, solo actualizamos las estadísticas localmente.
    if (type == ActiveFilterType.bp) {
      _initData();
    } else {
      _updateStatsLocally();
    }
  }

  Future<void> _openSearchModal<T>({required String title, required List<dynamic> items, required T? currentValue, required String Function(dynamic) getTitle, String Function(dynamic)? getSubtitle, required T? Function(dynamic) getValue, required void Function(T?) onSelected}) async {
    final dynamic result = await showDialog(
      context: context,
      builder: (context) {
        String searchQuery = '';
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Container(
            width: 400,
            height: MediaQuery.of(context).size.height * 0.6,
            padding: const EdgeInsets.all(20),
            child: StatefulBuilder(
              builder: (context, setStateDialog) {
                final filteredItems = items.where((item) {
                  return getTitle(item).toLowerCase().contains(searchQuery.toLowerCase());
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Seleccionar $title', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400)),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.filter_list, color: Colors.grey),
                        hintText: 'Filtrar...',
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
                      ),
                      onChanged: (val) => setStateDialog(() => searchQuery = val),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filteredItems.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.grey, thickness: 0.3),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final itemValue = getValue(item);
                          final isSelected = itemValue == currentValue;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            tileColor: isSelected ? Colors.grey.withOpacity(0.1) : null,
                            title: Text(getTitle(item), style: const TextStyle(fontSize: 14)),
                            subtitle: getSubtitle != null && itemValue != null ? Text(getSubtitle(item), style: const TextStyle(fontSize: 12, color: Colors.grey)) : null,
                            onTap: () => Navigator.of(context).pop({'selected': true, 'value': itemValue}),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    if (result != null && result is Map && result['selected'] == true) {
      onSelected(result['value'] as T?);
    }
  }

  Widget _buildSearchableField<T>({required String label, required String? hintText, required T? value, required bool isLoading, required bool isDisabled, required String displayText, required VoidCallback onTap}) {
    return InkWell(
      onTap: (isLoading || isDisabled) ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          suffixIcon: isLoading ? Transform.scale(scale: 0.5, child: const CircularProgressIndicator(strokeWidth: 3)) : const Icon(Icons.search),
        ),
        isEmpty: value == null && (displayText.isEmpty || displayText.startsWith('Todos los')),
        child: Text(
          (value == null || displayText.isEmpty) ? (hintText ?? '') : displayText,
          style: TextStyle(fontSize: 16, color: (isLoading || isDisabled || value == null) ? Colors.grey[600] : Theme.of(context).colorScheme.onSurface),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Future<void> _showFilterModal() async {
    int? tempSelectedYear = _selectedYear;
    String? tempSelectedBP = _selectedBP;
    String? tempSelectedLevel = _selectedLevel;
    String? tempSelectedStatus = _selectedStatus;
    String? tempSelectedSituation = _selectedSituation;
    String? tempSelectedSalesRep = _selectedSalesRep;
    String? tempSelectedUser = _selectedUser;

    final originalBP = _selectedBP;

    final applied = await showDialog<bool>(
      context: context,
      builder: (context) {
        // --- Modal-specific state ---
        List<dynamic> modalUsers = _users;

        // Pre-filter users if a BP is already selected
        if (tempSelectedBP != null) {
          final bpData = _bPartners.firstWhere((bp) => bp['Name'] == tempSelectedBP, orElse: () => {});
          if (bpData.isNotEmpty) {
            final bpId = bpData['id'];
            modalUsers = _users.where((u) {
              final userBpData = u['C_BPartner_ID'];
              return userBpData is Map && userBpData['id'] == bpId;
            }).toList();
          }
        }

        return StatefulBuilder(
          builder: (context, setStateModal) {
            // 1. Calcular dinámicamente los usuarios válidos CADA VEZ que cambia el modal
            List<dynamic> modalUsers = _users;
            if (tempSelectedBP != null && tempSelectedBP != '__ALL__') {
              final bpData = _bPartners.firstWhere((bp) => bp['Name'] == tempSelectedBP, orElse: () => {});
              if (bpData.isNotEmpty) {
                final bpId = bpData['id'];
                modalUsers = _users.where((u) {
                  final userBpData = u['C_BPartner_ID'];
                  // Validación robusta: extrae el ID sea un Map o sea un entero directo
                  final uBpId = (userBpData is Map) ? userBpData['id'] : userBpData;
                  return uBpId == bpId;
                }).toList();
              }
            }
            return CustomModal(
              title: 'Filtrar Solicitudes',
              width: 500,
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchableField<int>(
                      label: 'Año',
                      hintText: 'Todos los Años',
                      value: tempSelectedYear,
                      isLoading: false,
                      isDisabled: false,
                      displayText: tempSelectedYear?.toString() ?? 'Todos los Años',
                      onTap: () => _openSearchModal<int>(title: 'Año', items: ['__ALL__', ...List.generate(10, (index) => (DateTime.now().year - 3) + index)], currentValue: tempSelectedYear, getTitle: (item) => item == '__ALL__' ? 'Todos los Años' : item.toString(), getValue: (item) => item == '__ALL__' ? null : item as int, onSelected: (val) => setStateModal(() => tempSelectedYear = val)),
                    ),
                    const SizedBox(height: 16),
                    if (AccessControl.isAdmin) ...[
                      _buildSearchableField<String>(
                        label: 'Tercero',
                        hintText: 'Todos los Terceros',
                        value: tempSelectedBP,
                        isLoading: false,
                        isDisabled: false,
                        displayText: tempSelectedBP ?? 'Todos los Terceros',
                        onTap: () async {
                          await _openSearchModal<String>(
                            title: 'Tercero',
                            items: [
                              '__ALL__',
                              ...{
                                for (var bp in _bPartners)
                                  if (bp['id'] != null) bp['id']: bp,
                              }.values,
                            ],
                            currentValue: tempSelectedBP,
                            getTitle: (item) => item == '__ALL__' ? 'Todos los Terceros' : (item['Name'] ?? 'Sin Nombre'),
                            getSubtitle: (item) => item == '__ALL__' ? '' : 'ID: ${item['id']}',
                            getValue: (item) => item == '__ALL__' ? null : item['Name']?.toString(),
                            onSelected: (val) {
                              setStateModal(() {
                                tempSelectedBP = val;
                                // Validación de Usuario vs Tercero
                                if (tempSelectedUser != null && val != null && val != '__ALL__') {
                                  final newBpData = _bPartners.firstWhere((bp) => bp['Name'] == val, orElse: () => <String, dynamic>{});
                                  if (newBpData.isNotEmpty) {
                                    final newBpId = newBpData['id'];
                                    final userRecord = _users.firstWhere((u) => u['Name'] == tempSelectedUser, orElse: () => <String, dynamic>{});

                                    if (userRecord.isNotEmpty) {
                                      final uBp = userRecord['C_BPartner_ID'];
                                      final uBpId = (uBp is Map) ? uBp['id'] : uBp;

                                      if (uBpId != newBpId) {
                                        tempSelectedUser = null; // Limpiamos al usuario
                                        WidgetsBinding.instance.addPostFrameCallback((_) => ToastMessage.show(context: context, message: 'El filtro de usuario se ha quitado, no pertenece a este tercero', type: ToastType.help));
                                      }
                                    }
                                  }
                                }
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildSearchableField<String>(
                        label: 'Rep. Comercial',
                        hintText: 'Todos los Rep. Comerciales',
                        value: tempSelectedSalesRep,
                        isLoading: false,
                        isDisabled: false,
                        displayText: tempSelectedSalesRep ?? 'Todos los Rep. Comerciales',
                        onTap: () => _openSearchModal<String>(
                          title: 'Rep. Comercial',
                          // Filtro técnico para Representantes Comerciales
                          items: ['__ALL__', ..._bPartners.where((bp) => bp['C_BPartner0IsSalesRep'] == 'Y' || bp['C_BPartner0IsSalesRep'] == true)],
                          currentValue: tempSelectedSalesRep,
                          getTitle: (item) => item == '__ALL__' ? 'Todos los Rep. Comerciales' : (item['Name'] ?? 'Sin Nombre'),
                          getSubtitle: (item) => item == '__ALL__' ? '' : 'ID: ${item['id']}',
                          getValue: (item) => item == '__ALL__' ? null : item['Name']?.toString(),
                          onSelected: (val) => setStateModal(() => tempSelectedSalesRep = val),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildSearchableField<String>(
                      label: 'Tipo de solicitud',
                      hintText: 'Todos los Tipos',
                      value: tempSelectedSituation,
                      isLoading: false,
                      isDisabled: false,
                      displayText: tempSelectedSituation ?? 'Todos los Tipos',
                      onTap: () => _openSearchModal<String>(
                        title: 'Tipo de solicitud',
                        items: ['__ALL__', ..._requests.map((e) => e['situation'].toString()).toSet()],
                        currentValue: tempSelectedSituation,
                        getTitle: (item) => item == '__ALL__' ? 'Todos los Tipos' : item.toString(),
                        getValue: (item) => item == '__ALL__' ? null : item.toString(),
                        onSelected: (val) => setStateModal(() => tempSelectedSituation = val),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSearchableField<String>(
                      label: 'Usuario',
                      hintText: 'Todos los Usuarios',
                      value: tempSelectedUser,
                      isLoading: false,
                      isDisabled: false,
                      displayText: tempSelectedUser ?? 'Todos los Usuarios',
                      onTap: () => _openSearchModal<String>(
                        title: 'Usuario',
                        // Se utiliza modalUsers definido en el StatefulBuilder
                        items: [
                          '__ALL__',
                          ...{
                            for (var u in modalUsers)
                              if ((u['AD_User_ID'] ?? u['id']) != null) (u['AD_User_ID'] ?? u['id']): u,
                          }.values,
                        ],
                        currentValue: tempSelectedUser,
                        getTitle: (item) => item == '__ALL__' ? 'Todos los Usuarios' : (item['Name'] ?? 'Sin Nombre'),
                        getSubtitle: (item) => item == '__ALL__' ? '' : 'ID: ${item['AD_User_ID'] ?? item['id']}',
                        getValue: (item) => item == '__ALL__' ? null : item['Name']?.toString(),
                        onSelected: (val) => setStateModal(() => tempSelectedUser = val),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSearchableField<String>(
                      label: 'Nivel',
                      hintText: 'Todos los Niveles',
                      value: tempSelectedLevel,
                      isLoading: false,
                      isDisabled: false,
                      displayText: tempSelectedLevel ?? 'Todos los Niveles',
                      onTap: () => _openSearchModal<String>(title: 'Nivel', items: ['__ALL__', 'Urgente', 'Alta', 'Media', 'Baja', 'Menor'], currentValue: tempSelectedLevel, getTitle: (item) => item == '__ALL__' ? 'Todos los Niveles' : item.toString(), getValue: (item) => item == '__ALL__' ? null : item.toString(), onSelected: (val) => setStateModal(() => tempSelectedLevel = val)),
                    ),
                    const SizedBox(height: 16),
                    _buildSearchableField<String>(
                      label: 'Estado',
                      hintText: 'Todos los Estados',
                      value: (_statusIdMap.isNotEmpty && tempSelectedStatus != null && !_statusIdMap.containsKey(tempSelectedStatus)) ? null : tempSelectedStatus,
                      isLoading: false,
                      isDisabled: false,
                      displayText: tempSelectedStatus ?? 'Todos los Estados',
                      onTap: () => _openSearchModal<String>(
                        title: 'Estado',
                        items: [
                          '__ALL__',
                          ...(_statusIdMap.isNotEmpty ? (_statusIdMap.keys.toList()..sort()) : ['1_Open', '2_Waiting on customer', '3_Closed']),
                        ],
                        currentValue: tempSelectedStatus,
                        getTitle: (item) => item == '__ALL__' ? 'Todos los Estados' : item.toString(),
                        getValue: (item) => item == '__ALL__' ? null : item.toString(),
                        onSelected: (val) => setStateModal(() => tempSelectedStatus = val),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                CustomButton(text: 'Aplicar Filtros', onPressed: () => Navigator.pop(context, true)),
              ],
            );
          },
        );
      },
    );

    if (applied == true) {
      setState(() {
        _selectedYear = tempSelectedYear;
        _selectedBP = tempSelectedBP;
        _selectedLevel = tempSelectedLevel;
        _selectedStatus = tempSelectedStatus;
        _selectedSituation = tempSelectedSituation;
        _selectedSalesRep = tempSelectedSalesRep;
        _selectedUser = tempSelectedUser;
        _currentPage = 0;
      });

      if (originalBP != _selectedBP) {
        setState(() => _isLoading = true);
        if (_selectedBP != null) {
          final found = _bPartners.firstWhere((bp) => bp['Name'] == _selectedBP, orElse: () => <String, dynamic>{});
          if (found.isNotEmpty) {
            _bpId = found['id'];
          }
        } else {
          _bpId = null;
        }
        _initData();
      } else {
        _updateStatsLocally();
      }
    }
  }

  /// Muestra un diálogo para seleccionar el modo de vista del administrador.
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
                trailing: current == AdminViewMode.mixed ? Icon(Icons.check, color: colorScheme.primary) : null,
                onTap: () {
                  _adminViewModeManager.saveMode(AdminViewMode.mixed);
                  Navigator.pop(dialogContext);
                },
              ),
              ListTile(
                title: const Text('Modo Soporte'),
                trailing: current == AdminViewMode.support ? Icon(Icons.check, color: colorScheme.primary) : null,
                onTap: () {
                  _adminViewModeManager.saveMode(AdminViewMode.support);
                  Navigator.pop(dialogContext);
                },
              ),
              ListTile(
                title: const Text('Modo Proyecto'),
                trailing: current == AdminViewMode.project ? Icon(Icons.check, color: colorScheme.primary) : null,
                onTap: () {
                  _adminViewModeManager.saveMode(AdminViewMode.project);
                  Navigator.pop(dialogContext);
                },
              ),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cerrar'))],
        );
      },
    );
  }

  /// Construye las acciones específicas de la AppBar para el administrador, adaptándose a móvil.
  List<Widget> _buildAdminAppBarActions(BuildContext context) {
    final List<Widget> actions = [];
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final colorScheme = Theme.of(context).colorScheme;

    if (isMobile) {
      actions.add(
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: 'Opciones de Administrador',
          onSelected: (value) {
            if (value == 'admin_mode') {
              _showAdminModeSelectionDialog(context);
            } else if (value == 'exception_dialog') {
              _showExceptionDialog();
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'admin_mode',
              child: ListTile(leading: const Icon(Icons.admin_panel_settings), title: Text('Modo de Vista (${_adminViewModeManager.currentMode == AdminViewMode.support ? 'Soporte' : (_adminViewModeManager.currentMode == AdminViewMode.project ? 'Proyecto' : 'Mixto')})')),
            ),
            PopupMenuItem<String>(
              value: 'exception_dialog',
              child: ListTile(leading: const Icon(Icons.shield_outlined), title: const Text('Excepción de Horas')),
            ),
          ],
        ),
      );
    } else {
      // Desktop view: existing buttons
      actions.add(_buildAdminModePopupMenu(context));
      actions.add(_buildExceptionHoursInkWell());
    }
    return actions;
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
        _isLoading = false;
      });
      _updateStatsLocally();
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
        if (r['status'] == '9_Final Close' || r['statusId'] == 103 || r['statusId'] == 1000019 || r['status'].toString().toLowerCase().contains('archivada')) {
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
        if (r['status'] == '9_Final Close' || r['statusId'] == 103 || r['statusId'] == 1000019 || r['status'].toString().toLowerCase().contains('archivada')) {
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
          CustomButton(text: 'Eliminar', backgroundColor: Theme.of(context).colorScheme.error, onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirm == true) {
      final success = await deleteRequestApi(id);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud eliminada correctamente')));
          _refreshRequest(fetchNetwork: false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al eliminar'), backgroundColor: Colors.red));
        }
      }
    }
  }

  void _editRequest(Map<String, dynamic> req) async {
    if (!AccessControl.canManageRequests) {
      // Mostrar solo lectura de los detalles para soporte
      showDialog(
        context: context,
        builder: (context) => CustomModal(
          title: 'Detalle de Solicitud ${req['id']}',
          width: 500,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomTextField(
                controller: TextEditingController(text: req['situation']),
                label: 'Tipo de Solicitud',
                readOnly: true,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: TextEditingController(text: req['emailSubject']),
                label: 'Asunto',
                readOnly: true,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: TextEditingController(text: req['category']),
                label: 'Categoría',
                readOnly: true,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: TextEditingController(text: req['level']),
                label: 'Nivel',
                readOnly: true,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: TextEditingController(text: req['status']),
                label: 'Estado',
                readOnly: true,
              ),
              const SizedBox(height: 16),
              Stack(
                alignment: Alignment.topRight,
                children: [
                  CustomTextField(
                    controller: TextEditingController(text: req['descriptionClean']),
                    label: 'Descripción',
                    maxLines: 4,
                    readOnly: true,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0, right: 4.0),
                    child: IconButton(
                      icon: const Icon(Icons.zoom_out_map),
                      tooltip: 'Ver descripción completa',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext dialogContext) => CustomModal(
                            title: 'Descripción Completa',
                            width: 600,
                            content: SizedBox(
                              height: 400,
                              child: SingleChildScrollView(
                                child: Html(
                                  data: req['description'] ?? '',
                                  style: {"body": Style(margin: Margins.zero, padding: HtmlPaddings.zero)},
                                ),
                              ),
                            ),
                            actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cerrar'))],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => EditRequestDialog(
        request: req,
        statusIdMap: _statusIdMap,
        priorityMap: priorityMap,
        onSave: () {
          _refreshRequest(fetchNetwork: false);
        },
        onDelete: () => _deleteRequest(req['realId']),
      ),
    );
  }

  /// Construye el PopupMenuButton para seleccionar el modo de vista del administrador.
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

  /// Construye el InkWell para mostrar el diálogo de excepciones de horas.
  List<Map<String, dynamic>> _getFilteredRequests() {
    return _requests.where((alert) {
      bool isClosed = alert['status'] == '9_Final Close' || alert['statusId'] == 103 || alert['statusId'] == 1000019 || alert['status'].toString().toLowerCase().contains('archivada');
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

  /// Widget para el PopupMenuButton de selección de modo de vista.
  Widget _buildAdminModePopupMenu(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
            Text(_adminViewModeManager.currentMode == AdminViewMode.support ? 'Modo Soporte' : (_adminViewModeManager.currentMode == AdminViewMode.project ? 'Modo Proyecto' : 'Modo Mixto'), style: const TextStyle(fontWeight: FontWeight.bold)),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
      itemBuilder: (BuildContext context) {
        final current = _adminViewModeManager.currentMode;
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
    );
  }

  /// Widget para el InkWell de "Excepción de Horas".
  Widget _buildExceptionHoursInkWell() {
    return InkWell(
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
    );
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

    final listContent = SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RequestStatsCard(contractedHours: _contractedHours, consumedHours: _consumedHours, estimatedHours: _estimatedHours),
          RequestFilterBar(
            searchController: _searchController,
            isAscending: _isAscending,
            rowsPerPage: _rowsPerPage,
            showHistory: _showHistory,
            onShowFilters: _showFilterModal,
            onShowCalendar: () => setState(() => _showCalendar = true), // Callback para mostrar el calendario
            activeFilterCount: _activeFilterCount,
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
                _selectedYear = null; // Limpiar también el filtro de año
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
                  true) {
                _refreshRequest(fetchNetwork: false);
              }
            },
            onToggleHistory: () => setState(() {
              _showHistory = !_showHistory;
              _selectedStatus = null;
              if (_showHistory) {
                _startHistorySkeleton();
              } else {
                _isHistorySkeletonActive = false;
                _historySkeletonTimer?.cancel();
              }
            }),
          ),
          const SizedBox(height: 20),
          _buildActiveFilterChips(), // Mostrar los chips de filtros activos
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text('$totalItems solicitudes encontradas', style: Theme.of(context).textTheme.titleMedium),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 1000),
            child: (_isLoading || (_showHistory && _isHistorySkeletonActive)) ? const SkeletonTable() : RequestsDataTable(requests: paginatedAlerts, onEdit: _editRequest, onRefresh: () => _refreshRequest(fetchNetwork: false)),
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
    );

    final appBarActions = [
      if (AccessControl.isAdmin) ..._buildAdminAppBarActions(context), // Acciones de admin adaptadas
      if (GlobalCache.backgroundSyncNotifier.value)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Center(
            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary)),
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: IconButton(
          onPressed: () => GlobalCache.performSmartSync(context, () async {
            await _initData();
          }),
          icon: const Icon(Icons.refresh),
          tooltip: 'Refrescar',
        ),
      ),
      if (!AccessControl.isAdmin)
        IconButton(
          icon: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
          tooltip: 'Cerrar Sesión',
          onPressed: () => showLogoutConfirmation(context),
        ),
    ];

    if (!AccessControl.isAdmin) {
      return Scaffold(
        appBar: AppBar(leadingWidth: 180, leading: const UserInfoLeading(), title: const Text('Mis Solicitudes De Soporte'), actions: appBarActions),
        bottomNavigationBar: const ProjectBottomNav(currentRoute: '/my-requests'),
        body: SafeArea(child: listContent),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_showCalendar ? 'Calendario de Solicitudes' : 'Mis Solicitudes De Soporte'),
        leading: _showCalendar ? IconButton(icon: const Icon(Icons.arrow_back), tooltip: 'Volver al Listado', onPressed: () => setState(() => _showCalendar = false)) : null,
        actions: appBarActions, // Las acciones de la AppBar se mantienen
      ),
      drawer: const CustomDrawer(currentRoute: '/my-requests'),
      body: SafeArea(
        child: _showCalendar ? CalendarContent(requests: _rawRequests) : listContent, // Muestra el listado o el calendario
      ),
    );
  }
}
