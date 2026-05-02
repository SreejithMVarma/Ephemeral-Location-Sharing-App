import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../main.dart';
import '../domain/radar_message.dart';
import 'api_client.dart';

class NetworkException implements Exception {
  NetworkException(this.message);
  final String message;
}

final connectivityStateProvider = StreamProvider<ConnectivityResult>((ref) {
  final connectivity = Connectivity();
  return connectivity.onConnectivityChanged.map((list) {
    if (list.isEmpty) {
      return ConnectivityResult.none;
    }
    return list.first;
  });
});

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['X-Request-ID'] = DateTime.now().microsecondsSinceEpoch.toString();
        handler.next(options);
      },
      onError: (error, handler) {
        handler.reject(
          DioException(
            requestOptions: error.requestOptions,
            message: 'Network request failed',
            response: error.response,
            type: error.type,
          ),
        );
      },
    ),
  );

  return dio;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return DioApiClient(ref.watch(dioProvider));
});

class RadarWebSocketService {
  RadarWebSocketService(this._url);

  final String _url;
  WebSocketChannel? _channel;
  final _controller = StreamController<RadarMessage>.broadcast();

  Stream<RadarMessage> get messages => _controller.stream;

  Future<void> connect({int retries = 5}) async {
    var attempt = 0;
    while (attempt < retries) {
      try {
        _channel = WebSocketChannel.connect(Uri.parse(_url));
        _channel!.stream.listen(
          (event) {
            try {
              if (event is String) {
                final parsed = jsonDecode(event) as Map<String, dynamic>;
                _controller.add(RadarMessage.fromJson(parsed));
              } else if (event is Map<String, dynamic>) {
                _controller.add(RadarMessage.fromJson(event));
              }
            } catch (e) {
              debugPrint('Error parsing WS message: $e');
            }
          },
          onError: (Object e) {
            debugPrint('WS stream error: $e');
          },
          onDone: () {
            debugPrint('WS stream closed');
          },
          cancelOnError: false,
        );
        return;
      } catch (e) {
        attempt += 1;
        final backoff = Duration(seconds: attempt > 5 ? 30 : attempt);
        await Future<void>.delayed(backoff);
      }
    }
    throw NetworkException('WebSocket reconnect limit reached');
  }

  /// Send a message to the server. The [json] map is encoded to a JSON string
  /// because the backend expects `receive_text()` / `json.loads()`.
  void send(Map<String, dynamic> json) {
    _channel?.sink.add(jsonEncode(json));
  }

  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
  }
}

/// Per-session WebSocket service. Key is the full WS URL including path and
/// query string, e.g. `ws://10.0.2.2:8000/ws/<sessionId>?token=<userId>`.
final radarWebSocketServiceProvider =
    Provider.family<RadarWebSocketService, String>((ref, wsUrl) {
  return RadarWebSocketService(wsUrl);
});

final appLifecycleObserverProvider = Provider<AppLifecycleObserver>((ref) {
  return AppLifecycleObserver();
});

// TODO: Re-enable in V2
class NotificationService {
  NotificationService();

  Future<void> requestJoinPermission() async {
    // MVP: Notifications disabled - stub implementation
  }

  Future<String?> currentToken() async {
    // MVP: Firebase disabled - return null
    return null;
  }

  void bindTokenRefresh({required String sessionId, required String userId}) {
    // MVP: Token refresh disabled - stub implementation
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class AppLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // MVP: No special lifecycle handling needed
  }
}
