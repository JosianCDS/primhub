import 'package:flutter/material.dart';
import 'package:primhub/ui/widgets/duration_formatter.dart';

class RequestStatsCard extends StatelessWidget {
  final double? contractedHours;
  final double consumedHours;
  final double estimatedHours;

  const RequestStatsCard({
    super.key,
    required this.contractedHours,
    required this.consumedHours,
    required this.estimatedHours,
  });

  @override
  Widget build(BuildContext context) {
    final double safeContracted = contractedHours ?? 0.0;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    double availableHours = safeContracted - consumedHours;
    bool isInsufficient = (estimatedHours > availableHours) && safeContracted > 0;

    double maxHours = safeContracted;
    if (maxHours <= 0) maxHours = 1.0;
    
    double consumedPct = (consumedHours / maxHours).clamp(0.0, 1.0);
    double estimatedPct = (estimatedHours / maxHours).clamp(0.0, 1.0 - consumedPct);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: isInsufficient 
            ? colorScheme.errorContainer.withOpacity(0.3) 
            : colorScheme.surfaceContainerHighest.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isInsufficient 
              ? colorScheme.error.withOpacity(0.2) 
              : colorScheme.outlineVariant.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header simplificado
          Row(
            children: [
              Icon(
                isInsufficient ? Icons.warning_rounded : Icons.pie_chart_outline_rounded,
                size: 18,
                color: isInsufficient ? colorScheme.error : colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Estado de Horas',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isInsufficient ? colorScheme.error : colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (contractedHours != null)
                Text(
                  'Total: ${DurationFormatter.format(safeContracted)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats compactos
          Wrap(
            spacing: 20.0,
            runSpacing: 8.0,
            children: [
              _buildCompactStat(context, 'Consumidas', consumedHours, colorScheme.error),
              _buildCompactStat(context, 'Estimadas', estimatedHours, colorScheme.tertiary),
              _buildCompactStat(context, 'Disponibles', availableHours, colorScheme.primary),
            ],
          ),
          const SizedBox(height: 16),
          // Barra minimalista
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 8,
              width: double.infinity,
              color: colorScheme.surfaceContainerHighest,
              child: isInsufficient
                  ? Container(color: colorScheme.error)
                  : Stack(
                      children: [
                        // Capa de Estimadas (debajo)
                        FractionallySizedBox(
                          widthFactor: (consumedPct + estimatedPct).clamp(0.0, 1.0),
                          child: Container(color: colorScheme.tertiary.withOpacity(0.7)),
                        ),
                        // Capa de Consumidas (encima)
                        FractionallySizedBox(
                          widthFactor: consumedPct,
                          child: Container(color: colorScheme.error),
                        ),
                      ],
                    ),
            ),
          ),
          if (isInsufficient) ...[
            const SizedBox(height: 8),
            Text(
              '⚠️ Las estimaciones superan el saldo disponible.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactStat(BuildContext context, String label, double value, Color color) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 9,
            letterSpacing: 0.5,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
          ),
        ),
        Text(
          DurationFormatter.format(value),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
