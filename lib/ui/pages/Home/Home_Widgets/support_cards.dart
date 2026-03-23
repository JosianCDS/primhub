import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/ui/Shared_Custom/cardcustom.dart';
import 'package:primhub/ui/widgets/duration_formatter.dart';

class SupportHoursCard extends StatelessWidget {
  final Map<String, dynamic> contract;
  final bool isDark;
  final Color textColor;

  const SupportHoursCard({super.key, required this.contract, required this.isDark, required this.textColor});

  @override
  Widget build(BuildContext context) {
    final double contractedHours = contract['contractedHours'] ?? 0.0;
    final double consumedHours = contract['consumedHours'] ?? 0.0;
    final String documentNo = contract['DocumentNo'] ?? 'N/A';

    double progress = 0.0;
    if (contractedHours > 0) {
      progress = consumedHours / contractedHours;
    }

    return InkWell(
      onTap: () => context.push('/support', extra: {'contract': contract, 'bpId': contract['C_BPartner_ID']}),
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
                  DurationFormatter.format(contractedHours - consumedHours),
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
                builder: (context, value, _) => LinearProgressIndicator(value: value, backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(progress > 1.0 ? Colors.red : const Color.fromARGB(255, 200, 42, 42)), minHeight: 8, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Contrato: $documentNo',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ${DurationFormatter.format(contractedHours)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class SupportRequestsCard extends StatelessWidget {
  final int bpId;
  final String? bpName;
  final int closedRequestsCount;
  final int inProgressRequestsCount;
  final Color textColor;

  const SupportRequestsCard({super.key, required this.bpId, this.bpName, required this.closedRequestsCount, required this.inProgressRequestsCount, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/my-requests', extra: {'bpId': bpId, 'bpName': bpName}),
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
            if (bpName != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  bpName!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.7)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Solicitudes Atendidas',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                ),
                Text(
                  '$closedRequestsCount',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(color: const Color(0xffD97708), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '$inProgressRequestsCount están en revisión/progreso.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
