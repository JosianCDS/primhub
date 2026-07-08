import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/api/global_cache.dart';
import 'package:primhub/api/token.dart';
import 'package:primhub/api/api_utils.dart';

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

    // Animación base ajustada al máximo permitido (8 segundos).
    _progressController = AnimationController(vsync: this, duration: const Duration(seconds: 8));

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

    if (Token.auth != null && Token.auth!.isNotEmpty) {
      final payload = Token.decodePayload(Token.auth!);
      if (payload.containsKey('exp')) {
        final exp = payload['exp'] as int;
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (now >= exp) {
          final refreshed = await handleTokenRefresh();
          if (!refreshed) {
            return;
          }
        }
      }
    }

    // 2. Fase 1 (Datos Esenciales): Esperamos a que termine. Es vital para que 
    // la app no muestre listas vacías en dispositivos móviles más lentos.
    await GlobalCache.syncData(force: true);

    // 3. Fase 2 (Datos Históricos): Le damos un tiempo límite razonable en el splash. 
    // Si excede este tiempo, navegará al Home y la carga continuará en background.
    final phase2Future = () async {
      if (GlobalCache.phase2SyncFuture != null) {
        await GlobalCache.phase2SyncFuture;
      }
    }();

    await Future.any([phase2Future, Future.delayed(const Duration(seconds: 8))]);

    if (mounted) {
      if (_progressController.value < 1.0) {
        await _progressController.animateTo(1.0, duration: const Duration(milliseconds: 50), curve: Curves.easeOut);
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
