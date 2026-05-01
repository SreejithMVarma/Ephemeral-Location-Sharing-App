import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/session_cache.dart';
import '../infrastructure/local_storage_service.dart';

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

final localStorageServiceProvider = FutureProvider<LocalStorageService>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  return LocalStorageService(secureStorage, prefs);
});

final rejoinCacheProvider = FutureProvider<SessionCache?>((ref) async {
  final storage = await ref.watch(localStorageServiceProvider.future);
  final cache = await storage.readSession();
  if (cache == null) {
    return null;
  }

  if (cache.authToken.isEmpty || cache.sessionId.isEmpty) {
    await storage.clearAll();
    return null;
  }
  return cache;
});

/// Provider for session history (all previously joined sessions, sorted by most recent first)
final sessionHistoryProvider = FutureProvider<List<SessionCache>>((ref) async {
  final storage = await ref.watch(localStorageServiceProvider.future);
  return storage.readSessionHistory();
});
