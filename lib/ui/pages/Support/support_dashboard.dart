import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../widgets/custom_drawer.dart';
import 'package:primhub/ui/widgets/duration_formatter.dart';
import 'Requests/request_functions.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:primhub/api/global_cache.dart';
import 'package:primhub/ui/widgets/project_bottom_nav.dart';
import 'package:primhub/api/api_utils.dart';
import 'package:primhub/ui/Shared_Custom/custom_skeleton.dart';
import 'package:primhub/ui/Shared_Custom/user_info_leading.dart';

class SupportDashboardPage extends StatefulWidget {
  const SupportDashboardPage({super.key});

  @override
  State<SupportDashboardPage> createState() => _SupportDashboardPageState();
}

class _SupportDashboardPageState extends State<SupportDashboardPage> {
  List<Map<String, dynamic>> _supportRecords = [];
  bool _isLoading = true;
  double _totalConsumedHours = 0.0;
  double? _contractedHours;

  bool _isInit = true;

  // Filtro de Tercero
  List<Map<String, dynamic>> _bPartners = [];
  Map<String, int> _statusIdMap = {};
  int? _selectedBpId;
  final _adminViewModeManager = AdminViewModeManager();

  @override
  void initState() {
    super.initState();
    // La inicialización se mueve a didChangeDependencies para asegurar que el contexto esté listo
    _adminViewModeManager.addListener(_onViewModeChanged);
    GlobalCache.backgroundSyncNotifier.addListener(_onBackgroundSyncChanged);
  }

  void _onBackgroundSyncChanged() {
    if (mounted) setState(() {});
  }

  void _onViewModeChanged() {
    _refreshData();
  }

