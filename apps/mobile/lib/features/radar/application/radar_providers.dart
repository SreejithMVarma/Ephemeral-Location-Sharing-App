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
import '../../session/infrastructure/session_location_logger.dart';
import '../domain/radar_blip.dart';

// ---------------------------------------------------------------------------
// Session-ended flag — set true when backend sends SESSION_ENDED
// ---------------------------------------------------------------------------

final sessionEndedProvider = StateProvider<bool>((ref) => false);

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
  bool _isPaused = true;

  void setPaused(bool paused) {
    _isPaused = paused;
  }

  void _init() {
    // Seed from HTTP snapshot
    _ref.listen<AsyncValue<Map<String, RadarBlip>>>(
      liveRadarBlipsProvider,
      (_, next) {
        next.whenData((snapshot) {
          // Merge: WS live data wins over HTTP snapshot.
          // Build a map starting with snapshot entries, then for any key already
          // in state (from WS), keep the WS blip — preserving computed distance,
          // bearing, and remoteLat/Lng that the snapshot never includes.
          final merged = <String, RadarBlip>{...snapshot};
          for (final entry in state.entries) {
            merged[entry.key] = entry.value; // WS data overwrites snapshot
          }
          state = merged;
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

    final baseUrl = session.wsUrl.endsWith('/')
        ? session.wsUrl.substring(0, session.wsUrl.length - 1)
        : session.wsUrl;
    final path = baseUrl.endsWith('/ws') ? '/${session.sessionId}' : '/ws/${session.sessionId}';
    final wsUrl = '$baseUrl$path?token=${session.userId}';

    final wsService = _ref.read(radarWebSocketServiceProvider(wsUrl));

    _wsSub?.cancel();
    _wsSub = wsService.messages.listen(
      _handleMessage,
      onError: (Object e) => debugPrint('[WS] error: $e'),
    );

    // Actually open the WebSocket connection (was missing — caused no peer data)
    wsService.connect().then((_) {
      debugPrint('[WS] connected: $wsUrl');
    }).catchError((Object e) {
      debugPrint('[WS] connect failed: $e');
    });
  }

  void _handleMessage(RadarMessage msg) {
    // Log every incoming WS message so we can confirm the receive path is alive.
    debugPrint('[WS-RX] type=${msg.type.name} sender=${msg.senderId}');

    switch (msg.type) {
      case RadarMessageType.locationUpdate:
        if (_isPaused) {
          debugPrint('[WS-RX] LOCATION_UPDATE dropped — radar is paused');
          return;
        }
        _applyLocationUpdate(msg);
      case RadarMessageType.userDisconnected:
        final userId = msg.payload['user_id'] as String?;
        if (userId != null && userId.isNotEmpty) {
          final updated = Map<String, RadarBlip>.from(state);
          updated.remove(userId);
          state = updated;
          debugPrint('[WS-RX] user disconnected: $userId');
        }
      case RadarMessageType.privacyUpdate:
        _applyPrivacyUpdate(msg);
      case RadarMessageType.sessionEnded:
        debugPrint('[WS-RX] SESSION_ENDED from server');
        _ref.read(sessionEndedProvider.notifier).state = true;
      case RadarMessageType.chatMessage:
        _ref.read(incomingChatMessageProvider.notifier).state = msg;
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

    // Log peer location to per-session file
    SessionLocationLogger.logPeerLocation(
      userId: senderId,
      lat: remoteLat,
      lng: remoteLng,
      accuracy: (payload['accuracy'] as num?)?.toDouble() ?? 0,
      speed: (payload['speed'] as num?)?.toDouble() ?? 0,
      heading: (payload['heading'] as num?)?.toDouble() ?? 0,
    );

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

    debugPrint(
      '[PEER] $displayName  lat=${remoteLat.toStringAsFixed(6)}'
      ' lng=${remoteLng.toStringAsFixed(6)}'
      ' dist=${distance.toStringAsFixed(0)}m'
      ' bearing=${bearing.toStringAsFixed(1)}deg',
    );

    final updated = Map<String, RadarBlip>.from(state);
    updated[senderId] = RadarBlip(
      userId: senderId,
      displayName: displayName,
      bearing: bearing,
      distanceMeters: distance,
      directionOnly: directionOnly,
      remoteLat: remoteLat,
      remoteLng: remoteLng,
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
    updated[userId] = existing.copyWith(directionOnly: mode == 'direction_only');
    state = updated;
  }

  /// Recompute bearing + distance for every existing blip when own position changes.
  void _recomputeAllDistances(Position ownPos) {
    if (state.isEmpty) return;

    bool changed = false;
    final updated = Map<String, RadarBlip>.from(state);
    final recomputed = <String>[];

    for (final entry in state.entries) {
      final blip = entry.value;
      if (blip.remoteLat == null || blip.remoteLng == null) continue;

      final newBearing = haversineBearing(
        ownPos.latitude,
        ownPos.longitude,
        blip.remoteLat!,
        blip.remoteLng!,
      );
      final newDistance = haversineDistance(
        ownPos.latitude,
        ownPos.longitude,
        blip.remoteLat!,
        blip.remoteLng!,
      );

      updated[entry.key] = blip.copyWith(
        bearing: newBearing,
        distanceMeters: newDistance,
      );
      recomputed.add('${blip.displayName.isNotEmpty ? blip.displayName : blip.userId}: ${newDistance.toStringAsFixed(1)}m @ ${newBearing.toStringAsFixed(1)}°');
      changed = true;
    }

    if (changed) {
      state = updated;
    }
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
class RadarWsLifecycle extends StateNotifier<bool> {
  RadarWsLifecycle(this._ref) : super(false);

  final Ref _ref;
  RadarWebSocketService? _wsService;

  Future<void> connect() async {
    if (state) return;
    final session = _ref.read(sessionStateProvider);
    if (session == null || session.wsUrl.isEmpty) {
      debugPrint('[RadarWsLifecycle] no session or wsUrl — skipping connect');
      return;
    }

    final baseUrl = session.wsUrl.endsWith('/')
        ? session.wsUrl.substring(0, session.wsUrl.length - 1)
        : session.wsUrl;
    final path = baseUrl.endsWith('/ws') ? '/${session.sessionId}' : '/ws/${session.sessionId}';
    final wsUrl = '$baseUrl$path?token=${session.userId}';

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
// Incoming chat message passthrough (listened to by chat providers)
// ---------------------------------------------------------------------------

/// Each time a CHAT_MESSAGE arrives via WS, this is set to the latest message.
/// Chat providers listen to this to update their state.
final incomingChatMessageProvider = StateProvider<RadarMessage?>((ref) => null);

// ---------------------------------------------------------------------------
// Blip providers (downstream consumers of RadarBlipsNotifier)
// ---------------------------------------------------------------------------

/// HTTP snapshot — fetches initial member list.
const _emptyBlips = <String, RadarBlip>{};

final liveRadarBlipsProvider =
    FutureProvider<Map<String, RadarBlip>>((ref) async {
  final session = ref.watch(sessionStateProvider);
  if (session == null) return _emptyBlips;

  final api = ref.watch(apiClientProvider);

  try {
    final response = await retryWithBackoff(
      task: () => api.getJsonList(
        '/api/v1/sessions/${session.sessionId}/members',
        query: {'p': session.passkey},
      ),
    );

    final blips = <String, RadarBlip>{};

    for (final memberData in response) {
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
    debugPrint('[liveRadarBlipsProvider] Error fetching blips: $e');
    return _emptyBlips;
  }
});

/// Live blip map driven by WS updates (primary source during a session).
final radarBlipsProvider =
    StateNotifierProvider<RadarBlipsNotifier, Map<String, RadarBlip>>((ref) {
  return RadarBlipsNotifier(ref);
});
