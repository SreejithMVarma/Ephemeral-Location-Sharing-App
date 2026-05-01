import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/session_cache.dart';

class LocalStorageService {
  LocalStorageService(this._secureStorage, this._prefs);

  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;

  static const _sessionCacheKey = 'session_cache';
  static const _privacyModeKey = 'default_privacy_mode';

  Future<void> saveSession(SessionCache cache) async {
    await _secureStorage.write(
      key: _sessionCacheKey,
      value: jsonEncode(cache.toJson()),
    );
  }

  Future<SessionCache?> readSession() async {
    final raw = await _secureStorage.read(key: _sessionCacheKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return SessionCache.fromJson(decoded);
  }

  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
  }

  Future<void> setDefaultPrivacyMode(String mode) async {
    await _prefs.setString(_privacyModeKey, mode);
  }

  String getDefaultPrivacyMode() {
    return _prefs.getString(_privacyModeKey) ?? 'direction_distance';
  }
}
