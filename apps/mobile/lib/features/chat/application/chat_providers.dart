import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../session/application/session_state.dart';
import '../../session/domain/radar_message.dart';
import '../../session/infrastructure/network_providers.dart';
import '../../radar/application/radar_providers.dart';

// ---------------------------------------------------------------------------
// Domain model
// ---------------------------------------------------------------------------

class ChatMessage {
  const ChatMessage({
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.isMine,
    this.chatType = 'global',
    this.targetUserId,
    this.isPulsePing = false,
  });

  final String senderId;
  final String senderName;
  final String text;
  final String timestamp;
  final bool isMine;
  final String chatType; // 'global' | 'dm'
  final String? targetUserId;
  final bool isPulsePing;
}

// ---------------------------------------------------------------------------
// Group Chat Notifier
// ---------------------------------------------------------------------------

class GroupChatNotifier extends StateNotifier<List<ChatMessage>> {
  GroupChatNotifier(this._ref) : super([]) {
    // Listen for incoming WS chat messages
    _ref.listen<RadarMessage?>(
      incomingChatMessageProvider,
      (_, msg) {
        if (msg == null) return;
        if (msg.type != RadarMessageType.chatMessage) return;
        final payload = msg.payload;
        final chatType = payload['chat_type'] as String? ?? 'global';
        if (chatType != 'global') return;

        final session = _ref.read(sessionStateProvider);
        final isMine = msg.senderId == (session?.userId ?? '');
        // Avoid duplicates: we already add optimistically when sending
        if (isMine) return;

        final incoming = ChatMessage(
          senderId: msg.senderId,
          senderName: payload['sender_name'] as String? ?? msg.senderId,
          text: payload['text'] as String? ?? '',
          timestamp: msg.timestamp,
          isMine: false,
          chatType: 'global',
          isPulsePing: payload['is_pulse_ping'] as bool? ?? false,
        );
        state = [...state, incoming];
        debugPrint('[GroupChat] Received message from ${msg.senderId}');
      },
    );
  }

  final Ref _ref;

  void sendMessage(String text, {bool isPulsePing = false}) {
    final session = _ref.read(sessionStateProvider);
    if (session == null || text.trim().isEmpty) return;

    final now = DateTime.now().toUtc().toIso8601String();
    final msg = ChatMessage(
      senderId: session.userId,
      senderName: session.displayName,
      text: text.trim(),
      timestamp: now,
      isMine: true,
      chatType: 'global',
      isPulsePing: isPulsePing,
    );

    // Optimistic local update
    state = [...state, msg];

    // Send via WebSocket
    _sendViaWs(session, {
      'type': 'CHAT_MESSAGE',
      'sender_id': session.userId,
      'timestamp': now,
      'payload': {
        'chat_type': 'global',
        'text': text.trim(),
        'sender_name': session.displayName,
        'is_pulse_ping': isPulsePing,
      },
    });
  }

  void _sendViaWs(dynamic session, Map<String, dynamic> envelope) {
    final baseUrl = (session.wsUrl as String).endsWith('/')
        ? (session.wsUrl as String).substring(0, (session.wsUrl as String).length - 1)
        : session.wsUrl as String;
    final path = baseUrl.endsWith('/ws') ? '/${session.sessionId}' : '/ws/${session.sessionId}';
    final wsUrl = '$baseUrl$path?token=${session.userId}';
    final wsService = _ref.read(radarWebSocketServiceProvider(wsUrl));
    wsService.send(envelope);
  }
}

final groupChatProvider =
    StateNotifierProvider<GroupChatNotifier, List<ChatMessage>>((ref) {
  return GroupChatNotifier(ref);
});

// ---------------------------------------------------------------------------
// DM Chat Notifier (family — one per peer userId)
// ---------------------------------------------------------------------------

class DmChatNotifier extends StateNotifier<List<ChatMessage>> {
  DmChatNotifier(this._ref, this._peerId) : super([]) {
    _ref.listen<RadarMessage?>(
      incomingChatMessageProvider,
      (_, msg) {
        if (msg == null) return;
        if (msg.type != RadarMessageType.chatMessage) return;
        final payload = msg.payload;
        final chatType = payload['chat_type'] as String? ?? 'global';
        if (chatType != 'dm') return;

        final session = _ref.read(sessionStateProvider);
        final myId = session?.userId ?? '';
        final targetId = payload['target_user_id'] as String? ?? '';

        // Accept only messages involving this peer conversation
        final isFromPeer = msg.senderId == _peerId && targetId == myId;
        final isMyEcho = msg.senderId == myId && targetId == _peerId;
        if (!isFromPeer && !isMyEcho) return;
        if (isMyEcho) return; // Already added optimistically

        final incoming = ChatMessage(
          senderId: msg.senderId,
          senderName: payload['sender_name'] as String? ?? msg.senderId,
          text: payload['text'] as String? ?? '',
          timestamp: msg.timestamp,
          isMine: false,
          chatType: 'dm',
          targetUserId: _peerId,
        );
        state = [...state, incoming];
        debugPrint('[DmChat] Received DM from ${msg.senderId}');
      },
    );
  }

  final Ref _ref;
  final String _peerId;

  void sendMessage(String text, String peerDisplayName) {
    final session = _ref.read(sessionStateProvider);
    if (session == null || text.trim().isEmpty) return;

    final now = DateTime.now().toUtc().toIso8601String();
    final msg = ChatMessage(
      senderId: session.userId,
      senderName: session.displayName,
      text: text.trim(),
      timestamp: now,
      isMine: true,
      chatType: 'dm',
      targetUserId: _peerId,
    );

    state = [...state, msg];

    final baseUrl = session.wsUrl.endsWith('/')
        ? session.wsUrl.substring(0, session.wsUrl.length - 1)
        : session.wsUrl;
    final path = baseUrl.endsWith('/ws') ? '/${session.sessionId}' : '/ws/${session.sessionId}';
    final wsUrl = '$baseUrl$path?token=${session.userId}';
    final wsService = _ref.read(radarWebSocketServiceProvider(wsUrl));
    wsService.send({
      'type': 'CHAT_MESSAGE',
      'sender_id': session.userId,
      'timestamp': now,
      'payload': {
        'chat_type': 'dm',
        'text': text.trim(),
        'sender_name': session.displayName,
        'target_user_id': _peerId,
        'target_name': peerDisplayName,
      },
    });
  }
}

final dmChatProvider =
    StateNotifierProvider.family<DmChatNotifier, List<ChatMessage>, String>((ref, peerId) {
  return DmChatNotifier(ref, peerId);
});

// ---------------------------------------------------------------------------
// Unread badge counts
// ---------------------------------------------------------------------------

final groupUnreadProvider = StateProvider<int>((ref) => 0);
final dmUnreadProvider = StateProvider.family<int, String>((ref, peerId) => 0);
