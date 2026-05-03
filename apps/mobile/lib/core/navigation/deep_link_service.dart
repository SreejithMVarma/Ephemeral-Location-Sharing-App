import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the deep link that has been captured but not yet processed.
final pendingDeepLinkProvider = StateProvider<Uri?>((ref) => null);

/// Provides the deep link service singleton
final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  return DeepLinkService(ref);
});

class DeepLinkService {
  DeepLinkService(this._ref);

  final Ref _ref;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  /// Subscribe to the ongoing deep link stream for foreground/background launches.
  ///
  /// The cold-launch initial URI is captured eagerly in `main()` before
  /// `runApp()` to avoid the race where the router initialises before this
  /// service has had a chance to call [AppLinks.getInitialLink].
  void initStream() {
    try {
      _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
        _handleDeepLink(uri);
      }, onError: (err) {
        debugPrint('Deep link stream error: $err');
      });
    } catch (e) {
      debugPrint('Failed to initialize DeepLinkService stream: $e');
    }
  }

  /// Full init — fetches the initial link AND subscribes to the stream.
  /// Use only in tests or when you cannot call [getInitialLink] from main().
  Future<void> init() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
      initStream();
    } catch (e) {
      debugPrint('Failed to initialize DeepLinkService: $e');
    }
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('[DeepLinkService] Captured: $uri');

    if (uri.scheme == 'radarapp' && uri.host == 'join') {
      _ref.read(pendingDeepLinkProvider.notifier).state = uri;
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
