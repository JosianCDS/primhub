// /home/alexander/Descargas/primhub/lib/ui/pages/Support/request_stats_card.dart

import 'package:flutter/material.dart';
import 'package:primhub/ui/widgets/duration_formatter.dart';

class RequestStatsCard extends StatelessWidget {
  final double? contractedHours;
  final double consumedHours;
  final double estimatedHours;

  const RequestStatsCard({super.key, required this.contractedHours, required this.consumedHours, required this.estimatedHours});

  @override
  Widget build(BuildContext context) {
    final double safeContracted = contractedHours ?? 0.0;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    double availableHours = safeContracted - consumedHours;
    bool isInsufficient = estimatedHours > availableHours;

    double maxHours = safeContracted;
    if (maxHours <= 0) maxHours = 1.0;
    double consumedPct = (consumedHours / maxHours).clamp(0.0, 1.0);
    double estimatedPct = (estimatedHours / maxHours).clamp(0.0, 1.0 - consumedPct);
    int consumedFlex = (consumedPct * 1000).toInt();
    int estimatedFlex = (estimatedPct * 1000).toInt();
    int remainingFlex = 1000 - consumedFlex - estimatedFlex;

    return Card(
      color: isInsufficient ? colorScheme.errorContainer.withOpacity(0.5) : colorScheme.primaryContainer.withOpacity(0.2),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [_buildStatItem('Consumidas', consumedHours, colorScheme.error, Icons.timelapse, isMobile, context), _buildStatItem('Estimadas', estimatedHours, colorScheme.tertiary, Icons.watch_later_outlined, isMobile, context), _buildStatItem('Disponibles', availableHours, colorScheme.secondary, Icons.check_circle_outline, isMobile, context)],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 12,
                color: colorScheme.surfaceContainerHighest,
                child: isInsufficient
                    ? Container(color: colorScheme.error)
                    : Row(
                        children: [
                          if (consumedFlex > 0)
                            Expanded(
                              flex: consumedFlex,
                              child: Container(color: colorScheme.error),
                            ),
                          if (estimatedFlex > 0)
                            Expanded(
                              flex: estimatedFlex,
                              child: Container(color: colorScheme.tertiary),
                            ),
                          if (remainingFlex > 0)
                            Expanded(
                              flex: remainingFlex,
                              child: Container(color: colorScheme.secondary),
                            ),
                        ],
                      ),
              ),
            ),
            if (isInsufficient) ...[
              const SizedBox(height: 8),
              Text(
                '¡Advertencia! Las horas estimadas superan las disponibles. Deberá contratar más horas.',
                style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, double value, Color color, IconData icon, bool isMobile, BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: color);
    if (isMobile) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(DurationFormatter.format(value), style: style),
        ],
      );
    }
    return Text('$label: ${DurationFormatter.format(value)}', style: style);
  }
}
