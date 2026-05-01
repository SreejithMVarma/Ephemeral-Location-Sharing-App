import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/session_cache.dart';

class LocalStorageService {
  LocalStorageService(this._secureStorage, this._prefs);

  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;

  static const _sessionCacheKey = 'session_cache';
  static const _sessionHistoryKey = 'session_history';
  static const _privacyModeKey = 'default_privacy_mode';

  /// Save current session (also adds to history)
  Future<void> saveSession(SessionCache cache) async {
    await _secureStorage.write(
      key: _sessionCacheKey,
      value: jsonEncode(cache.toJson()),
    );
    // Also add to history
    await _addToSessionHistory(cache);
  }

  /// Add a session to the history list
  Future<void> _addToSessionHistory(SessionCache cache) async {
    final history = await readSessionHistory();
    
    // Remove duplicate if it exists (same sessionId)
    history.removeWhere((s) => s.sessionId == cache.sessionId);
    
    // Add the new session to the front
    history.insert(0, cache);
    
    // Keep only last 10 sessions
    if (history.length > 10) {
      history.removeLast();
    }
    
    await _secureStorage.write(
      key: _sessionHistoryKey,
      value: jsonEncode(history.map((s) => s.toJson()).toList()),
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

  /// Read all session history (sorted by most recent first)
  Future<List<SessionCache>> readSessionHistory() async {
    final raw = await _secureStorage.read(key: _sessionHistoryKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => SessionCache.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Remove a session from history
  Future<void> removeFromHistory(String sessionId) async {
    final history = await readSessionHistory();
    history.removeWhere((s) => s.sessionId == sessionId);
    
    await _secureStorage.write(
      key: _sessionHistoryKey,
      value: jsonEncode(history.map((s) => s.toJson()).toList()),
    );
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
