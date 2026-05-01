import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class ForegroundTrackingService {
  Future<void> start(String sessionName) async {
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      return;
    }

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'radar_tracking_channel',
        channelName: 'Radar Tracking',
        channelDescription: 'Radar active: sharing location',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
      ),
    );

    await FlutterForegroundTask.startService(
      serviceId: 1101,
      notificationTitle: 'Radar active',
      notificationText: 'Sharing location with $sessionName',
      notificationInitialRoute: '/',
    );
  }

  Future<void> stop() async {
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      await FlutterForegroundTask.stopService();
    }
  }
}
