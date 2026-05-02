class SessionCache {
  const SessionCache({
    required this.sessionId,
    required this.authToken,
    required this.sessionName,
    required this.joinedAt,
    this.isCreatedByMe = false,
    this.adminId = '',
    this.displayName = '',
    this.privacyMode = 'direction_distance',
    this.deepLinkUrl = '',
  });

  final String sessionId;
  final String authToken;
  final String sessionName;
  final String joinedAt;
  final bool isCreatedByMe;
  final String adminId;
  final String displayName;
  final String privacyMode;
  final String deepLinkUrl;

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'auth_token': authToken,
    'session_name': sessionName,
    'joined_at': joinedAt,
    'is_created_by_me': isCreatedByMe,
    'admin_id': adminId,
    'display_name': displayName,
    'privacy_mode': privacyMode,
    'deep_link_url': deepLinkUrl,
  };

  factory SessionCache.fromJson(Map<String, dynamic> json) {
    return SessionCache(
      sessionId: (json['session_id'] as String?) ?? '',
      authToken: (json['auth_token'] as String?) ?? '',
      sessionName: (json['session_name'] as String?) ?? '',
      joinedAt: (json['joined_at'] as String?) ?? '',
      isCreatedByMe: (json['is_created_by_me'] as bool?) ?? false,
      adminId: (json['admin_id'] as String?) ?? '',
      displayName: (json['display_name'] as String?) ?? '',
      privacyMode: (json['privacy_mode'] as String?) ?? 'direction_distance',
      deepLinkUrl: (json['deep_link_url'] as String?) ?? '',
    );
  }
}
