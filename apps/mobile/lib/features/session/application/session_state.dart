import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Session information for the current active session
class SessionState {
  const SessionState({
    required this.sessionId,
    required this.sessionName,
    required this.userId,
    required this.displayName,
    required this.privacyMode,
    required this.passkey,
    this.wsUrl = '',
    this.isCreatedByMe = false,
    this.adminId = '',
  });

  final String sessionId;
  final String sessionName;
  final String userId;
  final String displayName;
  final String privacyMode;
  final String passkey;

  /// WebSocket base URL returned by the /verify endpoint (e.g. ws://10.0.2.2:8000).
  /// The full connection URL is assembled as: `$wsUrl/ws/$sessionId?token=$userId`.
  final String wsUrl;
  final bool isCreatedByMe;
  final String adminId;

  SessionState copyWith({
    String? sessionId,
    String? sessionName,
    String? userId,
    String? displayName,
    String? privacyMode,
    String? passkey,
    String? wsUrl,
    bool? isCreatedByMe,
    String? adminId,
  }) {
    return SessionState(
      sessionId: sessionId ?? this.sessionId,
      sessionName: sessionName ?? this.sessionName,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      privacyMode: privacyMode ?? this.privacyMode,
      passkey: passkey ?? this.passkey,
      wsUrl: wsUrl ?? this.wsUrl,
      isCreatedByMe: isCreatedByMe ?? this.isCreatedByMe,
      adminId: adminId ?? this.adminId,
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
    required String passkey,
    String wsUrl = '',
    bool isCreatedByMe = false,
    String adminId = '',
  }) {
    state = SessionState(
      sessionId: sessionId,
      sessionName: sessionName,
      userId: userId,
      displayName: displayName,
      privacyMode: privacyMode,
      passkey: passkey,
      wsUrl: wsUrl,
      isCreatedByMe: isCreatedByMe,
      adminId: adminId,
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
