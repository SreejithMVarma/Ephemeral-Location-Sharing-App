

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../radar/application/radar_providers.dart';
import '../../radar/domain/radar_blip.dart';
import '../application/chat_providers.dart';

// ---------------------------------------------------------------------------
// Entry point — show the chat modal
// ---------------------------------------------------------------------------

class ChatScreen extends ConsumerStatefulWidget {
  /// [initialDmUserId] — if set, opens directly to that user's DM tab.
  const ChatScreen({super.key, this.initialDmUserId});

  final String? initialDmUserId;

  static Future<void> show(BuildContext context, {String? initialDmUserId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChatScreen(initialDmUserId: initialDmUserId),
    );
  }

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<RadarBlip> _peers = [];
  int _activeTab = 0; // 0 = group, 1..n = DM per peer

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this); // rebuilt after peers load
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _rebuildTabs(List<RadarBlip> peers) {
    if (peers.length == _peers.length) return;
    _peers = peers;
    _tabController.dispose();
    _tabController = TabController(
      length: 1 + peers.length,
      vsync: this,
      initialIndex: _activeTab.clamp(0, peers.length),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _activeTab = _tabController.index);
      }
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final blips = ref.watch(radarBlipsProvider);
    final peers = blips.values.toList();
    _rebuildTabs(peers);

    // If initialDmUserId provided, jump to that tab once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialDmUserId != null) {
        final idx = peers.indexWhere((p) => p.userId == widget.initialDmUserId);
        if (idx >= 0 && _tabController.index != idx + 1) {
          _tabController.animateTo(idx + 1);
        }
      }
    });

    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      child: Column(
        children: [
          // Handle bar
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline, color: AppColors.blue, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Chat',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close, color: AppColors.textDim, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Tab bar
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.white.withValues(alpha: 0.06), width: 0.6),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.sm - 2),
                border: Border.all(color: AppColors.blue.withValues(alpha: 0.4), width: 0.8),
              ),
              labelColor: AppColors.blue,
              unselectedLabelColor: AppColors.textDim,
              labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              tabs: [
                const Tab(text: 'Group'),
                ...peers.map((p) => Tab(text: p.displayName.isEmpty ? p.userId : p.displayName)),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _GroupChatTab(),
                ...peers.map((peer) => _DmChatTab(peer: peer)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Group Chat Tab
// ---------------------------------------------------------------------------

class _GroupChatTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_GroupChatTab> createState() => _GroupChatTabState();
}

class _GroupChatTabState extends ConsumerState<_GroupChatTab> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(groupChatProvider);
    _scrollToBottom();

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Text(
                    'No messages yet. Say hello! 👋',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textDim),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _ChatBubble(message: messages[index]);
                  },
                ),
        ),
        _MessageInput(
          controller: _controller,
          onSend: (text) {
            ref.read(groupChatProvider.notifier).sendMessage(text);
            _controller.clear();
          },
          onPulsePing: () {
            ref.read(groupChatProvider.notifier).sendMessage(
              "Pulse ping — I'm at my current location!",
              isPulsePing: true,
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// DM Chat Tab
// ---------------------------------------------------------------------------

class _DmChatTab extends ConsumerStatefulWidget {
  const _DmChatTab({required this.peer});

  final RadarBlip peer;

  @override
  ConsumerState<_DmChatTab> createState() => _DmChatTabState();
}

class _DmChatTabState extends ConsumerState<_DmChatTab> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(dmChatProvider(widget.peer.userId));
    _scrollToBottom();

    return Column(
      children: [
        // Peer header card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.blue.withValues(alpha: 0.2), width: 0.7),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.blue.withValues(alpha: 0.18),
                    border: Border.all(color: AppColors.blue.withValues(alpha: 0.5), width: 1),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.peer.displayName.isEmpty ? '?' : widget.peer.displayName[0].toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.blue, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.peer.displayName.isEmpty ? widget.peer.userId : widget.peer.displayName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${widget.peer.distanceMeters.round()}m away',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.amber),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.green.withValues(alpha: 0.3), width: 0.6),
                  ),
                  child: Text('DIRECT', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.green)),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Text(
                    'No messages yet.\nSay something private! 🔒',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textDim),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _ChatBubble(message: messages[index]);
                  },
                ),
        ),
        _MessageInput(
          controller: _controller,
          onSend: (text) {
            ref.read(dmChatProvider(widget.peer.userId).notifier)
                .sendMessage(text, widget.peer.displayName);
            _controller.clear();
          },
          onPulsePing: null, // No pulse ping in DM
          hintText: 'message ${widget.peer.displayName}...',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable: Chat bubble
// ---------------------------------------------------------------------------

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (message.isPulsePing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Align(
          alignment: Alignment.center,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.amber.withValues(alpha: 0.3), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.radar, color: AppColors.amber, size: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PULSE PING · ${message.senderName}',
                          style: textTheme.labelSmall?.copyWith(color: AppColors.amber)),
                      Text(message.text, style: textTheme.bodySmall?.copyWith(color: AppColors.amber)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final mine = message.isMine;
    final bubbleColor = mine
        ? AppColors.green.withValues(alpha: 0.15)
        : AppColors.surface2;
    final borderColor = mine
        ? AppColors.green.withValues(alpha: 0.25)
        : AppColors.white.withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 3),
                child: Text(
                  message.senderName,
                  style: textTheme.labelSmall?.copyWith(color: AppColors.textDim),
                ),
              ),
            Container(
              constraints: const BoxConstraints(maxWidth: 260),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: mine ? const Radius.circular(14) : const Radius.circular(3),
                  bottomRight: mine ? const Radius.circular(3) : const Radius.circular(14),
                ),
                border: Border.all(color: borderColor, width: 0.8),
              ),
              child: Text(message.text, style: textTheme.bodyMedium),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
              child: Text(
                _formatTime(message.timestamp),
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.textDim.withValues(alpha: 0.5),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }
}

// ---------------------------------------------------------------------------
// Reusable: Message input row
// ---------------------------------------------------------------------------

class _MessageInput extends StatelessWidget {
  const _MessageInput({
    required this.controller,
    required this.onSend,
    this.onPulsePing,
    this.hintText = 'message...',
  });

  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final VoidCallback? onPulsePing;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm + MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          border: Border(top: BorderSide(color: AppColors.white.withValues(alpha: 0.06), width: 0.6)),
        ),
        child: Row(
          children: [
            if (onPulsePing != null) ...[
              GestureDetector(
                onTap: () {
                  HapticFeedback.heavyImpact();
                  onPulsePing!();
                },
                child: Tooltip(
                  message: 'Send pulse ping',
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.amber.withValues(alpha: 0.3), width: 0.7),
                    ),
                    child: const Icon(Icons.radar, color: AppColors.amber, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (text) {
                  if (text.trim().isNotEmpty) {
                    onSend(text);
                  }
                },
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textDim),
                  filled: true,
                  fillColor: AppColors.bg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide(color: AppColors.white.withValues(alpha: 0.1), width: 0.7),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide(color: AppColors.white.withValues(alpha: 0.1), width: 0.7),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide(color: AppColors.blue.withValues(alpha: 0.5), width: 0.8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  HapticFeedback.lightImpact();
                  onSend(text);
                }
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.blue.withValues(alpha: 0.4), width: 0.8),
                ),
                child: const Icon(Icons.send_rounded, color: AppColors.blue, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
