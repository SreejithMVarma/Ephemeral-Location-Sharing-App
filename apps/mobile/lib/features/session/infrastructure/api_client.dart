import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

abstract class ApiClient {
  Future<Map<String, dynamic>> getJson(String path, {Map<String, dynamic>? query});
  Future<Map<String, dynamic>> postJson(String path, {Map<String, dynamic>? body});
}

class DioApiClient implements ApiClient {
  DioApiClient(this._dio) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final startedAt = DateTime.now();
          options.extra['startedAt'] = startedAt;
          debugPrint('[API] --> ${options.method} ${options.uri}');
          if (options.data != null) {
            debugPrint('[API] request body: ${options.data}');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          final startedAt = response.requestOptions.extra['startedAt'] as DateTime?;
          final elapsedMs = startedAt == null ? null : DateTime.now().difference(startedAt).inMilliseconds;
          debugPrint('[API] <-- ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri}${elapsedMs == null ? '' : ' (${elapsedMs}ms)'}');
          debugPrint('[API] response body: ${response.data}');
          handler.next(response);
        },
        onError: (error, handler) {
          final startedAt = error.requestOptions.extra['startedAt'] as DateTime?;
          final elapsedMs = startedAt == null ? null : DateTime.now().difference(startedAt).inMilliseconds;
          debugPrint('[API] xx ${error.requestOptions.method} ${error.requestOptions.uri}${elapsedMs == null ? '' : ' (${elapsedMs}ms)'}');
          debugPrint('[API] error type: ${error.type} status: ${error.response?.statusCode} message: ${error.message}');
          if (error.response?.data != null) {
            debugPrint('[API] error body: ${error.response?.data}');
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;

  @override
  Future<Map<String, dynamic>> getJson(String path, {Map<String, dynamic>? query}) async {
    final response = await _dio.get(path, queryParameters: query);
    return (response.data as Map).cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> postJson(String path, {Map<String, dynamic>? body}) async {
    final response = await _dio.post(path, data: body);
    return (response.data as Map).cast<String, dynamic>();
  }
}
