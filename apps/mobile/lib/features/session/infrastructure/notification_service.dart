import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_client.dart';

class NotificationService {
  NotificationService(this._apiClient);

  final ApiClient _apiClient;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  StreamSubscription<String>? _refreshSubscription;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    FirebaseMessaging.onMessage.listen((message) async {
      final type = message.data['type']?.toString();
      if (type == 'NEW_LOCATION_DATA') {
        await _showSilentWakeHint();
      }
    });

    _initialized = true;
  }

  Future<void> requestJoinPermission() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true, provisional: false);
  }

  Future<String?> currentToken() {
    return _messaging.getToken();
  }

  Future<void> registerJoinToken({
    required String sessionId,
    required String userId,
  }) async {
    final token = await currentToken();
    if (token == null || token.isEmpty) {
      return;
    }

    await _apiClient.postJson(
      '/api/v1/sessions/$sessionId/device-token',
      body: {
        'user_id': userId,
        'fcm_token': token,
      },
    );
  }

  void bindTokenRefresh({
    required String sessionId,
    required String userId,
  }) {
    _refreshSubscription?.cancel();
    _refreshSubscription = _messaging.onTokenRefresh.listen((token) {
      _apiClient.postJson(
        '/api/v1/sessions/$sessionId/device-token',
        body: {
          'user_id': userId,
          'fcm_token': token,
        },
      );
    });
  }

  Future<void> dispose() async {
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;
  }

  Future<void> _showSilentWakeHint() async {
    await _localNotifications.show(
      1001,
      'Radar sync',
      'Updating nearby locations',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'radar_silent_sync',
          'Radar Silent Sync',
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
        ),
        iOS: DarwinNotificationDetails(presentAlert: false, presentBadge: false, presentSound: false),
      ),
    );
  }
}
