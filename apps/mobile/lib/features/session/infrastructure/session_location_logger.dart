import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Writes structured location events to a per-session log file in the app's
/// documents directory.
///
/// File path: <Documents>/ephemeral_logs/session_<id>_<date>.log
///
/// Each line is a CSV row:
///   timestamp,event,userId,lat,lng,accuracy,speed,bearing
class SessionLocationLogger {
  SessionLocationLogger._();

  static IOSink? _sink;
  static String? _activeSessionId;

  /// Open (or re-open) the log file for [sessionId].
  /// Safe to call multiple times — reopens only if sessionId changed.
  static Future<void> openSession(String sessionId) async {
    if (_activeSessionId == sessionId && _sink != null) return;
    await closeSession(); // flush & close any previous session

    _activeSessionId = sessionId;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${dir.path}/ephemeral_logs');
      if (!logDir.existsSync()) logDir.createSync(recursive: true);

      final date = DateTime.now().toLocal();
      final stamp =
          '${date.year.toString().padLeft(4, '0')}'
          '${date.month.toString().padLeft(2, '0')}'
          '${date.day.toString().padLeft(2, '0')}';
      final file = File('${logDir.path}/session_${sessionId}_$stamp.log');

      _sink = file.openWrite(mode: FileMode.append);

      // Header if file is new
      if (file.lengthSync() == 0) {
        _sink!.writeln('timestamp,event,userId,lat,lng,accuracy_m,speed_mps,heading_deg');
      }
      _sink!.writeln('${_ts()},SESSION_OPEN,$sessionId,,,,, ');
      debugPrint('[SessionLogger] Opened log: ${file.path}');
    } catch (e) {
      debugPrint('[SessionLogger] Could not open log file: $e');
    }
  }

  /// Log a location broadcast (own device sending to server).
  static void logOwnLocation({
    required String userId,
    required double lat,
    required double lng,
    required double accuracy,
    required double speed,
    required double heading,
  }) {
    _write('OWN_LOCATION', userId, lat, lng, accuracy, speed, heading);
  }

  /// Log a received location update from a peer.
  static void logPeerLocation({
    required String userId,
    required double lat,
    required double lng,
    double accuracy = 0,
    double speed = 0,
    double heading = 0,
  }) {
    _write('PEER_LOCATION', userId, lat, lng, accuracy, speed, heading);
  }

  /// Log a rejected GPS fix (accuracy too low).
  static void logRejectedFix({
    required String userId,
    required double lat,
    required double lng,
    required double accuracy,
  }) {
    _write('REJECTED_FIX', userId, lat, lng, accuracy, 0, 0);
  }

  /// Log a SESSION_ENDED event.
  static void logSessionEnded(String sessionId) {
    if (_sink == null) return;
    _sink!.writeln('${_ts()},SESSION_ENDED,$sessionId,,,,, ');
  }

  static void _write(
    String event,
    String userId,
    double lat,
    double lng,
    double accuracy,
    double speed,
    double heading,
  ) {
    if (_sink == null) return;
    final line =
        '${_ts()},$event,$userId,${lat.toStringAsFixed(8)},${lng.toStringAsFixed(8)},'
        '${accuracy.toStringAsFixed(1)},${speed.toStringAsFixed(2)},${heading.toStringAsFixed(1)}';
    _sink!.writeln(line); // written to file only
  }

  static String _ts() => DateTime.now().toUtc().toIso8601String();

  /// Flush and close the current log file.
  static Future<void> closeSession() async {
    if (_sink != null) {
      await _sink!.flush();
      await _sink!.close();
      _sink = null;
    }
    _activeSessionId = null;
  }

  /// Returns the path of the log directory for display / sharing.
  static Future<String?> logDirectory() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/ephemeral_logs';
    } catch (_) {
      return null;
    }
  }
}
