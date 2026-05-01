import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/core/app_config.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('App renders entry screen with injected config', (WidgetTester tester) async {
    const config = AppConfig(
      apiBaseUrl: 'https://api.radarapp.io',
      fcmSenderId: '1234567890',
      deepLinkScheme: 'radarapp',
      regionWsUrls: {'us-east': 'wss://api.radarapp.io/ws'},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
        ],
        child: const MyApp(),
      ),
    );

    expect(find.text('Radar'), findsOneWidget);
    expect(find.textContaining('https://api.radarapp.io'), findsOneWidget);
  });

  testWidgets('GoRouter redirects unknown unauthenticated route to entry', (WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/private',
      redirect: (context, state) {
        const isAuthed = false;
        if (!isAuthed && state.uri.path != '/') {
          return '/';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Entry Screen')),
        ),
        GoRoute(
          path: '/private',
          builder: (context, state) => const Scaffold(body: Text('Private Screen')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.pumpAndSettle();
    expect(find.text('Entry Screen'), findsOneWidget);
    expect(find.text('Private Screen'), findsNothing);
  });
}
