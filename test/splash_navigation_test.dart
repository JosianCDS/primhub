import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:primhub/api/session_manager.dart';
import 'package:primhub/api/splash_loading_page.dart';
import 'package:primhub/api/token.dart';

void main() {
  testWidgets('splash navigates after its first frame', (tester) async {
    Token.auth = 'e30.eyJleHAiOjQxMDI0NDQ4MDB9.signature';
    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(path: '/splash', builder: (_, _) => const SplashLoadingPage()),
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Dashboard listo')),
        ),
        GoRoute(path: '/login', builder: (_, _) => const SizedBox()),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump();

    expect(find.text('Dashboard listo'), findsOneWidget);
    expect(tester.takeException(), isNull);

    SessionManager().stopKeepAliveTimer();
    Token.auth = null;
    router.dispose();
  });
}
