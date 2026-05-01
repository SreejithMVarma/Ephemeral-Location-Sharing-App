import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../infrastructure/compass_service.dart';

final compassServiceProvider = Provider<CompassService>((ref) {
  final service = CompassService();
  ref.onDispose(() {
    service.stop();
  });
  return service;
});
