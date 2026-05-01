import 'dart:io';

import 'package:dio/dio.dart';

class ErrorMessages {
  static String fromException(Object error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionError || error.error is SocketException) {
        return 'Cannot reach the backend. Start the backend and Redis, then try again.';
      }

      final detail = _extractBackendDetail(error.response?.data);
      if (detail != null && detail.isNotEmpty) {
        return detail;
      }
    }

    if (error is SocketException) {
      return 'Cannot reach the backend. Start the backend and Redis, then try again.';
    }

    if (error is StateError && error.message.isNotEmpty) {
      return error.message;
    }

    return 'Something went wrong. Please try again.';
  }

  static String? _extractBackendDetail(Object? payload) {
    if (payload is Map) {
      final detail = payload['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
      final error = payload['error'];
      if (error is String && error.isNotEmpty) {
        return error;
      }
    }
    if (payload is String && payload.isNotEmpty) {
      return payload;
    }
    return null;
  }

  static const sessionNotFound = 'This radar is no longer active.';
  static const networkUnavailable = 'No network connection. Please check your internet.';
}
