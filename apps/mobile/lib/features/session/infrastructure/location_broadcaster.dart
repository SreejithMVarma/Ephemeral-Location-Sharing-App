import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../session/application/location_providers.dart';
import '../../session/application/session_state.dart';
import '../../session/domain/location_mode.dart';
import '../infrastructure/location_service.dart';
import '../infrastructure/network_providers.dart';
import '../infrastructure/session_location_logger.dart';

/// Bridges GPS position fixes to the WebSocket as `LOCATION_UPDATE` envelopes.
///
/// Call [start] when entering the radar and [stop] when leaving to cleanly
/// start and cancel the GPS subscription.
class LocationBroadcaster {
  LocationBroadcaster({
    required LocationService locationService,
    required RadarWebSocketService wsService,
    required String userId,
  })  : _locationService = locationService,
        _wsService = wsService,
        _userId = userId;

  final LocationService _locationService;
  final RadarWebSocketService _wsService;
  final String _userId;

  StreamSubscription<Position>? _sub;

  /// Starts listening to [LocationMode.radar] GPS fixes and broadcasting them.
  Future<void> start(String sessionId) async {
    await stop(); // cancel any previous subscription first
    await SessionLocationLogger.openSession(sessionId);
    // Ensure the WS channel is open before sending any location fixes.
    try {
      await _wsService.connect();
      debugPrint('[ME] WS connected, starting GPS broadcast');
    } catch (e) {
      debugPrint('[ME] WS connect failed: $e — location updates will not be sent');
    }
    await _locationService.start(LocationMode.radar);
    _sub = _locationService.stream.listen(
      _onPosition,
      onError: (Object e) => debugPrint('[ME] GPS error: $e'),
    );
  }

  void _onPosition(Position position) {
    final now = DateTime.now().toUtc().toIso8601String();
    final envelope = <String, dynamic>{
      'type': 'LOCATION_UPDATE',
      'sender_id': _userId,
      'timestamp': now,
      'payload': <String, dynamic>{
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
      },
    };
    debugPrint('[ME] lat=${position.latitude.toStringAsFixed(6)} lng=${position.longitude.toStringAsFixed(6)} acc=${position.accuracy.toStringAsFixed(1)}m');
    // Log to per-session file with real userId
    SessionLocationLogger.logOwnLocation(
      userId: _userId,
      lat: position.latitude,
      lng: position.longitude,
      accuracy: position.accuracy,
      speed: position.speed,
      heading: position.heading,
    );
    _wsService.send(envelope);
  }

  /// Stops the GPS subscription and location service.
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _locationService.stop();
    await SessionLocationLogger.closeSession();
  }
}

// ---------------------------------------------------------------------------
// Haversine helpers (used by RadarBlipsNotifier to compute bearing + distance)
// ---------------------------------------------------------------------------

/// Returns the great-circle distance in metres between two lat/lng points.
double haversineDistance(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const r = 6371000.0; // Earth radius in metres
  final phi1 = _deg2rad(lat1);
  final phi2 = _deg2rad(lat2);
  final dPhi = _deg2rad(lat2 - lat1);
  final dLam = _deg2rad(lng2 - lng1);

  final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
      math.cos(phi1) * math.cos(phi2) * math.sin(dLam / 2) * math.sin(dLam / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

/// Returns the initial bearing in degrees (0-360) from point 1 → point 2.
double haversineBearing(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  final phi1 = _deg2rad(lat1);
  final phi2 = _deg2rad(lat2);
  final dLam = _deg2rad(lng2 - lng1);

  final y = math.sin(dLam) * math.cos(phi2);
  final x = math.cos(phi1) * math.sin(phi2) -
      math.sin(phi1) * math.cos(phi2) * math.cos(dLam);
  final theta = math.atan2(y, x);
  return (_rad2deg(theta) + 360) % 360;
}

double _deg2rad(double deg) => deg * math.pi / 180;
double _rad2deg(double rad) => rad * 180 / math.pi;

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Provides a [LocationBroadcaster] scoped to the current session.
/// Returns null if there is no active session.
final locationBroadcasterProvider = Provider<LocationBroadcaster?>((ref) {
  final session = ref.watch(sessionStateProvider);
  if (session == null) return null;

  final locationService = ref.watch(locationServiceProvider);

  // Use identical URL construction to RadarBlipsNotifier so both share the
  // same radarWebSocketServiceProvider instance (same Provider.family key).
  // This prevents double-connect and ensures the correct wss:// URL is used
  // regardless of whether session.wsUrl already contains the /ws path segment.
  final baseUrl = session.wsUrl.endsWith('/')
      ? session.wsUrl.substring(0, session.wsUrl.length - 1)
      : session.wsUrl;
  final path = baseUrl.endsWith('/ws')
      ? '/${session.sessionId}'
      : '/ws/${session.sessionId}';
  final wsUrl = '$baseUrl$path?token=${session.userId}';

  final wsService = ref.watch(radarWebSocketServiceProvider(wsUrl));

  return LocationBroadcaster(
    locationService: locationService,
    wsService: wsService,
    userId: session.userId,
  );
});
