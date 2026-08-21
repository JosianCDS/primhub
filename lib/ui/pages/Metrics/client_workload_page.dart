import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/api/global_cache.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/theme/colors.dart';
import 'package:primhub/ui/widgets/custom_drawer.dart';
import 'package:primhub/ui/Shared_Custom/custom_container.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:treemap/treemap.dart';

class ClientWorkloadPage extends StatefulWidget {
  const ClientWorkloadPage({super.key});

  @override
  State<ClientWorkloadPage> createState() => _ClientWorkloadPageState();
}

class _ClientWorkloadPageState extends State<ClientWorkloadPage> {
  bool _isLoading = true;
  String _timeFilter = 'all'; // all, this_week, next_15_days, this_month
  
  int? _selectedBpId;
  List<Map<String, dynamic>> _availableBps = [];
  
  // Datos agrupados por Tercero
  // Formato: { "Nombre del Tercero": [ request1, request2... ] }
  Map<String, List<Map<String, dynamic>>> _groupedRequests = {};
  List<String> _sortedBps = [];
  
  String? _selectedSalesRep;
  List<String> _availableReps = [];

  @override
  void initState() {
    super.initState();
    if (!AccessControl.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/');
      });
      return;
    }
    _loadData();
    GlobalCache.backgroundSyncNotifier.addListener(_onSyncChanged);
  }

  @override
  void dispose() {
    GlobalCache.backgroundSyncNotifier.removeListener(_onSyncChanged);
    super.dispose();
  }

  void _onSyncChanged() {
    if (mounted) _loadData();
  }

  void _loadData() {
    setState(() => _isLoading = true);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    DateTime? minDate;
    DateTime? maxDate;

    if (_timeFilter == 'this_week') {
      final currentWeekday = today.weekday;
      minDate = today.subtract(Duration(days: currentWeekday - 1));
      maxDate = minDate.add(const Duration(days: 6));
    } else if (_timeFilter == 'this_month') {
      minDate = DateTime(today.year, today.month, 1);
      maxDate = DateTime(today.year, today.month + 1, 0);
    } else if (_timeFilter == 'next_15_days') {
      final currentWeekday = today.weekday;
      minDate = today.subtract(Duration(days: currentWeekday - 1));
      maxDate = minDate.add(const Duration(days: 13));
    }

    final rawRequests = GlobalCache.requests;
    Map<String, List<Map<String, dynamic>>> tempGrouped = {};

    for (var req in rawRequests) {
      // Filtrar siempre por el año actual
      String? createdStr = req['Created'] ?? req['DateStartPlan'] ?? req['StartDate'];
      if (createdStr != null && createdStr.length >= 4) {
        final year = int.tryParse(createdStr.substring(0, 4));
        if (year != now.year) continue;
      }

      // Descartar anuladas y archivadas
      String statusStr = (req['status'] ?? req['R_Status_Name'] ?? '').toString().toLowerCase();
      if (statusStr.isEmpty) {
        final statusObj = req['R_Status_ID'];
        if (statusObj is Map) {
          statusStr = (statusObj['Name'] ?? statusObj['identifier'] ?? '').toString().toLowerCase();
        } else if (statusObj is int) {
           statusStr = GlobalCache.statuses.keys.firstWhere((k) => GlobalCache.statuses[k] == statusObj, orElse: () => '').toLowerCase();
        }
      }
      if (statusStr.contains('anulada') || statusStr.contains('archivada')) {
        continue;
      }

      // Filtrar por fecha (Filtro superior)
      bool passDate = true;
      if (minDate != null && maxDate != null) {
        String? startStr = req['DateStartPlan'] ?? req['StartDate'] ?? req['Created'];
        if (startStr != null && startStr.isNotEmpty) {
          DateTime? reqDate = DateTime.tryParse(startStr.replaceAll(' ', 'T'));
          if (reqDate != null) {
            reqDate = DateTime(reqDate.year, reqDate.month, reqDate.day);
            if (reqDate.isBefore(minDate) || reqDate.isAfter(maxDate)) {
              passDate = false;
            }
          }
        }
      }
      if (!passDate) continue;

      // Filtrar por Tercero
      if (_selectedBpId != null) {
        final bpData = req['C_BPartner_ID'];
        int? reqBpId;
        if (bpData is Map) {
          reqBpId = (bpData['id'] as num?)?.toInt();
        } else if (bpData is num) {
          reqBpId = bpData.toInt();
        }
        if (reqBpId != _selectedBpId) {
          continue;
        }
      }

      // Agrupar por Representante
      final repData = req['SalesRep_ID'];
      String repName = '';
      if (repData is Map) {
        repName = (repData['Name'] ?? repData['identifier'] ?? '').toString().trim();
      } else if (repData != null) {
        final found = GlobalCache.users.where((u) => u['id'] == repData).toList();
        if (found.isNotEmpty) {
           repName = (found.first['Name'] ?? '').toString().trim();
        } else {
           final foundRep = GlobalCache.salesReps.where((r) => r['id'] == repData).toList();
           if (foundRep.isNotEmpty) {
              repName = (foundRep.first['Name'] ?? '').toString().trim();
           }
        }
      }
      
      if (repName.isEmpty) repName = 'Sin Asignar';

      // Filtro por Representante Comercial
      if (_selectedSalesRep != null && _selectedSalesRep != 'Todos' && repName != _selectedSalesRep) {
        continue;
      }

      final bpData = req['C_BPartner_ID'];
      final bpName = bpData is Map ? (bpData['identifier'] ?? bpData['Name'] ?? 'Sin Tercero').toString() : 'Sin Tercero';

      if (!tempGrouped.containsKey(bpName)) {
        tempGrouped[bpName] = [];
      }
      tempGrouped[bpName]!.add(req);
    }

    // Actualizar lista de terceros disponibles para el filtro
    List<String> allBps = tempGrouped.keys.toList();
    if (_availableReps.isEmpty && _selectedSalesRep == null) {
      // Necesitamos poblar _availableReps de alguna manera, lo haremos iterando todas las requests
      Set<String> repsSet = {};
      for (var req in rawRequests) {
        final repData = req['SalesRep_ID'];
        String repN = '';
        if (repData is Map) {
          repN = (repData['Name'] ?? repData['identifier'] ?? '').toString().trim();
        } else if (repData != null) {
          final found = GlobalCache.users.where((u) => u['id'] == repData).toList();
          if (found.isNotEmpty) {
             repN = (found.first['Name'] ?? '').toString().trim();
          } else {
             final foundRep = GlobalCache.salesReps.where((r) => r['id'] == repData).toList();
             if (foundRep.isNotEmpty) {
                repN = (foundRep.first['Name'] ?? '').toString().trim();
             }
          }
        }
        if (repN.isEmpty) repN = 'Sin Asignar';
        repsSet.add(repN);
      }
      _availableReps = ['Todos', ...repsSet];
      _availableReps.sort((a, b) {
        if (a == 'Todos') return -1;
        if (b == 'Todos') return 1;
        if (a == 'Sin Asignar') return 1;
        if (b == 'Sin Asignar') return -1;
        return a.compareTo(b);
      });
    }
    
    // Cargar terceros disponibles usando la misma fuente que "Mis Solicitudes"
    if (_availableBps.isEmpty) {
      _availableBps = List<Map<String, dynamic>>.from(GlobalCache.bPartners);
      _availableBps.sort((a, b) => (a['Name'] ?? '').toString().compareTo((b['Name'] ?? '').toString()));
    }

    // Ordenar terceros por volumen (descendente)
    List<String> bps = tempGrouped.keys.toList();
    bps.sort((a, b) {
      if (a == 'Sin Tercero') return 1;
      if (b == 'Sin Tercero') return -1;
      return tempGrouped[b]!.length.compareTo(tempGrouped[a]!.length);
    });

    if (mounted) {
      setState(() {
        _groupedRequests = tempGrouped;
        _sortedBps = bps;
        _isLoading = false;
      });
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Urgente': return Colors.deepPurple;
      case 'Alta': return Colors.red.shade700;
      case 'Media': return Colors.orange.shade800;
      case 'Baja': return Colors.blue.shade700;
      case 'Muy baja': return Colors.teal.shade600;
      default: return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            tooltip: 'Volver',
            onPressed: () => context.go('/metrics'),
          ),
        ),
        title: const Text('Carga de por Tercero'),
        centerTitle: true,
        backgroundColor: colorScheme.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            tooltip: 'Información del Treemap',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => CustomModal(
                  title: 'Información del Treemap',
                  width: 500,
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'El Treemap te permite visualizar rápidamente la carga de trabajo de cada representante comercial en tiempo real.',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      const Text('Funcionalidades:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      ListTile(
                        leading: const Icon(Icons.group_rounded, color: Colors.deepPurple),
                        title: const Text('Filtro por Tercero'),
                        subtitle: const Text('Filtra las solicitudes por cliente.'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      ListTile(
                        leading: const Icon(Icons.filter_alt_rounded, color: Colors.deepPurple),
                        title: const Text('Filtrado por Representante'),
                        subtitle: const Text('Haz clic en el nombre de cualquier representante (cabecera morada) para ir a "Mis Solicitudes" filtrando únicamente su trabajo.'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      ListTile(
                        leading: const Icon(Icons.article_rounded, color: Colors.deepPurple),
                        title: const Text('Detalle de Solicitud'),
                        subtitle: const Text('Haz clic en cualquier tarjeta de solicitud para ver su detalle completo.'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  actions: [
                    CustomButton(
                      text: 'Entendido',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refrescar',
            onPressed: () => GlobalCache.performSmartSync(context, () async {
              _loadData();
            }),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filtros
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Filtro por Tercero (Cliente)
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                        ),
                        child: DropdownMenu<int?>(
                          initialSelection: _selectedBpId,
                          hintText: 'Todos los Terceros',
                          leadingIcon: const Icon(Icons.business_rounded),
                          width: 280,
                          menuHeight: 300,
                          inputDecorationTheme: const InputDecorationTheme(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16),
                          ),
                          dropdownMenuEntries: [
                            const DropdownMenuEntry<int?>(value: null, label: 'Todos los Terceros'),
                            ..._availableBps.map((bp) => DropdownMenuEntry<int?>(
                              value: bp['id'] as int,
                              label: bp['Name']?.toString() ?? 'Sin Nombre',
                            )).toList(),
                          ],
                          onSelected: (val) {
                            setState(() => _selectedBpId = val);
                            _loadData();
                          },
                        ),
                      ),
                      // Filtro Búsqueda de Representante
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                        ),
                        child: DropdownMenu<String>(
                          initialSelection: _selectedSalesRep ?? 'Todos',
                          hintText: 'Representante',
                          leadingIcon: const Icon(Icons.person_outline),
                          width: 250,
                          menuHeight: 300,
                          inputDecorationTheme: const InputDecorationTheme(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16),
                          ),
                          dropdownMenuEntries: _availableReps.isEmpty 
                              ? const [DropdownMenuEntry(value: 'Todos', label: 'Todos los Representantes')]
                              : _availableReps.map((rep) => DropdownMenuEntry(value: rep, label: rep)).toList(),
                          onSelected: (val) {
                            if (val != null) {
                              setState(() => _selectedSalesRep = val == 'Todos' ? null : val);
                              _loadData();
                            }
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _timeFilter,
                            icon: const Icon(Icons.filter_alt_outlined),
                            borderRadius: BorderRadius.circular(12),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('Todo el Historial')),
                              DropdownMenuItem(value: 'this_week', child: Text('Semana Actual')),
                              DropdownMenuItem(value: 'next_15_days', child: Text('15 Días')),
                              DropdownMenuItem(value: 'this_month', child: Text('Mes Actual')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _timeFilter = val);
                                _loadData();
                              }
                            },
                          ),
                        ),
                      ),
                      
                      // Contador General
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
                        ),
                        child: Text(
                          'Total General: ${_groupedRequests.values.fold<int>(0, (sum, list) => sum + list.length)}',
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Treemap Board
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _sortedBps.isEmpty
                          ? const Center(child: Text('No hay solicitudes con los filtros actuales.'))
                          : Padding(
                              padding: const EdgeInsets.all(24.0).copyWith(top: 8.0),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  // Definir paleta de colores para los representantes
                                  final repColors = [
                                    Colors.deepPurple, Colors.blue.shade700, Colors.teal, 
                                    Colors.orange.shade700, Colors.pink, Colors.indigo, 
                                    Colors.brown, Colors.cyan.shade700, Colors.red.shade700,
                                    Colors.green.shade700
                                  ];
                                  
                                  List<TreeNode> bpNodes = [];
                                  
                                  for (String bp in _sortedBps) {
                                    final requests = _groupedRequests[bp]!;
                                    if (requests.isEmpty) continue;
                                    
                                    // Agrupar por Representante (Sales Rep) dentro de este Tercero
                                    Map<String, int> repCounts = {};
                                    Map<String, int?> repIds = {};
                                    for (var req in requests) {
                                      final repData = req['SalesRep_ID'];
                                      String repN = '';
                                      int? rId;
                                      if (repData is Map) {
                                        repN = (repData['Name'] ?? repData['identifier'] ?? '').toString().trim();
                                        rId = (repData['id'] as num?)?.toInt();
                                      } else if (repData != null) {
                                        rId = (repData as num).toInt();
                                        final found = GlobalCache.users.where((u) => u['id'] == repData).toList();
                                        if (found.isNotEmpty) {
                                           repN = (found.first['Name'] ?? '').toString().trim();
                                        } else {
                                           final foundRep = GlobalCache.salesReps.where((r) => r['id'] == repData).toList();
                                           if (foundRep.isNotEmpty) {
                                              repN = (foundRep.first['Name'] ?? '').toString().trim();
                                           }
                                        }
                                      }
                                      if (repN.isEmpty) repN = 'Sin Asignar';
                                      
                                      repCounts[repN] = (repCounts[repN] ?? 0) + 1;
                                      
                                      if (!repIds.containsKey(repN)) {
                                        repIds[repN] = rId;
                                      }
                                    }
                                    
                                    // Usar un índice estable basado en la lista global de terceros
                                    int stableIndex = _availableBps.indexWhere((element) => element['Name'] == bp);
                                    if (stableIndex < 0) stableIndex = 0;
                                    
                                    Color baseColor = repColors[stableIndex % repColors.length];
                                    
                                    List<TreeNode> repInnerNodes = [];
                                    repCounts.forEach((repNameInner, count) {
                                      repInnerNodes.add(
                                        TreeNode.leaf(
                                          value: count,
                                          margin: const EdgeInsets.all(2), // Margen entre reps del mismo cliente
                                          options: TreeNodeOptions(
                                            color: baseColor,
                                            border: Border.all(color: Colors.black12, width: 1),
                                            onTap: () {
                                              int? bpId;
                                              if (requests.isNotEmpty) {
                                                final bpData = requests.first['C_BPartner_ID'];
                                                if (bpData is Map) {
                                                  bpId = (bpData['id'] as num?)?.toInt();
                                                } else if (bpData != null) {
                                                  bpId = (bpData as num).toInt();
                                                }
                                              }

                                              final extras = <String, dynamic>{};
                                              if (bpId != null) extras['bpId'] = bpId;
                                              if (repIds[repNameInner] != null) extras['salesRepId'] = repIds[repNameInner];
                                              
                                              context.pushReplacement('/my-requests', extra: extras);
                                            },
                                            child: Tooltip(
                                              message: 'Cliente: $bp\nRepresentante: $repNameInner\nSolicitudes: $count',
                                              child: LayoutBuilder(
                                                builder: (context, constraints) {
                                                  // Si el recuadro es microscópico, no intentamos dibujar texto
                                                  if (constraints.maxHeight < 30 || constraints.maxWidth < 30) {
                                                    return const SizedBox.shrink();
                                                  }
                                                  // Si es mediano/pequeño, solo mostramos el número o limitamos el texto
                                                  final bool isSmall = constraints.maxHeight < 60;
                                                  
                                                  return Container(
                                                    padding: const EdgeInsets.all(4),
                                                    alignment: Alignment.center,
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        if (!isSmall)
                                                          Flexible(
                                                            child: Text(
                                                              repNameInner, 
                                                              style: const TextStyle(
                                                                color: Colors.white, 
                                                                fontSize: 11, 
                                                                fontWeight: FontWeight.w600, // SemiBold para mejor lectura
                                                                shadows: [Shadow(blurRadius: 2, color: Colors.black54)]
                                                              ), 
                                                              textAlign: TextAlign.center, 
                                                              maxLines: constraints.maxHeight < 90 ? 2 : 3, 
                                                              overflow: TextOverflow.ellipsis
                                                            ),
                                                          ),
                                                        if (!isSmall) const SizedBox(height: 4),
                                                        Text(
                                                          '$count', 
                                                          style: TextStyle(
                                                            color: Colors.white, 
                                                            fontSize: isSmall ? 12 : 16, 
                                                            fontWeight: FontWeight.w800, // Bold fuerte para el número
                                                            shadows: const [Shadow(blurRadius: 2, color: Colors.black54)]
                                                          )
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }
                                              ),
                                            ),
                                          ),
                                        )
                                      );
                                    });
                                    
                                    if (repInnerNodes.isNotEmpty) {
                                      bpNodes.add(
                                        TreeNode.node(
                                          children: repInnerNodes,
                                          margin: const EdgeInsets.all(4), // Margen exterior entre bloques
                                          padding: const EdgeInsets.only(top: 24), // Padding interior para el título
                                          options: TreeNodeOptions(
                                            color: Colors.transparent,
                                            border: Border.all(color: Colors.white24, width: 1),
                                            child: Align(
                                              alignment: Alignment.topLeft,
                                              child: Container(
                                                height: 24,
                                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                                alignment: Alignment.centerLeft,
                                                color: baseColor, // Usar el mismo color del bloque para la pestaña
                                                child: Text(
                                                  '$bp (${requests.length})',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600, // SemiBold para un look más moderno
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          )
                                        )
                                      );
                                    }
                                  }

                                  if (bpNodes.isEmpty) {
                                    return const Center(child: Text('No hay datos para renderizar el treemap.'));
                                  }

                                  return TreeMapLayout(
                                    tile: const Squarify(),
                                    children: bpNodes,
                                  );
                                },
                              ),
                            ),
                ),
          ],
        ),
      ),
    );
  }
}