import 'package:flutter/material.dart';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/ui/widgets/hover_widgets.dart';

class FileCard extends StatelessWidget {
  final String extension;
  final String name;
  final String size;
  final Color color;
  final int charLimit;
  final bool isFolder;
  final Map<String, dynamic> details;
  final VoidCallback onTap;
  final VoidCallback? onDownload;
  final VoidCallback? onProperties;
  final bool isDownloading;

  const FileCard({super.key, required this.extension, required this.name, required this.size, required this.color, required this.charLimit, required this.details, required this.onTap, this.isFolder = false, this.onDownload, this.onProperties, this.isDownloading = false});

  @override
  Widget build(BuildContext context) {
    return HoverScaleCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Card(
          elevation: 4,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: isFolder ? const EdgeInsets.all(8) : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        border: Border.all(color: color, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: isFolder ? Icon(Icons.folder, color: color, size: 28) : Icon(DocumentsLogic.getFileIcon(extension), color: color, size: 28),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name.split('.').first.length > charLimit ? '${name.split('.').first.substring(0, charLimit)}...' : name.split('.').first,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(size, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(height: 8),
                    _buildStatusChip(context),
                    const SizedBox(height: 12),
                    if (isDownloading) const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) else Icon(isFolder ? Icons.folder_open : Icons.download, color: Theme.of(context).colorScheme.primary, size: 24),
                  ],
                ),
              ),
              if (AccessControl.canManageFiles && onProperties != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(icon: const Icon(Icons.info_outline), color: Colors.grey[500], tooltip: 'Ver propiedades', onPressed: onProperties),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    final status = DocumentsLogic.extractStatus(details['Status']);
    final statusColor = DocumentsLogic.getStatusColor(status);
    return Chip(
      label: Text(
        status,
        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
      ),
      backgroundColor: statusColor.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
