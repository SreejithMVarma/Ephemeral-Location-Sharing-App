import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/theme/app_tokens.dart';
import '../../radar/application/radar_providers.dart';
import '../../session/domain/radar_message.dart';
import '../../session/application/session_state.dart';
import '../../session/infrastructure/network_providers.dart';

class FullMapView extends ConsumerStatefulWidget {
  const FullMapView({super.key});

  @override
  ConsumerState<FullMapView> createState() => _FullMapViewState();
}

class _FullMapViewState extends ConsumerState<FullMapView> {
  MapboxMap? _mapboxMap;
  StreamSubscription<RadarMessage>? _wsSub;
  Timer? _viewportDebounce;
  bool _styleReady = false;
  String? _boundSessionId;
  String? _boundWsUrl;
  final Map<String, Map<String, dynamic>> _pointsById = {};

  @override
  void dispose() {
    _viewportDebounce?.cancel();
    _wsSub?.cancel();
    super.dispose();
  }

  void _bindToSession(SessionState session) {
    if (_boundSessionId == session.sessionId && _boundWsUrl == session.wsUrl) {
      return;
    }
    _boundSessionId = session.sessionId;
    _boundWsUrl = session.wsUrl;

    final baseUrl = session.wsUrl.endsWith('/')
        ? session.wsUrl.substring(0, session.wsUrl.length - 1)
        : session.wsUrl;
    final path = baseUrl.endsWith('/ws')
        ? '/${session.sessionId}'
        : '/ws/${session.sessionId}';
    final wsUrl = '$baseUrl$path?token=${session.userId}';
    final wsService = ref.read(radarWebSocketServiceProvider(wsUrl));

    _wsSub?.cancel();
    _wsSub = wsService.messages.listen(_handleWsMessage);
    wsService.connect().catchError((error) {
      debugPrint('[FullMap] WebSocket connect failed: $error');
    });
  }

  void _handleWsMessage(RadarMessage msg) {
    switch (msg.type) {
      case RadarMessageType.viewportSnapshot:
        final users = (msg.payload['users'] as List<dynamic>?) ?? const [];
        _pointsById.clear();
        for (final user in users) {
          if (user is! Map<String, dynamic>) continue;
          final id = (user['id'] as String?) ?? '';
          final lat = (user['lat'] as num?)?.toDouble();
          final lng = (user['lng'] as num?)?.toDouble();
          if (id.isEmpty || lat == null || lng == null) continue;
          _pointsById[id] = {
            'id': id,
            'lat': lat,
            'lng': lng,
            'display_name': user['display_name'] ?? id,
            'is_self': id == ref.read(sessionStateProvider)?.userId,
          };
        }
        _syncSource();
        break;
      case RadarMessageType.viewportDiff:
      case RadarMessageType.locationUpdate:
        _applyPoint(msg);
        break;
      case RadarMessageType.userDisconnected:
        final userId = msg.payload['user_id'] as String?;
        if (userId != null) {
          _pointsById.remove(userId);
          _syncSource();
        }
        break;
      default:
        break;
    }
  }

  void _applyPoint(RadarMessage msg) {
    final id = msg.senderId;
    if (id.isEmpty) return;
    final lat = (msg.payload['lat'] as num?)?.toDouble();
    final lng = (msg.payload['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    _pointsById[id] = {
      'id': id,
      'lat': lat,
      'lng': lng,
      'display_name': msg.payload['display_name'] ?? id,
      'is_self': _boundSessionId != null && id == ref.read(sessionStateProvider)?.userId,
    };
    _syncSource();
  }

  Future<void> _syncSource() async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null || !_styleReady) return;

