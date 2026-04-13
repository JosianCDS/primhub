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

    // Animación suave que va del 0% al 90% en 18 segundos (50% más lento), ralentizándose al final
    _progressController = AnimationController(vsync: this, duration: const Duration(seconds: 40));

    _progressAnimation = Tween<double>(begin: 0.0, end: 0.97).animate(CurvedAnimation(parent: _progressController, curve: Curves.easeOutQuart));

    _progressController.forward();
    _startSync();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _startSync() async {
    await GlobalCache.syncData(
      force: true,
      onProgress: (message, progress) {
        if (mounted) {
          setState(() {
            _loadingMessage = message;
          });
        }
      },
    );

    if (mounted) {
      // Cuando los datos terminan de cargar, animamos rápidamente el porcentaje restante hasta 100%
      final currentProgress = _progressAnimation.value;
      _progressController.stop();
      _progressController.duration = const Duration(milliseconds: 800);
      _progressAnimation = Tween<double>(begin: currentProgress, end: 1.0).animate(CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic));

      await _progressController.forward(from: 0.0);

      // Micropausa para que el usuario perciba visualmente que la barra llegó al final
      await Future.delayed(const Duration(milliseconds: 200));

      if (mounted) context.go('/');
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
