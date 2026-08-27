import 'package:flutter/material.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/widgets/duration_formatter.dart';
import 'package:primhub/ui/Shared_Custom/custom_modal.dart';
import 'package:primhub/ui/Shared_Custom/custom_inputs.dart'; // Para CustomTextField
import 'package:primhub/api/contract_api.dart';
import 'package:primhub/ui/Shared_Custom/custom_skeleton.dart';
import 'package:primhub/api/global_cache.dart';
import 'package:primhub/ui/pages/Support/Requests/request_functions.dart';

class SupportSummaryPremium extends StatelessWidget {
  final double contractedHours;
  final double consumedHours;
  final double inProgressHours;
  final double availableHours;
  final List<Map<String, dynamic>> processedChips;
  final int? selectedChipId;
  final Function(int?)? onChipTap;
  final VoidCallback onRefresh;
  final bool allowRename;
  final String? emptyMessage;
  final bool isLoading;
  final Widget? attachmentCarousel;

  const SupportSummaryPremium({
    super.key,
    required this.contractedHours,
    required this.consumedHours,
    required this.inProgressHours,
    required this.availableHours,
    required this.processedChips,
    required this.onRefresh,
    this.selectedChipId,
    this.onChipTap,
    this.allowRename = false,
    this.emptyMessage,
    this.isLoading = false,
    this.attachmentCarousel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  colorScheme.surfaceContainerHigh,
                  colorScheme.surfaceContainerHighest,
                ]
              : [const Color(0xFFFFFFFF), const Color(0xFFF8FAFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 500;
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resumen del Plan de Soporte',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: isDark
                                  ? colorScheme.primary
                                  : const Color(0xFF463EE2),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Año ${DateTime.now().year}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ?attachmentCarousel,
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: (isDark ? colorScheme.primary : const Color(0xFF463EE2))
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${DurationFormatter.format(contractedHours)} Adquiridas',
                                  style: TextStyle(
                                    color: isDark
                                        ? colorScheme.primary
                                        : const Color(0xFF463EE2),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Resumen del Plan de Soporte',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: isDark
                                      ? colorScheme.primary
                                      : const Color(0xFF463EE2),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Año ${DateTime.now().year}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (attachmentCarousel != null) ...[
                                attachmentCarousel!,
                                const SizedBox(width: 12),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: (isDark ? colorScheme.primary : const Color(0xFF463EE2))
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${DurationFormatter.format(contractedHours)} Adquiridas',
                                  style: TextStyle(
                                    color: isDark
                                        ? colorScheme.primary
                                        : const Color(0xFF463EE2),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
            const SizedBox(height: 24),
            // Carrusel de Fichas
            SizedBox(
              height: 160,
              child: isLoading
                  ? ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 3,
                      itemBuilder: (context, index) => const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: CustomSkeleton(
                          width: 280,
                          height: 160,
                          borderRadius: 20,
                        ),
                      ),
                    )
                  : processedChips.isEmpty
                  ? Center(
                      child: Text(
                        emptyMessage ??
                            'No hay fichas de producto para el periodo actual',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: processedChips.length,
                      itemBuilder: (context, index) {
                        final chip = processedChips[index];
                        final int chipId = chip['id'];
                        final bool isSelected = selectedChipId == chipId;
                        final double available =
                            (chip['available'] as num?)?.toDouble() ?? 0.0;
                        final double consumedFromThis =
                            (chip['consumed'] as num?)?.toDouble() ?? 0.0;
                        final double estimatedFromThis =
                            (chip['estimated'] as num?)?.toDouble() ?? 0.0;
                        final double total =
                            (chip['Qty'] as num?)?.toDouble() ?? 1.0;
                        final double percent = (consumedFromThis / total).clamp(
                          0.0,
                          1.0,
                        );
                        final String chipName =
                            chip['Description'] ?? 'Ficha sin nombre';
                        final String serviceStart =
                            chip['service_start_date'] ?? 'N/A';
                        final String serviceFinish =
                            chip['service_finish_date'] ?? 'N/A';
                        final bool isActive = chip['IsActive'] == 'Y' || chip['IsActive'] == true;

                        String bpName = 'Sin Tercero';
                        final rawBp = chip['C_BPartner_ID'];
                        if (rawBp is Map) {
                          bpName = (rawBp['identifier'] ?? rawBp['Name'] ?? 'Sin Tercero').toString();
                        } else if (rawBp != null) {
                          final bpId = (rawBp is num) ? rawBp.toInt() : int.tryParse(rawBp.toString()) ?? 0;
                          var found = GlobalCache.allBPartners.firstWhere(
                            (bp) => bp['id'] == bpId,
                            orElse: () => <String, dynamic>{},
                          );
                          if (found.isEmpty) {
                            found = GlobalCache.bPartners.firstWhere(
                              (bp) => bp['id'] == bpId,
                              orElse: () => <String, dynamic>{},
                            );
                          }
                          bpName = found.isNotEmpty ? (found['Name'] ?? 'Tercero $bpId') : 'Tercero $bpId';
                        }
                        if (bpName.length > 30) {
                          bpName = '${bpName.substring(0, 30)}...';
                        }

                        return InkWell(
                          onTap: () => onChipTap?.call(chipId),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 280,
                            margin: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark
                                        ? colorScheme.primary.withOpacity(0.15)
                                        : const Color(0xFFEEF2FF))
                                  : (isDark
                                        ? colorScheme.surface
                                        : Colors.white),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? (isDark
                                          ? colorScheme.primary
                                          : const Color(0xFF463EE2))
                                    : colorScheme.outline.withOpacity(0.1),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color:
                                            (isDark
                                                    ? colorScheme.primary
                                                    : const Color(0xFF463EE2))
                                                .withOpacity(0.2),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          chipName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isSelected 
                                                ? (isDark ? Colors.white : const Color(0xFF1E1B4B))
                                                : (isDark ? Colors.white : Colors.black87),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (allowRename && AccessControl.isAdmin)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 16,
                                          ),
                                          onPressed: () =>
                                              _showEditChipNameDialog(
                                                context,
                                                chip,
                                              ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      if (AccessControl.isAdmin)
                                        SizedBox(
                                          height: 24,
                                          child: FittedBox(
                                            fit: BoxFit.contain,
                                            child: Switch(
                                              value: isActive,
                                              activeColor: Colors.green,
                                              inactiveThumbColor: Colors.grey,
                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              onChanged: (val) => _toggleChipActive(context, chip, val),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$serviceStart al $serviceFinish',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                      color: isSelected 
                                          ? (isDark ? Colors.white70 : const Color(0xFF4338CA))
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    bpName,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected 
                                          ? (isDark ? Colors.white : const Color(0xFF1E1B4B))
                                          : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                  const Spacer(),
                                  Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${DurationFormatter.format(consumedFromThis)} cons.',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                              if (estimatedFromThis > 0)
                                                Text(
                                                  '${DurationFormatter.format(estimatedFromThis)} est.',
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Colors
                                                            .orange
                                                            .shade700,
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                            ],
                                          ),
                                          Text(
                                            '${DurationFormatter.format(available)} disp.',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: available > 0
                                                      ? Colors.green
                                                      : Colors.red,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: percent,
                                          backgroundColor: colorScheme
                                              .surfaceContainerHighest,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                available > 0
                                                    ? Colors.green
                                                    : Colors.red,
                                              ),
                                          minHeight: 4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 24),
            isMobile
                ? Column(
                    children: [
                      _buildSmallStat(
                        context,
                        'Horas Contratadas',
                        DurationFormatter.format(contractedHours),
                        Icons.inventory_2_outlined,
                        const Color(0xFF64748B),
                      ),
                      const SizedBox(height: 12),
                      _buildSmallStat(
                        context,
                        'Horas Consumidas',
                        DurationFormatter.format(consumedHours),
                        Icons.check_circle_outline,
                        const Color(0xFFEF4444),
                      ),
                      const SizedBox(height: 12),
                      _buildSmallStat(
                        context,
                        'Horas Disponibles',
                        DurationFormatter.format(availableHours),
                        Icons.account_balance_wallet_outlined,
                        const Color(0xFF463EE2),
                        isMain: true,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _buildSmallStat(
                          context,
                          'Horas Contratadas',
                          DurationFormatter.format(contractedHours),
                          Icons.inventory_2_outlined,
                          const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSmallStat(
                          context,
                          'Horas Consumidas',
                          DurationFormatter.format(consumedHours),
                          Icons.check_circle_outline,
                          const Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSmallStat(
                          context,
                          'Horas Disponibles',
                          DurationFormatter.format(availableHours),
                          Icons.account_balance_wallet_outlined,
                          const Color(0xFF463EE2),
                          isMain: true,
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      );
    },
  ),
);
  }

  Widget _buildSmallStat(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isMain = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: isMain
            ? (isDark ? color.withOpacity(0.15) : const Color(0xFFEEF2FF))
            : (isDark ? color.withOpacity(0.05) : color.withOpacity(0.03)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMain ? color.withOpacity(0.3) : color.withOpacity(0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isMain ? color : color.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isMain ? color : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditChipNameDialog(
    BuildContext context,
    Map<String, dynamic> chip,
  ) {
    final nameController = TextEditingController(
      text: chip['Description'] ?? '',
    );
    final chipId = int.tryParse(chip['id']?.toString() ?? '') ?? 0;
    if (chipId == 0) {
// [Mantenimiento] Log removido:       debugPrint("ERROR: ID de ficha no válido para renombrar: ${chip['id']}");
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setModalState) => CustomModal(
            title: 'Renombrar Ficha de Producto',
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Asigna un nombre descriptivo a esta ficha para identificarla fácilmente.',
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: nameController,
                  label: 'Nombre de la Ficha',
                  hintText: 'Ej: Soporte Mensual Mayo',
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              CustomButton(
                text: 'Guardar',
                isLoading: isSaving,
                onPressed: () async {
                  final newName = nameController.text.trim();
                  if (newName.isEmpty) return;

                  setModalState(() => isSaving = true);
                  final success =
                      await ContractApi.updateProductChipDescription(
                        chipId,
                        newName,
                      );

                  if (context.mounted) {
                    if (success) {
                      Navigator.pop(context);
                      onRefresh();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nombre actualizado correctamente'),
                        ),
                      );
                    } else {
                      setModalState(() => isSaving = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Error al actualizar el nombre'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleChipActive(BuildContext context, Map<String, dynamic> chip, bool newValue) async {
    final int chipId = chip['id'];
    final String chipName = chip['Description'] ?? 'Ficha sin nombre';
    
    if (!newValue) {
      // Intentando desactivar: Validar si existen solicitudes asociadas
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );
      
      final reqCount = await fetchRequestCount(filter: "C_BPartner_Product_Chip_ID eq $chipId");
      if (context.mounted) Navigator.pop(context); // cerrar cargando
      
      if (reqCount > 0) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => CustomModal(
              title: 'Acción Denegada',
              content: Text('No es posible inactivar esta ficha ($chipName) porque tiene $reqCount solicitudes asociadas a ella. Debe reasignar las solicitudes o eliminarlas primero.'),
              actions: [
                CustomButton(
                  text: 'Aceptar',
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          );
        }
        return;
      }
    }
    
    if (!context.mounted) return;
    
    // Mostrar diálogo de confirmación
    final String actionText = newValue ? 'activar' : 'inactivar';
    final double totalQty = (chip['Qty'] as num?)?.toDouble() ?? 0.0;
    String bpName = 'Sin Tercero';
    final rawBp = chip['C_BPartner_ID'];
    if (rawBp is Map) {
      bpName = (rawBp['identifier'] ?? rawBp['Name'] ?? 'Sin Tercero').toString();
    } else if (rawBp != null) {
      bpName = 'Tercero $rawBp';
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => CustomModal(
        title: 'Confirmar Acción',
        content: Text('¿Está seguro de que desea $actionText la ficha "$chipName"?\n\nAl $actionText, se modificará el saldo disponible del tercero $bpName (Total: ${DurationFormatter.format(totalQty)}).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          CustomButton(
            text: 'Sí, $actionText',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    if (!context.mounted) return;
    
    // Ejecutar el cambio
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    
    final success = await ContractApi.updateProductChipActive(chipId, newValue);
    
    if (context.mounted) {
      Navigator.pop(context); // cerrar cargando
      if (success) {
        onRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ficha ${newValue ? 'activada' : 'inactivada'} correctamente.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al cambiar el estado de la ficha.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
