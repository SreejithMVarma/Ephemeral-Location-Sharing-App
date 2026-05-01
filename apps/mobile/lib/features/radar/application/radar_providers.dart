import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/radar_blip.dart';

final radarBlipsProvider = StateProvider<Map<String, RadarBlip>>((ref) {
  return const {
    'u1': RadarBlip(
      userId: 'u1',
      displayName: 'Alex',
      bearing: 40,
      distanceMeters: 35,
      directionOnly: false,
    ),
    'u2': RadarBlip(
      userId: 'u2',
      displayName: 'Rina',
      bearing: 240,
      distanceMeters: 90,
      directionOnly: true,
    ),
  };
});

final radarBlipIdsProvider = Provider<List<String>>((ref) {
  return ref.watch(radarBlipsProvider.select((map) => map.keys.toList()));
});

final radarBlipProvider = Provider.family<RadarBlip?, String>((ref, userId) {
  return ref.watch(radarBlipsProvider.select((map) => map[userId]));
});
