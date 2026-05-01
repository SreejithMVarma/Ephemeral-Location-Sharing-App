import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/navigation/app_router.dart';
import 'core/app_config.dart';
import 'core/startup/app_startup_orchestrator.dart';
import 'core/theme/app_theme.dart';
import 'features/session/infrastructure/network_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
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
