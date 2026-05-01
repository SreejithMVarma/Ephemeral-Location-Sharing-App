import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../domain/location_mode.dart';

class LocationService {
  StreamSubscription<Position>? _subscription;
  final _controller = StreamController<Position>.broadcast();

  Stream<Position> get stream => _controller.stream;

  LocationSettings _settingsForMode(LocationMode mode) {
    switch (mode) {
      case LocationMode.compass:
        return const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 2,
        );
      case LocationMode.background:
        return const LocationSettings(
          accuracy: LocationAccuracy.low,
          distanceFilter: 30,
        );
      case LocationMode.radar:
        return const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 10,
        );
    }
  }

  Future<void> start(LocationMode mode) async {
    await _subscription?.cancel();
    _subscription = Geolocator.getPositionStream(locationSettings: _settingsForMode(mode)).listen((position) {
      if (position.accuracy <= 50) {
        _controller.add(position);
      }
    });
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
