import 'dart:math';
import 'package:flutter/foundation.dart';

Future<T> retryWithBackoff<T>({
  required Future<T> Function() task,
  int maxRetries = 3,
  Duration maxDelay = const Duration(seconds: 30),
  String operationName = 'operation',
}) async {
  var attempt = 0;
  Object? lastError;
  while (attempt <= maxRetries) {
    try {
      debugPrint('[Retry] $operationName attempt ${attempt + 1}/${maxRetries + 1}');
      return await task();
    } catch (error) {
      lastError = error;
      debugPrint('[Retry] $operationName failed on attempt ${attempt + 1}: $error');
      if (attempt == maxRetries) {
        debugPrint('[Retry] $operationName giving up after ${attempt + 1} attempts');
        rethrow;
      }
      final base = min(pow(2, attempt).toInt(), maxDelay.inSeconds);
      final jitterMs = Random().nextInt(300);
      debugPrint('[Retry] $operationName waiting ${base}s + ${jitterMs}ms before retry');
      await Future<void>.delayed(Duration(seconds: base, milliseconds: jitterMs));
      attempt += 1;
    }
  }
  throw lastError ?? StateError('retry failed');
}
