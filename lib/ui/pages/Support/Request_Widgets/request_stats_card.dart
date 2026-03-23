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

    final isDark = Theme.of(context).brightness == Brightness.dark;
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
      color: isInsufficient ? (isDark ? Colors.red.shade900.withOpacity(0.5) : Colors.red.shade50) : (isDark ? Colors.blue.shade900.withOpacity(0.5) : Colors.blue.shade50),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem('Consumidas', consumedHours, isDark ? Colors.red.shade300 : Colors.red.shade800, Icons.timelapse, isMobile),
                _buildStatItem('Estimadas', estimatedHours, isDark ? Colors.amber.shade300 : Colors.amber.shade800, Icons.watch_later_outlined, isMobile),
                _buildStatItem('Disponibles', availableHours, isDark ? Colors.green.shade300 : Colors.green.shade800, Icons.check_circle_outline, isMobile),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 12,
                color: Colors.grey.shade300,
                child: isInsufficient
                    ? Container(color: Colors.red)
                    : Row(
                        children: [
                          if (consumedFlex > 0)
                            Expanded(
                              flex: consumedFlex,
                              child: Container(color: Colors.red),
                            ),
                          if (estimatedFlex > 0)
                            Expanded(
                              flex: estimatedFlex,
                              child: Container(color: Colors.amber),
                            ),
                          if (remainingFlex > 0)
                            Expanded(
                              flex: remainingFlex,
                              child: Container(color: Colors.green),
                            ),
                        ],
                      ),
              ),
            ),
            if (isInsufficient) ...[
              const SizedBox(height: 8),
              Text(
                '¡Advertencia! Las horas estimadas superan las disponibles. Deberá contratar más horas.',
                style: TextStyle(color: isDark ? Colors.red.shade200 : Colors.red.shade800, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, double value, Color color, IconData icon, bool isMobile) {
    final style = TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color);
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
