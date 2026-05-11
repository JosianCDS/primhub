import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/ui/Shared_Custom/cardcustom.dart';
import 'package:primhub/ui/Shared_Custom/custom_skeleton.dart';
import 'package:primhub/ui/Shared_Custom/custom_button.dart';
import 'package:primhub/ui/widgets/duration_formatter.dart';

class UnifiedSupportCard extends StatelessWidget {
  final String bpName;
  final String? productLabel; // Descripción de la ficha de producto
  final String? frequency;
  final String? serviceStartDate;
  final String? serviceFinishDate;
  final double acquiredHours;
  final double inProgressHours;
  final double consumedHours;
  final int inProgressRequestsCount;
  final int closedRequestsCount;
  final VoidCallback onShowAllContracts;
  final VoidCallback? onAvailableHoursTap;
  final VoidCallback? onInProgressTap;
  final VoidCallback? onClosedTap;
  final bool isLoading;

  const UnifiedSupportCard({
    super.key,
    required this.bpName,
    this.productLabel,
    this.frequency,
    this.serviceStartDate,
    this.serviceFinishDate,
    required this.acquiredHours,
    required this.inProgressHours,
    required this.consumedHours,
    required this.inProgressRequestsCount,
    required this.closedRequestsCount,
    required this.onShowAllContracts,
    this.onAvailableHoursTap,
    this.onInProgressTap,
    this.onClosedTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final double availableHours =
        acquiredHours - consumedHours; // Según requerimiento: Estimadas no se restan de disponibles
    final bool isInsufficient = availableHours <= 0;

    const Color headerIconColor = Color(0xFF4F46E5);
    const Color headerIconBgColor = Color(0xFFEEF2FF);
    const Color statColor = Color(0xFFD97708);

    String dateRange = 'Vigencia: ';
    if (serviceStartDate != null && serviceFinishDate != null) {
      dateRange +=
          '${serviceStartDate!.split('T')[0]} - ${serviceFinishDate!.split('T')[0]}';
    } else {
      dateRange += 'No definida';
    }

    return CardCustom(
      hover: false,
      height: null,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: headerIconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: headerIconColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productLabel ?? bpName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (productLabel != null)
                        Text(
                          bpName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (frequency != null)
                  Chip(
                    label: Text(
                      frequency!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF1E40AF),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: const Color(0xFFDBEAFE),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              dateRange,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
            const Divider(height: 24),
            // Hours Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MiniStatItem(
                  label: 'Adquiridas',
                  value: acquiredHours,
                  color: Colors.blueGrey,
                  isHour: true,
                ),
                _MiniStatItem(
                  label: 'Estimadas',
                  value: inProgressHours,
                  color: Colors.blue,
                  isHour: true,
                ),
                _MiniStatItem(
                  label: 'Consumidas',
                  value: consumedHours,
                  color: Colors.green,
                  isHour: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Availability Main Stat
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: isInsufficient
                    ? Colors.red.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isInsufficient
                      ? Colors.red.withOpacity(0.3)
                      : Colors.orange.withOpacity(0.3),
                ),
              ),
              child: InkWell(
                onTap: onAvailableHoursTap,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DISPONIBLES',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isInsufficient
                                ? Colors.red.shade900
                                : Colors.orange.shade900,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DurationFormatter.format(availableHours),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: isInsufficient
                                ? Colors.red.shade900
                                : Colors.orange.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Requests counters
            Row(
              children: [
                 Expanded(
                  child: InkWell(
                    onTap: onInProgressTap,
                    borderRadius: BorderRadius.circular(12),
                    child: _CompactRequestStat(
                      label: 'En Curso',
                      count: inProgressRequestsCount,
                      icon: Icons.sync,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: onClosedTap,
                    borderRadius: BorderRadius.circular(12),
                    child: _CompactRequestStat(
                      label: 'Finalizadas',
                      count: closedRequestsCount,
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatItem extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool isHour;

  const _MiniStatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.isHour,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          isHour ? DurationFormatter.format(value) : value.toInt().toString(),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

class _CompactRequestStat extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  const _CompactRequestStat({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractiveStatItem extends StatefulWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onTap;
  final bool isHour;

  const _InteractiveStatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.isLoading,
    this.onTap,
    required this.isHour,
  });

  @override
  State<_InteractiveStatItem> createState() => _InteractiveStatItemState();
}

class _InteractiveStatItemState extends State<_InteractiveStatItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedValue = widget.isHour
        ? DurationFormatter.format(widget.value)
        : widget.value.toInt().toString();

    final innerContent = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(widget.icon, color: widget.color, size: 28),
        const SizedBox(height: 8),
        if (widget.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: CustomSkeleton(
              height: 28,
              width: 70,
            ), // Skeleton tiene un tamaño fijo
          )
        else
          Text(
            formattedValue,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: widget.color,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1, // Asegura que el texto no expanda la altura
            overflow:
                TextOverflow.ellipsis, // Maneja el desbordamiento de texto
          ),
        Text(
          widget.label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
          maxLines: 1, // Asegura que el texto no expanda la altura
          overflow: TextOverflow.ellipsis, // Maneja el desbordamiento de texto
        ),
      ],
    );

    final clickableArea = SizedBox(
      // Define un tamaño fijo para el área clickeable
      width: 120, // Ancho fijo, ajusta según sea necesario
      height: 100, // Alto fijo, ajusta según sea necesario
      child: innerContent,
    );

    if (widget.onTap != null) {
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: widget.isLoading
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: InkWell(
          onTap: widget.isLoading ? null : widget.onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            // No se necesita padding aquí, el hijo SizedBox ya define el área de contenido
            decoration: BoxDecoration(
              // El fondo se oscurece al pasar el mouse
              color: _isHovered && !widget.isLoading
                  ? theme.colorScheme.primary.withOpacity(0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              // El borde es siempre visible y se hace más prominente al pasar el mouse
              border: Border.all(
                color: _isHovered && !widget.isLoading
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withOpacity(0.2),
                width: 1.5,
              ),
              // La sombra aparece al pasar el mouse
              boxShadow: _isHovered && !widget.isLoading
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: clickableArea, // El SizedBox de tamaño fijo es ahora el hijo
          ),
        ),
      );
    }
    return clickableArea; // Si no es clickeable, aún devuelve el contenido de tamaño fijo
  }
}
