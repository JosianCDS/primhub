import 'package:flutter/material.dart';

typedef DeferredWidgetBuilder = Widget Function();

class DeferredRoutePage extends StatefulWidget {
  const DeferredRoutePage({
    required this.loadLibrary,
    required this.builder,
    super.key,
  });

  final Future<void> Function() loadLibrary;
  final DeferredWidgetBuilder builder;

  @override
  State<DeferredRoutePage> createState() => _DeferredRoutePageState();
}

class _DeferredRoutePageState extends State<DeferredRoutePage> {
  late Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = widget.loadLibrary();
  }

  void _retry() {
    setState(() => _loadFuture = widget.loadLibrary());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return widget.builder();
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 44),
                    const SizedBox(height: 16),
                    const Text(
                      'No se pudo cargar esta sección.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _retry,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
