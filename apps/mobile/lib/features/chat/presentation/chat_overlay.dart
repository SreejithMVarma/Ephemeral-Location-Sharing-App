// chat_overlay.dart is superseded by chat_screen.dart.
// This file is kept as a no-op stub to avoid import errors from existing code
// that may reference ChatOverlay. The actual chat UI lives in chat_screen.dart.
import 'package:flutter/material.dart';

/// Legacy stub — no longer renders anything.
/// Use ChatScreen.show(context) from chat_screen.dart instead.
class ChatOverlay extends StatelessWidget {
  const ChatOverlay({super.key, this.defaultDmUserId});
  final String? defaultDmUserId;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
