enum RadarMessageType {
  locationUpdate,
  userConnected,
  userDisconnected,
  sessionEnded,
  chatMessage,
  pulsePing,
  privacyUpdate,
  ping,
  pong,
  rateLimited,
}

class RadarMessage {
  const RadarMessage({
    required this.type,
    required this.payload,
    required this.senderId,
    required this.timestamp,
  });

  final RadarMessageType type;
  final Map<String, dynamic> payload;
  final String senderId;
  final String timestamp;

  factory RadarMessage.fromJson(Map<String, dynamic> json) {
    final raw = (json['type'] as String? ?? '').toUpperCase();
    final type = switch (raw) {
      'LOCATION_UPDATE' => RadarMessageType.locationUpdate,
      'USER_CONNECTED' => RadarMessageType.userConnected,
      'USER_DISCONNECTED' => RadarMessageType.userDisconnected,
      'SESSION_ENDED' => RadarMessageType.sessionEnded,
      'CHAT_MESSAGE' => RadarMessageType.chatMessage,
      'PULSE_PING' => RadarMessageType.pulsePing,
      'PRIVACY_UPDATE' => RadarMessageType.privacyUpdate,
      'PING' => RadarMessageType.ping,
      'PONG' => RadarMessageType.pong,
      'RATE_LIMITED' => RadarMessageType.rateLimited,
      _ => RadarMessageType.chatMessage,
    };
    return RadarMessage(
      type: type,
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? {},
      senderId: (json['sender_id'] as String?) ?? '',
      timestamp: (json['timestamp'] as String?) ?? '',
    );
  }
}
