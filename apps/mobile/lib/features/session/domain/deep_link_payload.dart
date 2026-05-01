import 'dart:convert';

class DeepLinkPayload {
  const DeepLinkPayload({required this.sessionId, required this.passkey, required this.region});

  final String sessionId;
  final String passkey;
  final String region;

  String toMinifiedJson() {
    return jsonEncode({'s': sessionId, 'p': passkey, 'r': region});
  }

  String toLink(String scheme) {
    return '$scheme://join?s=$sessionId&p=$passkey&r=$region';
  }
}
