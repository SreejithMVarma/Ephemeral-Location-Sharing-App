import 'dart:async';

class AppStartupOrchestrator {
  AppStartupOrchestrator({
    required this.appVersion,
    required this.buildFlavor,
  });

  final String appVersion;
  final String buildFlavor;

  Future<void> bootstrapCritical() async {
    // MVP: No critical bootstrap needed
  }

  void scheduleDeferredWarmup() {
    // MVP: No deferred initialization needed
  }
}
