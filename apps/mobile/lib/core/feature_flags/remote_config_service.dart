import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  RemoteConfigService(this._remoteConfig);

  final FirebaseRemoteConfig _remoteConfig;
  bool _configured = false;

  Future<void> initialize() async {
    if (!_configured) {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );

      await _remoteConfig.setDefaults(const {
        'chat_enabled_global': true,
        'max_session_size': 50,
        'proximity_alert_threshold_meters': 20,
        'radar_radius_meters': 200,
      });
      _configured = true;
    }

    await fetchAndActivate();
  }

  Future<void> fetchAndActivate() async {
    try {
      await _remoteConfig.fetchAndActivate();
    } catch (_) {
      // Keep feature flags best-effort to avoid blocking app interaction.
    }
  }

  bool get chatEnabledGlobal => _remoteConfig.getBool('chat_enabled_global');
  int get maxSessionSize => _remoteConfig.getInt('max_session_size');
  int get proximityAlertThreshold => _remoteConfig.getInt('proximity_alert_threshold_meters');
  int get radarRadiusMeters => _remoteConfig.getInt('radar_radius_meters');
}
