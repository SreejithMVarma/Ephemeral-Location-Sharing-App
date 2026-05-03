import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/navigation/app_router.dart';
import 'core/navigation/deep_link_service.dart';
import 'core/app_config.dart';
import 'core/startup/app_startup_orchestrator.dart';
import 'core/theme/app_theme.dart';
import 'features/radar/application/radar_providers.dart';
import 'features/session/application/session_state.dart';
import 'features/session/infrastructure/foreground_tracking_service.dart';
import 'features/session/infrastructure/location_broadcaster.dart';
import 'features/session/infrastructure/network_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Eagerly capture initial deep link BEFORE runApp to avoid cold-launch race.
    // app_links requires this to be called as early as possible.
    Uri? initialDeepLink;
    try {
      initialDeepLink = await AppLinks().getInitialLink();
    } catch (_) {}

    final config = AppConfig.fromDartDefines();
    const buildFlavor = String.fromEnvironment('APP_FLAVOR', defaultValue: 'development');
    const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0');
    final startup = AppStartupOrchestrator(
      appVersion: appVersion,
      buildFlavor: buildFlavor,
    );

    await startup.bootstrapCritical();

    runApp(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          // Pre-seed any cold-launch deep link so the router sees it immediately.
          if (initialDeepLink != null &&
              initialDeepLink.scheme == 'radarapp' &&
              initialDeepLink.host == 'join')
            pendingDeepLinkProvider.overrideWith((ref) => initialDeepLink),
        ],
        child: const MyApp(),
      ),
    );

    startup.scheduleDeferredWarmup();
  } catch (e, st) {
    runApp(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: Text('Startup error:\n$e\n\n$st')))));
  }
}

final appConfigProvider = Provider<AppConfig>((_) {
  throw UnimplementedError('AppConfig must be injected from main()');
});

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  AppLifecycleObserver? _observer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final observer = ref.read(appLifecycleObserverProvider);
      _observer = observer;
      WidgetsBinding.instance.addObserver(observer);

      // Initialize deep link handling (background/foreground stream only —
      // the initial link was already captured in main() before runApp).
      ref.read(deepLinkServiceProvider).initStream();
    });
  }

  @override
  void dispose() {
    final observer = _observer;
    if (observer != null) {
      WidgetsBinding.instance.removeObserver(observer);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to session state to manage background location broadcasting lifecycle
    ref.listen(sessionStateProvider, (previous, next) {
      if (previous == null && next != null) {
        // Session started: start foreground service, connect WS, and broadcast GPS
        ref.read(foregroundTrackingServiceProvider).start(next.sessionName);
        ref.read(radarWsLifecycleProvider.notifier).connect();
        ref.read(locationBroadcasterProvider)?.start(next.sessionId);
      } else if (previous != null && next == null) {
        // Session ended: stop foreground service, disconnect WS, and stop GPS broadcast
        ref.read(foregroundTrackingServiceProvider).stop();
        ref.read(radarWsLifecycleProvider.notifier).disconnect();
        ref.read(locationBroadcasterProvider)?.stop();
      }
    });

    final router = ref.watch(appRouterProvider);
    final config = ref.watch(appConfigProvider);

    return MaterialApp.router(
      title: 'Ephemeral Radar',
      theme: AppTheme.dark(),
      routerConfig: router,
      builder: (context, child) {
        return Column(
          children: [
            Expanded(child: child ?? const SizedBox.shrink()),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'API: ${config.apiBaseUrl}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        );
      },
    );
  }
}
