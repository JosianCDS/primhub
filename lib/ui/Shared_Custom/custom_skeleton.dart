import 'package:flutter/material.dart';

/// Widget base para el efecto Skeleton (Shimmer animado)
class CustomSkeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxShape shape;

  const CustomSkeleton({super.key, this.width, this.height, this.borderRadius = 8.0, this.shape = BoxShape.rectangle});

  @override
  State<CustomSkeleton> createState() => _CustomSkeletonState();
}

class _CustomSkeletonState extends State<CustomSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surfaceContainerHighest.withOpacity(0.3);
    final highlightColor = theme.colorScheme.surfaceContainerHighest.withOpacity(0.8);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(color: Color.lerp(baseColor, highlightColor, _controller.value), shape: widget.shape, borderRadius: widget.shape == BoxShape.rectangle ? BorderRadius.circular(widget.borderRadius) : null),
        );
      },
    );
  }
}

/// Plantilla para simular una Tabla cargando (Soporte, Detalles, Tareas)
class SkeletonTable extends StatelessWidget {
  const SkeletonTable({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CustomSkeleton(height: 40, width: double.infinity, borderRadius: 12),
          const SizedBox(height: 16),
          ...List.generate(
            6,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  const CustomSkeleton(height: 30, width: 40),
                  const SizedBox(width: 16),
                  const Expanded(flex: 2, child: CustomSkeleton(height: 30)),
                  const SizedBox(width: 16),
                  const Expanded(flex: 3, child: CustomSkeleton(height: 30)),
                  const SizedBox(width: 16),
                  const CustomSkeleton(height: 30, width: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Plantilla para simular una Lista cargando (Mis Proyectos)
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: 16.0),
        child: CustomSkeleton(height: 85, width: double.infinity, borderRadius: 12),
      ),
    );
  }
}
