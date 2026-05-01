class TelemetryService {
  TelemetryService._();

  static Future<void> initialize({
    required String appVersion,
    required String buildFlavor,
    String? sessionId,
  }) async {
    // MVP: Telemetry disabled
  }

  static Future<void> recordError(Object error, StackTrace stackTrace, {bool fatal = false}) async {
    // MVP: Error recording disabled
  }

  static Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    // MVP: Event logging disabled
  }
}
