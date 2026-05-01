import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error_handling/retry.dart';
import '../../session/application/session_state.dart';
import '../../session/infrastructure/network_providers.dart';
import '../domain/radar_blip.dart';

/// Dummy blips - used when no live data is available
/// TODO: Remove after WebSocket integration is complete
const _dummyBlips = {
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

/// Fetches blips from the backend API
final liveRadarBlipsProvider = FutureProvider<Map<String, RadarBlip>>((ref) async {
  final session = ref.watch(sessionStateProvider);
  if (session == null) {
    return _dummyBlips;
  }

  final api = ref.watch(apiClientProvider);

  try {
    final response = await retryWithBackoff(
      task: () => api.getJson('/api/v1/sessions/${session.sessionId}/members'),
    );

    final membersData = response['members'] as List? ?? [];
    final blips = <String, RadarBlip>{};

    for (final memberData in membersData) {
      if (memberData is! Map<String, dynamic>) continue;

      final userId = memberData['user_id'] as String?;
      final displayName = memberData['display_name'] as String? ?? 'Unknown';
      final bearing = (memberData['bearing'] as num?)?.toDouble() ?? 0.0;
      final distance = (memberData['distance_meters'] as num?)?.toDouble() ?? 0.0;
      final privacyMode = memberData['privacy_mode'] as String? ?? 'direction_only';

      if (userId != null && userId.isNotEmpty) {
        blips[userId] = RadarBlip(
          userId: userId,
          displayName: displayName,
          bearing: bearing,
          distanceMeters: distance,
          directionOnly: privacyMode == 'direction_only',
        );
      }
    }

    return blips.isNotEmpty ? blips : _dummyBlips;
  } catch (e) {
    print('Error fetching blips: $e');
    return _dummyBlips;
  }
});

/// Provides live blips from WebSocket or API polling
final radarBlipsProvider = StateProvider<Map<String, RadarBlip>>((ref) {
  // Watch the API provider for updates
  final liveFuture = ref.watch(liveRadarBlipsProvider);

  // Return data when loaded, or dummy data while loading
  return liveFuture.when(
    data: (data) => data,
    loading: () => _dummyBlips,
    error: (error, stackTrace) => _dummyBlips,
  );
});

final radarBlipIdsProvider = Provider<List<String>>((ref) {
  return ref.watch(radarBlipsProvider.select((map) => map.keys.toList()));
});

final radarBlipProvider = Provider.family<RadarBlip?, String>((ref, userId) {
  return ref.watch(radarBlipsProvider.select((map) => map[userId]));
});
