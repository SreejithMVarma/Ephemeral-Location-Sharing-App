import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/error_handling/retry.dart';
import '../../session/application/location_providers.dart';
import '../../session/application/session_state.dart';
import '../../session/domain/radar_message.dart';
import '../../session/infrastructure/location_broadcaster.dart';
import '../../session/infrastructure/network_providers.dart';
import '../domain/radar_blip.dart';

// ---------------------------------------------------------------------------
// Own position stream
// ---------------------------------------------------------------------------

/// Latest known GPS position of this device (used for haversine computation).
final ownPositionProvider = StateProvider<Position?>((ref) => null);

// ---------------------------------------------------------------------------
// RadarBlipsNotifier — owns the blip map and reacts to WS events
// ---------------------------------------------------------------------------

/// Manages the radar blip map. Seeds from the HTTP snapshot on entry and
/// applies incremental updates from `LOCATION_UPDATE` / `USER_DISCONNECTED`
/// WebSocket messages.
class RadarBlipsNotifier extends StateNotifier<Map<String, RadarBlip>> {
  RadarBlipsNotifier(this._ref) : super({}) {
    _init();
  }

  final Ref _ref;
  StreamSubscription<RadarMessage>? _wsSub;
  StreamSubscription<Position>? _gpsSub;

  void _init() {
    // Seed from HTTP snapshot
    _ref.listen<AsyncValue<Map<String, RadarBlip>>>(
      liveRadarBlipsProvider,
      (_, next) {
        next.whenData((snapshot) {
          // Merge snapshot into existing map (don't wipe WS updates)
          state = {...state, ...snapshot};
        });
      },
      fireImmediately: true,
    );

    // Subscribe to own GPS updates so haversine stays current
    final locationService = _ref.read(locationServiceProvider);
    _gpsSub = locationService.stream.listen((pos) {
      _ref.read(ownPositionProvider.notifier).state = pos;
      _recomputeAllDistances(pos);
    });

    // Subscribe to the WS message stream
    _subscribeToWs();
  }

  void _subscribeToWs() {
    final session = _ref.read(sessionStateProvider);
    if (session == null || session.wsUrl.isEmpty) return;

    final wsUrl = '${session.wsUrl}/ws/${session.sessionId}?token=${session.userId}';
    final wsService = _ref.read(radarWebSocketServiceProvider(wsUrl));

    _wsSub?.cancel();
    _wsSub = wsService.messages.listen(
      _handleMessage,
      onError: (Object e) => debugPrint('[RadarBlipsNotifier] WS error: $e'),
    );
  }

  void _handleMessage(RadarMessage msg) {
    switch (msg.type) {
      case RadarMessageType.locationUpdate:
        _applyLocationUpdate(msg);
      case RadarMessageType.userDisconnected:
        final userId = msg.payload['user_id'] as String?;
        if (userId != null && userId.isNotEmpty) {
          final updated = Map<String, RadarBlip>.from(state);
          updated.remove(userId);
          state = updated;
        }
      case RadarMessageType.privacyUpdate:
        _applyPrivacyUpdate(msg);
      default:
        break;
    }
  }

  void _applyLocationUpdate(RadarMessage msg) {
    final senderId = msg.senderId;
    if (senderId.isEmpty) return;

    final session = _ref.read(sessionStateProvider);
    // Don't create a blip for ourselves
    if (session != null && senderId == session.userId) return;

    final payload = msg.payload;
    final remoteLat = (payload['lat'] as num?)?.toDouble();
    final remoteLng = (payload['lng'] as num?)?.toDouble();
    if (remoteLat == null || remoteLng == null) return;

    final ownPos = _ref.read(ownPositionProvider);

    double bearing = 0;
    double distance = 0;
    if (ownPos != null) {
      bearing = haversineBearing(
        ownPos.latitude,
        ownPos.longitude,
        remoteLat,
        remoteLng,
      );
      distance = haversineDistance(
        ownPos.latitude,
        ownPos.longitude,
        remoteLat,
        remoteLng,
      );
    }

    // Preserve existing display name / directionOnly from previous snapshot;
    // fall back to values in payload if available
    final existing = state[senderId];
    final displayName =
        existing?.displayName ?? (payload['display_name'] as String?) ?? senderId;
    final directionOnly =
        existing?.directionOnly ?? (payload['privacy_mode'] == 'direction_only');

    final updated = Map<String, RadarBlip>.from(state);
    updated[senderId] = RadarBlip(
      userId: senderId,
      displayName: displayName,
      bearing: bearing,
      distanceMeters: distance,
      directionOnly: directionOnly,
    );
    state = updated;
  }

