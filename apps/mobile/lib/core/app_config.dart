import 'dart:convert';
import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.fcmSenderId,
    required this.deepLinkScheme,
    required this.regionWsUrls,
  });

  final String apiBaseUrl;
  final String fcmSenderId;
  final String deepLinkScheme;
  final Map<String, String> regionWsUrls;

  static AppConfig fromDartDefines() {
    final apiBaseUrl = _optional('API_BASE_URL');
    final fcmSenderId = _optional('FCM_SENDER_ID');
    final deepLinkScheme = _optional('DEEP_LINK_SCHEME');
    final regionWsUrlsRaw = _optional('REGION_WS_URLS');

    if (apiBaseUrl.isEmpty) {
      debugPrint('AppConfig: API_BASE_URL is not set via --dart-define');
    }

    final decoded = regionWsUrlsRaw.isEmpty ? <String, dynamic>{} : _parseRegionWsUrls(regionWsUrlsRaw);

    final wsUrls = <String, String>{};
    for (final entry in decoded.entries) {
      final value = entry.value.toString();
      final wsUri = Uri.tryParse(value);
      if (wsUri == null || (!wsUri.isScheme('ws') && !wsUri.isScheme('wss'))) {
        throw FormatException(
          'Invalid WebSocket URL for region ${entry.key}: $value',
        );
      }
      wsUrls[entry.key] = value;
    }

    return AppConfig(
      apiBaseUrl: apiBaseUrl,
      fcmSenderId: fcmSenderId,
      deepLinkScheme: deepLinkScheme,
      regionWsUrls: wsUrls,
    );
  }

  static Map<String, dynamic> _parseRegionWsUrls(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Fall back to a relaxed parser for shell-escaped map syntax.
    }

    final trimmed = raw.trim();
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) {
      throw const FormatException(
        'REGION_WS_URLS must be a JSON object map of region->URL.',
      );
    }

    final inner = trimmed.substring(1, trimmed.length - 1).trim();
    if (inner.isEmpty) {
      return <String, dynamic>{};
    }

    final result = <String, dynamic>{};
    for (final segment in inner.split(',')) {
      final part = segment.trim();
      final separator = part.indexOf(':');
      if (separator <= 0) {
        throw const FormatException(
          'REGION_WS_URLS must be a JSON object map of region->URL.',
        );
      }
      final key = part.substring(0, separator).trim().replaceAll('"', '');
      final value = part.substring(separator + 1).trim().replaceAll('"', '');
      if (key.isEmpty || value.isEmpty) {
        throw const FormatException(
          'REGION_WS_URLS must be a JSON object map of region->URL.',
        );
      }
      result[key] = value;
    }
    return result;
  }

  static String _optional(String key) {
    final value = switch (key) {
      'API_BASE_URL' => const String.fromEnvironment('API_BASE_URL'),
      'FCM_SENDER_ID' => const String.fromEnvironment('FCM_SENDER_ID'),
      'DEEP_LINK_SCHEME' => const String.fromEnvironment('DEEP_LINK_SCHEME'),
      'REGION_WS_URLS' => const String.fromEnvironment('REGION_WS_URLS'),
      _ => '',
    };
    return value;
  }
}
