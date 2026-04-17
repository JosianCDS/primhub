import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/api/global_cache.dart';

class SplashLoadingPage extends StatefulWidget {
  const SplashLoadingPage({super.key});

  @override
  State<SplashLoadingPage> createState() => _SplashLoadingPageState();
}

class _SplashLoadingPageState extends State<SplashLoadingPage> with SingleTickerProviderStateMixin {
  String _loadingMessage = "Conectando con el servidor...";
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    // Animación base. Si la data carga rápido, la aceleraremos.
    _progressController = AnimationController(vsync: this, duration: const Duration(seconds: 4));

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _progressController, curve: Curves.easeOutQuart));

    _startSync();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _startSync() async {
    // 1. Inicia la animación para que el usuario vea el progreso.
    _progressController.forward();

    // 2. Carga los datos esenciales (Fase 1: rápida).
    await GlobalCache.syncData();

    if (mounted) {
      // 3. Acelera la animación para que llegue al 100% de inmediato y sin esperas innecesarias.
      if (_progressController.value < 1.0) {
        await _progressController.animateTo(1.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
      // 4. Navega a la pantalla principal.
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [theme.colorScheme.surface, theme.colorScheme.surfaceContainerLow]),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                  child: Padding(padding: const EdgeInsets.all(12.0), child: Image.asset('assets/LogoPrimHub.png')),
                ),
                const SizedBox(height: 40),
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return LinearProgressIndicator(value: _progressAnimation.value, borderRadius: BorderRadius.circular(8), minHeight: 6);
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  _loadingMessage,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
