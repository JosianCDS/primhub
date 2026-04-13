import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:primhub/api/access_control.dart';
import 'package:primhub/ui/pages/Projects/Documents/documents_logic.dart';
import 'package:primhub/ui/widgets/hover_widgets.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

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
  final String tableName;
  final Function(Map<String, dynamic> doc, String tableName, int targetFolderId)? onMoveToFolder;
  final Function(int draggedId, int targetId)? onReorder;
  final int columns;

  const FileCard({super.key, required this.extension, required this.name, required this.size, required this.color, required this.charLimit, required this.details, required this.onTap, this.isFolder = false, this.onDownload, this.onProperties, this.isDownloading = false, required this.tableName, this.onMoveToFolder, this.onReorder, this.columns = 5});

  @override
  Widget build(BuildContext context) {
    final String visualName = (details['Description'] != null && details['Description'].toString().trim().isNotEmpty) ? details['Description'].toString() : name;
    final bool isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension.toLowerCase());
    final bool isCompact = columns >= 8;

    Widget cardContent = HoverScaleCard(
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          elevation: 4,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 55, // 55% para la previsualización de imagen
                    child: Container(
                      color: color.withOpacity(0.1),
                      child: isFolder
                          ? Icon(Icons.folder, color: color, size: isCompact ? 56 : 80)
                          : (isImage
                                ? FutureBuilder<Uint8List?>(
                                    future: DocumentsLogic.fetchImagePreview(tableName, details['id'], name),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData && snapshot.data != null) {
                                        return ImageHoverPreview(
                                          imageBytes: snapshot.data!,
                                          child: Image.memory(snapshot.data!, fit: BoxFit.cover, width: double.infinity, height: double.infinity, gaplessPlayback: true),
                                        );
                                      }
                                      return Center(
                                        child: Icon(DocumentsLogic.getFileIcon(extension), color: color, size: isCompact ? 48 : 72),
                                      );
                                    },
                                  )
                                : Center(
                                    child: Icon(DocumentsLogic.getFileIcon(extension), color: color, size: isCompact ? 48 : 72),
                                  )),
                    ),
                  ),
                  Expanded(
                    flex: 45, // 45% para los detalles inferiores
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: isCompact ? 4.0 : 8.0, vertical: 4.0),
                      color: Theme.of(context).cardColor,
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                visualName.split('.').first,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: isCompact ? 12 : 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              if (!isFolder && !isCompact) ...[_buildStatusChip(context), const SizedBox(height: 4)],
                              if (isFolder && size.isNotEmpty && !isCompact) ...[Text(size, style: TextStyle(color: Colors.grey[600], fontSize: 11)), const SizedBox(height: 4)],
                              if (isDownloading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) else if (!isCompact) Icon(isFolder ? Icons.folder_open : Icons.download, color: Theme.of(context).colorScheme.primary, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (AccessControl.canManageFiles && onProperties != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(icon: const Icon(Icons.info_outline), color: Colors.grey[500], tooltip: 'Ver propiedades', onPressed: onProperties),
                ),
              if (!isFolder && AccessControl.canManageFiles)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Theme.of(context).cardColor.withOpacity(0.8), shape: BoxShape.circle),
                    child: Tooltip(
                      message: 'Arrastra para mover',
                      child: Icon(Icons.drag_indicator, color: Colors.grey[600], size: 20),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    Widget dropRegion = DropRegion(
      formats: Formats.standardFormats,
      onDropOver: (event) {
        if (event.session.items.isEmpty) return DropOperation.none;
        final item = event.session.items.first;
        if (item.localData != null && item.localData is Map) {
          final draggedData = item.localData as Map;
          final draggedId = draggedData['id'];

          if (draggedId == details['id']) return DropOperation.none; // Evitar soltar sobre sí mismo

          final draggedType = draggedData['type'];
          if (isFolder && draggedType == 'file') {
            return DropOperation.move; // Mover a la carpeta
          } else {
            return DropOperation.copy; // Reordenar posición
          }
        }
        return DropOperation.none;
      },
      onPerformDrop: (event) async {
        final item = event.session.items.first;
        if (item.localData is Map) {
          final data = item.localData as Map;
          final draggedId = data['id'];
          final draggedType = data['type'];
          if (isFolder && draggedType == 'file') {
            onMoveToFolder?.call(data['doc'], data['tableName'], details['id']);
          } else {
            onReorder?.call(draggedId, details['id']);
          }
        }
      },
      child: cardContent,
    );

    // Envolvemos el DropRegion con los widgets de arrastre para que la tarjeta sea bidireccional
    if (AccessControl.canManageFiles) {
      return DragItemWidget(
        dragItemProvider: (request) {
          final item = DragItem(localData: {'id': details['id'], 'tableName': tableName, 'type': isFolder ? 'folder' : 'file', 'doc': details});
          item.add(Formats.plainText(name)); // Formato genérico obligatorio para que el OS inicie el drag
          return item;
        },
        allowedOperations: () => [DropOperation.copy, DropOperation.move],
        child: DraggableWidget(child: dropRegion),
      );
    }

    return dropRegion;
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

/// Widget que muestra una vista previa ampliada de la imagen al pasar el ratón por encima (Hover)
class ImageHoverPreview extends StatefulWidget {
  final Uint8List imageBytes;
  final Widget child;

  const ImageHoverPreview({super.key, required this.imageBytes, required this.child});

  @override
  State<ImageHoverPreview> createState() => _ImageHoverPreviewState();
}

class _ImageHoverPreviewState extends State<ImageHoverPreview> {
  OverlayEntry? _overlayEntry;
  Timer? _hideTimer;

  void _showOverlay(BuildContext context) {
    _hideTimer?.cancel();
    _hideTimer = null;

    if (_overlayEntry != null) return;

    // Usamos post frame para evitar colisiones con el LayoutBuilder durante Drag & Drop
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _overlayEntry != null) return;

      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final offset = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      final screenSize = MediaQuery.of(context).size;

      const double previewSize = 400.0;

      double left = offset.dx + size.width + 16;
      double top = offset.dy - (previewSize / 2) + (size.height / 2);

      if (left + previewSize > screenSize.width) {
        left = offset.dx - previewSize - 16;
      }

      if (top < 16) top = 16;
      if (top + previewSize > screenSize.height) top = screenSize.height - previewSize - 16;

      _overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: left,
          top: top,
          child: IgnorePointer(
            child: Material(
              elevation: 16,
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: previewSize,
                  height: previewSize,
                  color: Theme.of(context).cardColor,
                  child: Image.memory(widget.imageBytes, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        ),
      );

      Overlay.of(context).insert(_overlayEntry!);
    });
  }

  void _hideOverlay() {
    _hideTimer?.cancel();
    // Añadimos un pequeño retraso antes de ocultar para evitar parpadeos
    // si el ratón sale y vuelve a entrar en milisegundos.
    _hideTimer = Timer(const Duration(milliseconds: 150), () {
      if (_overlayEntry != null) {
        _overlayEntry!.remove();
        _overlayEntry = null;
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(onEnter: (_) => _showOverlay(context), onExit: (_) => _hideOverlay(), child: widget.child);
  }
}
