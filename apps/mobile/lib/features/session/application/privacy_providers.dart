import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/telemetry/telemetry_service.dart';
import 'rejoin_service.dart';

enum PrivacyMode {
  directionOnly,
  directionDistance,
  fullMap,
}

final privacyModeProvider = StateProvider<PrivacyMode>((ref) => PrivacyMode.directionDistance);

final applyPrivacyModeProvider = Provider<Future<void> Function(PrivacyMode)>((ref) {
  return (mode) async {
    ref.read(privacyModeProvider.notifier).state = mode;
    final storage = await ref.read(localStorageServiceProvider.future);
    await storage.setDefaultPrivacyMode(mode.name);
    await TelemetryService.logEvent(
      'privacy_mode_changed',
      parameters: {'mode': mode.name},
    );
  };
});