    final featureJson = _buildFeatureCollectionJson();
    try {
      final source = await mapboxMap.style.getSource('full-map-users');
      if (source is GeoJsonSource) {
        await source.updateGeoJSON(featureJson);
      }
    } catch (error) {
      debugPrint('[FullMap] Failed to sync source: $error');
    }
  }

  String _buildFeatureCollectionJson() {
    final features = _pointsById.values.map((point) {
      return {
        'type': 'Feature',
        'properties': {
          'id': point['id'],
          'display_name': point['display_name'],
          'is_self': point['is_self'],
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [point['lng'], point['lat']],
        },
      };
    }).toList(growable: false);

    return jsonEncode({
      'type': 'FeatureCollection',
      'features': features,
    });
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData data) async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;

    final source = GeoJsonSource(
      id: 'full-map-users',
      data: _buildFeatureCollectionJson(),
      cluster: true,
      clusterRadius: 60.0,
      clusterMaxZoom: 14.0,
      clusterMinPoints: 2.0,
      generateId: true,
    );
    await mapboxMap.style.addSource(source);

    await mapboxMap.style.addLayer(
      CircleLayer(
        id: 'full-map-clusters',
        sourceId: 'full-map-users',
        filter: ['has', 'point_count'],
        circleColor: const Color(0xFF0EA5E9).toARGB32(),
        circleOpacity: 0.92,
        circleRadiusExpression: [
          'step',
          ['get', 'point_count'],
          18,
          10,
          24,
          30,
          32,
        ],
        circleStrokeColor: AppColors.white.toARGB32(),
        circleStrokeWidth: 2,
      ),
    );

    await mapboxMap.style.addLayer(
      SymbolLayer(
        id: 'full-map-cluster-count',
        sourceId: 'full-map-users',
        filter: ['has', 'point_count'],
        textFieldExpression: [
          'format',
          ['get', 'point_count_abbreviated'],
          {},
        ],
        textSize: 14,
        textColor: AppColors.white.toARGB32(),
        textAllowOverlap: true,
        textIgnorePlacement: true,
        textAnchor: TextAnchor.CENTER,
        textJustify: TextJustify.CENTER,
      ),
    );

    await mapboxMap.style.addLayer(
      CircleLayer(
        id: 'full-map-self',
        sourceId: 'full-map-users',
        filter: [
          'all',
          ['!', ['has', 'point_count']],
          ['==', ['get', 'is_self'], true],
        ],
        circleColor: const Color(0xFF10B981).toARGB32(),
        circleOpacity: 1,
        circleRadius: 11,
        circleStrokeColor: AppColors.white.toARGB32(),
        circleStrokeWidth: 3,
      ),
    );

    await mapboxMap.style.addLayer(
      CircleLayer(
        id: 'full-map-others',
        sourceId: 'full-map-users',
        filter: [
          'all',
          ['!', ['has', 'point_count']],
          ['!=', ['get', 'is_self'], true],
        ],
        circleColor: const Color(0xFF0EA5E9).toARGB32(),
        circleOpacity: 0.95,
        circleRadius: 8,
        circleStrokeColor: AppColors.white.toARGB32(),
        circleStrokeWidth: 2,
      ),
    );

    _styleReady = true;
    await _syncSource();
  }

  Future<void> _subscribeViewport() async {
    final mapboxMap = _mapboxMap;
    final session = ref.read(sessionStateProvider);
    if (mapboxMap == null || session == null) return;

    final cameraState = await mapboxMap.getCameraState();
    final camera = CameraOptions(
      center: cameraState.center,
      zoom: cameraState.zoom,
      bearing: cameraState.bearing,
      pitch: cameraState.pitch,
    );
    final bounds = await mapboxMap.coordinateBoundsForCamera(camera);
    final envelope = <String, dynamic>{
      'type': 'VIEWPORT_SUBSCRIBE',
      'sender_id': session.userId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'payload': {
        'bbox': {
          'north': bounds.northeast.coordinates.lat,
          'south': bounds.southwest.coordinates.lat,
          'east': bounds.northeast.coordinates.lng,
          'west': bounds.southwest.coordinates.lng,
        },
        'zoom': cameraState.zoom.round(),
      },
    };
    final wsUrl = _boundWsUrl;
    if (wsUrl == null || wsUrl.isEmpty) return;
    final wsService = ref.read(radarWebSocketServiceProvider(wsUrl));
    wsService.send(envelope);
  }

  Future<void> _zoomBy(double delta) async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;
    final cameraState = await mapboxMap.getCameraState();
    await mapboxMap.easeTo(
      CameraOptions(
        center: cameraState.center,
        zoom: (cameraState.zoom + delta).clamp(0, 22),
        bearing: cameraState.bearing,
        pitch: cameraState.pitch,
      ),
      null,
    );
  }

  Future<void> _centerOnCurrentSession() async {
    final mapboxMap = _mapboxMap;
    final session = ref.read(sessionStateProvider);
    final ownPosition = ref.read(ownPositionProvider);
    if (mapboxMap == null || session == null || ownPosition == null) return;
    final cameraState = await mapboxMap.getCameraState();
    await mapboxMap.easeTo(
      CameraOptions(
        center: Point(
          coordinates: Position(ownPosition.longitude, ownPosition.latitude),
        ),
        zoom: cameraState.zoom,
        bearing: cameraState.bearing,
        pitch: cameraState.pitch,
      ),
      null,
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    final session = ref.read(sessionStateProvider);
    if (session != null) {
      _bindToSession(session);
    }
  }

  void _onCameraIdle() {
    _viewportDebounce?.cancel();
    _viewportDebounce = Timer(const Duration(milliseconds: 250), () {
      _subscribeViewport();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionStateProvider);
    if (session != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _bindToSession(session);
        }
      });
    }

    final token = const String.fromEnvironment('MAPBOX_TOKEN');
    if (token.isNotEmpty) {
      MapboxOptions.setAccessToken(token);
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Full Map'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.white,
      ),
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey('full-map-widget'),
            viewport: CameraViewportState(
              center: Point(coordinates: Position(-122.4194, 37.7749)),
              zoom: 12.0,
            ),
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
            onMapIdleListener: (MapIdleEventData _) => _onCameraIdle(),
            styleUri: MapboxStyles.MAPBOX_STREETS,
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        session?.sessionName ?? 'Live session',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${_pointsById.length} visible',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.green),
                    ),
                    if (session?.isCreatedByMe ?? false) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.blue.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'Creator',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.blue,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'full-map-zoom-in',
                  backgroundColor: AppColors.surface.withValues(alpha: 0.92),
                  foregroundColor: AppColors.white,
                  onPressed: () => _zoomBy(1),
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'full-map-zoom-out',
                  backgroundColor: AppColors.surface.withValues(alpha: 0.92),
                  foregroundColor: AppColors.white,
                  onPressed: () => _zoomBy(-1),
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'full-map-center',
                  backgroundColor: AppColors.blue.withValues(alpha: 0.92),
                  foregroundColor: AppColors.white,
                  onPressed: _centerOnCurrentSession,
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
