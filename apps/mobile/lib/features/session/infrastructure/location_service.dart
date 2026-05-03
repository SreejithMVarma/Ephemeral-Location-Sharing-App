import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'session_location_logger.dart';
import '../domain/location_mode.dart';

class LocationService {
  StreamSubscription<Position>? _subscription;
  final _controller = StreamController<Position>.broadcast();

  Stream<Position> get stream => _controller.stream;

  LocationSettings _settingsForMode(LocationMode mode) {
    switch (mode) {
      case LocationMode.compass:
        return const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 1, // 1m for compass — sub-metre updates
        );
      case LocationMode.background:
        return const LocationSettings(
          accuracy: LocationAccuracy.low,
          distanceFilter: 30,
        );
      case LocationMode.radar:
        return const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // 5m — catch every meaningful move
        );
    }
  }

  Future<void> start(LocationMode mode) async {
    await _subscription?.cancel();
    _subscription = Geolocator.getPositionStream(locationSettings: _settingsForMode(mode)).listen((position) {
      if (position.accuracy <= 80) {
        debugPrint('[LocationService] 📍 lat=${position.latitude.toStringAsFixed(6)}, lng=${position.longitude.toStringAsFixed(6)}, accuracy=${position.accuracy.toStringAsFixed(1)}m, mode=$mode');
        SessionLocationLogger.logOwnLocation(
          userId: 'self',
          lat: position.latitude,
          lng: position.longitude,
          accuracy: position.accuracy,
          speed: position.speed,
          heading: position.heading,
        );
        _controller.add(position);
      } else {
        debugPrint('[LocationService] ⚠️ Ignored fix — accuracy too low (${position.accuracy.toStringAsFixed(1)}m > 80m)');
        SessionLocationLogger.logRejectedFix(
          userId: 'self',
          lat: position.latitude,
          lng: position.longitude,
          accuracy: position.accuracy,
        );
      }
    });
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