  @override
  void dispose() {
    _adminViewModeManager.removeListener(_onViewModeChanged);
    GlobalCache.backgroundSyncNotifier.removeListener(_onBackgroundSyncChanged);
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
      if (args != null && args['bpId'] != null) {
        _selectedBpId = args['bpId'];
      } else {
        _selectedBpId = AccessControl.isAdmin ? null : User.cBPartnerID;
      }
      _initData();
      _isInit = false;
    }
  }

  Future<void> _initData() async {
    if (AccessControl.isAdmin && _bPartners.isEmpty) {
      _bPartners = await ContractApi.getBPartnersWithSupportContracts();
      // Si el ID seleccionado no está en la lista de contratos, lo limpiamos
      if (_selectedBpId != null && !_bPartners.any((bp) => bp['id'] == _selectedBpId)) {
        _selectedBpId = null;
      }
    }
    _statusIdMap = await fetchStatuses();
    await _refreshData();
  }

  Future<void> _refreshData() async {
    if (mounted) setState(() => _isLoading = true);
    await _loadContractedHours();
    await _loadSupportData();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSupportData() async {
    List<Map<String, dynamic>> rawRequests = GlobalCache.requests;

    if (_selectedBpId != null) {
      rawRequests = rawRequests.where((r) => (r['C_BPartner_ID'] is Map ? r['C_BPartner_ID']['id'] : r['C_BPartner_ID']) == _selectedBpId).toList();
    } else if (!AccessControl.isAdmin && User.cBPartnerID != null) {
      rawRequests = rawRequests.where((r) => (r['C_BPartner_ID'] is Map ? r['C_BPartner_ID']['id'] : r['C_BPartner_ID']) == User.cBPartnerID).toList();
    }

    // Usar la misma función de procesamiento que my_requests.dart para consistencia
    final processedData = await processRequests(rawRequests, _statusIdMap);

    // Filtrar solo las solicitudes cerradas (espejo de la bitácora)
    final closedRequests = (processedData['requests'] as List<Map<String, dynamic>>).where((req) {
      final status = req['status'] as String?;
      final statusId = req['statusId'] as int?;
      return status == '9_Final Close' || statusId == 103;
    }).toList();

    // Ordenar por fecha descendente
    closedRequests.sort((a, b) {
      final timeA = a['time'] ?? '';
      final timeB = b['time'] ?? '';
      return timeB.compareTo(timeA);
    });

    if (mounted) {
      setState(() {
        _supportRecords = closedRequests;
        _totalConsumedHours = (processedData['consumedHours'] as num?)?.toDouble() ?? 0.0;
      });
    }
  }

  Future<void> _loadContractedHours() async {
    final contracts = GlobalCache.contracts.where((c) {
      if (_selectedBpId != null) return c['C_BPartner_ID'] == _selectedBpId;
      if (!AccessControl.isAdmin && User.cBPartnerID != null) return c['C_BPartner_ID'] == User.cBPartnerID;
      return true;
    }).toList();

    if (mounted) {
      final double totalHours = contracts.fold(0.0, (sum, contract) => sum + ((contract['contractedHours'] as num?)?.toDouble() ?? 0.0));
      setState(() {
        _contractedHours = totalHours;
      });
    }
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
              },
            ),
          ],
        );
      },
    );
  }

  void _showRequestDetails(Map<String, dynamic> record) {
    final TextEditingController summaryController = TextEditingController(text: record['description'] ?? '');
    final TextEditingController dateStartController = TextEditingController(text: record['dateStartPlan'] ?? '');
    final TextEditingController dateCompleteController = TextEditingController(text: record['dateCompletePlan'] ?? '');
    final TextEditingController startTimeController = TextEditingController(text: record['startTime'] ?? '');
    final TextEditingController endTimeController = TextEditingController(text: record['endTime'] ?? '');

    final double h = double.tryParse(record['qtyPlan']?.toString() ?? '0.0') ?? 0.0;
    final TextEditingController qtyPlanController = TextEditingController(text: DurationFormatter.format(h));

    showDialog(
      context: context,
      builder: (context) => CustomModal(
        title: 'Detalle del Ticket ${record['id']}',
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surface,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Descripción / Resumen', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Html(
                      data: record['description'] ?? '',
                      style: {"body": Style(margin: Margins.zero, padding: HtmlPaddings.zero)},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(controller: dateStartController, label: 'Inicio Plan', readOnly: true, prefixIcon: const Icon(Icons.calendar_today)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(controller: dateCompleteController, label: 'Fin Plan', readOnly: true, prefixIcon: const Icon(Icons.calendar_today)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(controller: startTimeController, label: 'Hora Inicio', readOnly: true, prefixIcon: const Icon(Icons.access_time)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(controller: endTimeController, label: 'Hora Fin', readOnly: true, prefixIcon: const Icon(Icons.access_time)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CustomTextField(controller: qtyPlanController, label: 'Horas Consumidas', readOnly: true),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: !AccessControl.isAdmin ? 180 : null,
        leading: !AccessControl.isAdmin
            ? const UserInfoLeading()
            : Builder(
                builder: (ctx) => IconButton(icon: const Icon(Icons.menu_rounded), tooltip: 'Menú Principal', onPressed: () => Scaffold.of(ctx).openDrawer()),
              ),
        title: const Text('Dashboard De Horas De Soporte'),
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
          if (GlobalCache.backgroundSyncNotifier.value)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary)),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: () {
              _refreshData();
            },
          ),
          if (!AccessControl.isAdmin)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              tooltip: 'Cerrar Sesión',
              onPressed: () => showLogoutConfirmation(context),
            ),
        ],
      ),
      drawer: AccessControl.isAdmin ? const CustomDrawer(currentRoute: '/support') : null,
      bottomNavigationBar: !AccessControl.isAdmin ? const ProjectBottomNav(currentRoute: '/support') : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Card(
                elevation: 4,
                color: isDark ? colorScheme.surface : const Color(0xFFFEFEFE),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Resumen del contrato', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final card1 = CardCustom(
                            height: 150,
                            width: null,
                            elevation: 0,
                            color: isDark ? colorScheme.surfaceContainerHighest : const Color(0xFFF6F8FA),
                            hover: true,
                            child: Container(
                              padding: const EdgeInsets.all(8.0),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Horas Contratadas',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: isDark ? colorScheme.onSurfaceVariant : const Color(0xff777D8A)),
                                  ),
                                  Text(
                                    _contractedHours == null ? '...' : DurationFormatter.format(_contractedHours!),
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: isDark ? colorScheme.onSurface : const Color(0xFF1C2430)),
                                  ),
                                ],
                              ),
                            ),
                          );
                          final card2 = CardCustom(
                            height: 150,
                            width: null,
                            elevation: 0,
                            color: isDark ? colorScheme.surfaceContainerHighest : const Color(0xFFF6F8FA),
                            hover: true,
                            child: Container(
                              padding: const EdgeInsets.all(8.0),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Horas Consumidas',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: isDark ? colorScheme.onSurfaceVariant : const Color(0xff777D8A)),
                                  ),
                                  Text(
                                    _isLoading ? '...' : DurationFormatter.format(_totalConsumedHours),
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: isDark ? colorScheme.error : const Color(0xFFD12324)),
                                  ),
                                ],
                              ),
                            ),
                          );
                          final card3 = CardCustom(
                            height: 150,
                            width: null,
                            elevation: 0,
                            color: isDark ? colorScheme.surfaceContainerHighest : const Color(0xFFE9EFFD),
                            hover: true,
                            child: Container(
                              padding: const EdgeInsets.all(8.0),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Horas Disponibles',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: isDark ? colorScheme.primary : const Color(0xFF463EE2)),
                                  ),
                                  Text(
                                    _isLoading || _contractedHours == null ? '...' : DurationFormatter.format(_contractedHours! - _totalConsumedHours),
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: isDark ? colorScheme.primary : const Color(0xFF463EE2)),
                                  ),
                                ],
                              ),
                            ),
                          );

                          if (constraints.maxWidth < 800) {
                            return Column(
                              children: [
                                SizedBox(width: double.infinity, child: card1),
                                const SizedBox(height: 10),
                                SizedBox(width: double.infinity, child: card2),
                                const SizedBox(height: 10),
                                SizedBox(width: double.infinity, child: card3),
                              ],
                            );
                          } else {
                            return Row(
                              children: [
                                Expanded(child: card1),
                                const SizedBox(width: 10),
                                Expanded(child: card2),
                                const SizedBox(width: 10),
                                Expanded(child: card3),
                              ],
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              CustomContainer(
                title: 'Registro de Horas Consumidas',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (AccessControl.isAdmin)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: SizedBox(
                          width: 300,
                          child: CustomDropdown<int?>(
                            label: 'Filtrar por Tercero',
                            // Validación estricta para evitar el AssertionError del DropdownButton
                            value: _bPartners.any((bp) => bp['id'] == _selectedBpId) ? _selectedBpId : null,
                            // Desactivamos el dropdown mientras carga para evitar colisiones
                            onChanged: _isLoading
                                ? null
                                : (val) {
                                    setState(() => _selectedBpId = val);
                                    _refreshData();
                                  },
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('Todos')),
                              ..._bPartners.map<DropdownMenuItem<int?>>((bp) {
                                return DropdownMenuItem<int?>(value: bp['id'], child: Text(bp['Name'] ?? 'Sin Nombre'));
                              }),
                            ],
                          ),
                        ),
                      ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _isLoading
                          ? const SkeletonTable()
                          : _supportRecords.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Center(
                                child: Text('No hay registros de horas consumidas para este filtro.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                              ),
                            )
                          : CustomTable(
                              columns: const [
                                DataColumn(label: Text('Ticket Relacionado')),
                                DataColumn(label: Text('Actividad/Tarea')),
                                DataColumn(label: Text('Fecha de inicio Planeada')),
                                DataColumn(label: Text('Fecha de Terminacion Planeada')),
                                DataColumn(label: Text('Horas Consumidas')),
                              ],
                              rows: _supportRecords.map((record) {
                                final double h = double.tryParse(record['qtyPlan']?.toString() ?? '0.0') ?? 0.0;
                                final hours = DurationFormatter.format(h);
                                return DataRow(
                                  onSelectChanged: (value) => _showRequestDetails(record),
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
                                              Clipboard.setData(ClipboardData(text: record['id']?.toString() ?? ''));
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código copiado al portapapeles')));
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.all(4.0),
                                              child: Icon(Icons.copy, size: 16, color: Colors.grey),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 300,
                                        child: Text(() {
                                          final cleanDesc = stripHtmlTags(record['description'] ?? '');
                                          return cleanDesc.length > 80 ? '${cleanDesc.substring(0, 80)}...' : cleanDesc;
                                        }()),
                                      ),
                                    ),
                                    DataCell(Text(record['dateStartPlan'] ?? '')),
                                    DataCell(Text(record['dateCompletePlan'] ?? '')),
                                    DataCell(Text(hours)),
                                  ],
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