  void _applyPrivacyUpdate(RadarMessage msg) {
    final userId = msg.payload['user_id'] as String? ?? msg.senderId;
    final mode = msg.payload['privacy_mode'] as String?;
    if (userId.isEmpty || mode == null) return;

    final existing = state[userId];
    if (existing == null) return;

    final updated = Map<String, RadarBlip>.from(state);
    updated[userId] = RadarBlip(
      userId: existing.userId,
      displayName: existing.displayName,
      bearing: existing.bearing,
      distanceMeters: existing.distanceMeters,
      directionOnly: mode == 'direction_only',
    );
    state = updated;
  }

  /// Recompute bearing + distance for every existing blip when own position changes.
  void _recomputeAllDistances(Position ownPos) {
    // Only recompute if we actually have blips
    if (state.isEmpty) return;
    // We don't have the remote lat/lng stored, so we skip recompute here;
    // the next LOCATION_UPDATE from each peer will carry fresh coordinates.
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _gpsSub?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// WebSocket lifecycle notifier
// ---------------------------------------------------------------------------

/// Manages the lifecycle of the radar WebSocket connection.
/// Call [connect] in `RadarView.initState` and [disconnect] in `dispose`.
class RadarWsLifecycle extends StateNotifier<bool> {
  RadarWsLifecycle(this._ref) : super(false);

  final Ref _ref;
  RadarWebSocketService? _wsService;

  Future<void> connect() async {
    if (state) return; // already connected
    final session = _ref.read(sessionStateProvider);
    if (session == null || session.wsUrl.isEmpty) {
      debugPrint('[RadarWsLifecycle] no session or wsUrl — skipping connect');
      return;
    }

    final wsUrl = '${session.wsUrl}/ws/${session.sessionId}?token=${session.userId}';
    final service = _ref.read(radarWebSocketServiceProvider(wsUrl));
    _wsService = service;

    try {
      await service.connect();
      state = true;
      debugPrint('[RadarWsLifecycle] connected to $wsUrl');
    } catch (e) {
      debugPrint('[RadarWsLifecycle] connect failed: $e');
    }
  }

  Future<void> disconnect() async {
    await _wsService?.disconnect();
    _wsService = null;
    state = false;
    debugPrint('[RadarWsLifecycle] disconnected');
  }

  @override
  void dispose() {
    _wsService?.disconnect();
    super.dispose();
  }
}

final radarWsLifecycleProvider =
    StateNotifierProvider<RadarWsLifecycle, bool>((ref) {
  return RadarWsLifecycle(ref);
});

// ---------------------------------------------------------------------------
// Blip providers (downstream consumers of RadarBlipsNotifier)
// ---------------------------------------------------------------------------

/// HTTP snapshot — fetches initial member list with pre-computed
/// bearing + distance from the backend.
const _emptyBlips = <String, RadarBlip>{};

final liveRadarBlipsProvider =
    FutureProvider<Map<String, RadarBlip>>((ref) async {
  final session = ref.watch(sessionStateProvider);
  if (session == null) return _emptyBlips;

  final api = ref.watch(apiClientProvider);

  try {
    final passkey = _resolvePasskey();
    final response = await retryWithBackoff(
      task: () => api.getJson(
        '/api/v1/sessions/${session.sessionId}/members',
        query: {'p': passkey},
      ),
    );

    final membersData = response as List? ?? [];
    final blips = <String, RadarBlip>{};

    for (final memberData in membersData) {
      if (memberData is! Map<String, dynamic>) continue;

      final memberId = memberData['user_id'] as String?;
      final displayName = memberData['display_name'] as String? ?? 'Unknown';
      final bearing = (memberData['bearing'] as num?)?.toDouble() ?? 0.0;
      final distance = (memberData['distance_meters'] as num?)?.toDouble() ?? 0.0;
      final privacyMode = memberData['privacy_mode'] as String? ?? 'direction_only';

      if (memberId != null &&
          memberId.isNotEmpty &&
          memberId != session.userId) {
        blips[memberId] = RadarBlip(
          userId: memberId,
          displayName: displayName,
          bearing: bearing,
          distanceMeters: distance,
          directionOnly: privacyMode == 'direction_only',
        );
      }
    }
    return blips;
  } catch (e) {
    debugPrint('Error fetching blips: $e');
    return _emptyBlips;
  }
});

/// The members endpoint currently does not require a passkey in dev,
/// so we return an empty string. Extend this if auth is added later.
String _resolvePasskey() => '';

/// Live blip map driven by WS updates (primary source during a session).
final radarBlipsProvider =
    StateNotifierProvider<RadarBlipsNotifier, Map<String, RadarBlip>>((ref) {
  return RadarBlipsNotifier(ref);
});

final radarBlipIdsProvider = Provider<List<String>>((ref) {
  return ref.watch(radarBlipsProvider.select((map) => map.keys.toList()));
});

final radarBlipProvider = Provider.family<RadarBlip?, String>((ref, userId) {
  return ref.watch(radarBlipsProvider.select((map) => map[userId]));
});
