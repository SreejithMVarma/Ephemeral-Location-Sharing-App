import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> hasForegroundLocation() async {
    final status = await Permission.locationWhenInUse.status;
    return status.isGranted;
  }

  Future<bool> hasBackgroundLocation() async {
    final status = await Permission.locationAlways.status;
    return status.isGranted;
  }

  Future<bool> requestForegroundLocation() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  Future<bool> requestBackgroundLocation() async {
    final status = await Permission.locationAlways.request();
    return status.isGranted;
  }

  Future<void> openSettings() => openAppSettings();
}
