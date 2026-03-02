import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/ui/shared/cardcustom.dart';
import 'package:primhub/ui/widgets/duration_formatter.dart';

class SupportHoursCard extends StatelessWidget {
  final double? contractedHours;
  final double consumedHours;
  final bool isDark;
  final Color textColor;

  const SupportHoursCard({
    super.key,
    required this.contractedHours,
    required this.consumedHours,
    required this.isDark,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    double progress = 0.0;
    if (contractedHours != null && contractedHours! > 0) {
      progress = consumedHours / contractedHours!;
    }

    return InkWell(
      onTap: () => context.push('/support'),
      borderRadius: BorderRadius.circular(12),
      child: CardCustom(
        hover: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Color.fromRGBO(223, 231, 255, 1), shape: BoxShape.circle),
              child: const Icon(Icons.access_time, color: Color.fromRGBO(79, 71, 229, 1), size: 36),
            ),
            const SizedBox(height: 16),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Horas De soporte Disponibles',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                ),
                Text(
                  contractedHours == null ? '...' : DurationFormatter.format(contractedHours! - consumedHours),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(color: const Color(0xff4F47E5), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
                duration: const Duration(seconds: 2),
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(progress > 1.0 ? Colors.red : const Color.fromARGB(255, 200, 42, 42)),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4)
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              contractedHours == null ? 'Cargando contrato...' : 'Contrato de ${DurationFormatter.format(contractedHours!)}.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'renovacion: 31/12/2026',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Frecuencia: ${ProductChip.frecuencyID ?? 'No definida'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class SupportRequestsCard extends StatelessWidget {
  final int closedRequestsCount;
  final int inProgressRequestsCount;
  final Color textColor;

  const SupportRequestsCard({
    super.key,
    required this.closedRequestsCount,
    required this.inProgressRequestsCount,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/my-requests'),
      borderRadius: BorderRadius.circular(12),
      child: CardCustom(
        hover: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Color.fromRGBO(254, 244, 199, 1), shape: BoxShape.circle),
              child: const Icon(Icons.sync, color: Color.fromRGBO(217, 119, 8, 1), size: 36),
            ),
            const SizedBox(height: 16),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Solicitudes ya atendidas',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                ),
                Text(
                  '',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(color: const Color(0xffD97708), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              ' están en revisión/progreso.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
