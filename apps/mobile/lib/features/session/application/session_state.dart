import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Session information for the current active session
class SessionState {
  const SessionState({
    required this.sessionId,
    required this.sessionName,
    required this.userId,
    required this.displayName,
    required this.privacyMode,
  });

  final String sessionId;
  final String sessionName;
  final String userId;
  final String displayName;
  final String privacyMode;

  SessionState copyWith({
    String? sessionId,
    String? sessionName,
    String? userId,
    String? displayName,
    String? privacyMode,
  }) {
    return SessionState(
      sessionId: sessionId ?? this.sessionId,
      sessionName: sessionName ?? this.sessionName,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      privacyMode: privacyMode ?? this.privacyMode,
    );
  }
}

/// Notifier for managing current session state
class SessionStateNotifier extends StateNotifier<SessionState?> {
  SessionStateNotifier() : super(null);

  void setSession({
    required String sessionId,
    required String sessionName,
    required String userId,
    required String displayName,
    required String privacyMode,
  }) {
    state = SessionState(
      sessionId: sessionId,
      sessionName: sessionName,
      userId: userId,
      displayName: displayName,
      privacyMode: privacyMode,
    );
  }

  void updateSessionName(String name) {
    if (state != null) {
      state = state!.copyWith(sessionName: name);
    }
  }

  void clearSession() {
    state = null;
  }
}

/// Provider for managing session state
final sessionStateProvider = StateNotifierProvider<SessionStateNotifier, SessionState?>((ref) {
  return SessionStateNotifier();
});
