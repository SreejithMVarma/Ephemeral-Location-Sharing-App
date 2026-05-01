class SessionCache {
  const SessionCache({
    required this.sessionId,
    required this.authToken,
    required this.sessionName,
    required this.joinedAt,
  });

  final String sessionId;
  final String authToken;
  final String sessionName;
  final String joinedAt;

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'auth_token': authToken,
    'session_name': sessionName,
    'joined_at': joinedAt,
  };

  factory SessionCache.fromJson(Map<String, dynamic> json) {
    return SessionCache(
      sessionId: (json['session_id'] as String?) ?? '',
      authToken: (json['auth_token'] as String?) ?? '',
      sessionName: (json['session_name'] as String?) ?? '',
      joinedAt: (json['joined_at'] as String?) ?? '',
    );
  }
}
