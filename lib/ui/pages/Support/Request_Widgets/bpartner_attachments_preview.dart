import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:primhub/ImagesManagment/fetch_attachments.dart';
import 'package:primhub/endpoint/endpoint.dart';
import 'package:primhub/ui/pages/Support/support_dashboard.dart';

class BPartnerAttachmentsPreview extends StatefulWidget {
  final int bPartnerId;

  const BPartnerAttachmentsPreview({super.key, required this.bPartnerId});

  @override
  State<BPartnerAttachmentsPreview> createState() => _BPartnerAttachmentsPreviewState();
}

class _BPartnerAttachmentsPreviewState extends State<BPartnerAttachmentsPreview> {
  List<Map<String, dynamic>> _attachments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAttachments();
  }

  @override
  void didUpdateWidget(covariant BPartnerAttachmentsPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bPartnerId != widget.bPartnerId) {
      _loadAttachments();
    }
  }

  Future<void> _loadAttachments() async {
    setState(() => _isLoading = true);
    const tableName = 'C_BPartner';
    final String fullTableUrl = '${Endpoint.baseUrl}/api/v1/models/$tableName';
    final attachments = await fetchAttachments(recordID: widget.bPartnerId, tableName: fullTableUrl);
    
    if (mounted) {
      setState(() {
        _attachments = attachments;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 40,
        width: 40,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_attachments.isEmpty) {
      return const SizedBox.shrink(); // No mostrar nada si no hay adjuntos
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => BPartnerAttachmentsDialog(bPartnerId: widget.bPartnerId),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.withOpacity(0.2),
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SvgPicture.asset(
                'assets/sla_icon.svg',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    'SLA',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_attachments.length} Archivo${_attachments.length > 1 ? 's' : ''}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
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
