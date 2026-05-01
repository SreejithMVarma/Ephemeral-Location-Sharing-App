import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/location_mode.dart';
import '../infrastructure/location_service.dart';
import '../infrastructure/permission_service.dart';

final permissionServiceProvider = Provider<PermissionService>((ref) => PermissionService());
final locationServiceProvider = Provider<LocationService>((ref) => LocationService());
final locationModeProvider = StateProvider<LocationMode>((ref) => LocationMode.radar);

final backgroundPermissionProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(permissionServiceProvider);
  return service.hasBackgroundLocation();
});
