import 'dart:async';

import 'package:flutter_compass/flutter_compass.dart';

class CompassService {
  StreamSubscription<CompassEvent>? _subscription;
  final _controller = StreamController<double>.broadcast();

  Stream<double> get headingStream => _controller.stream;

  void start() {
    _subscription?.cancel();
    _subscription = FlutterCompass.events?.listen((event) {
      final heading = event.heading;
      if (heading != null) {
        _controller.add(heading);
      }
    });
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
