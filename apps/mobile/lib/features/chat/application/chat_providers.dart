import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatMessage {
  const ChatMessage(
    this.text, {
    this.system = false,
    this.sender = 'system',
    this.isMine = false,
    this.pulse = false,
  });
  final String text;
  final bool system;
  final String sender;
  final bool isMine;
  final bool pulse;
}

final groupChatProvider = StateProvider<List<ChatMessage>>((ref) {
  return const [
    ChatMessage('Riya joined the radar', system: true),
    ChatMessage('I am at the food court entrance', sender: 'Sreejith'),
    ChatMessage('omw, 45m out', sender: 'You', isMine: true),
    ChatMessage('Arjun is waiting at current location', sender: 'Arjun', pulse: true),
  ];
});
