import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../application/chat_providers.dart';

class ChatOverlay extends ConsumerStatefulWidget {
  const ChatOverlay({
    super.key,
    this.defaultDmUserId,
  });

  final String? defaultDmUserId;

  @override
  ConsumerState<ChatOverlay> createState() => _ChatOverlayState();
}

class _ChatOverlayState extends ConsumerState<ChatOverlay> {
  bool _open = false;
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(groupChatProvider);
    final maxWidth = MediaQuery.of(context).size.width * 0.8;
    return RepaintBoundary(
      child: Align(
        alignment: Alignment.centerRight,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          offset: _open ? const Offset(0, 0) : const Offset(1, 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: maxWidth,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.96),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
              border: Border.all(color: AppColors.white.withValues(alpha: 0.08), width: 0.6),
            ),
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                if (details.delta.dx < -6) {
                  setState(() => _open = true);
                }
                if (details.delta.dx > 6) {
                  setState(() => _open = false);
                }
              },
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity == null) {
                  return;
                }
                if (details.primaryVelocity! < -400) {
                  setState(() => _open = true);
                } else if (details.primaryVelocity! > 400) {
                  setState(() => _open = false);
                }
              },
              child: _open
                  ? Column(
                    children: [
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Text('Group chat', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            const Spacer(),
                            Text('swipe to close', style: Theme.of(context).textTheme.labelSmall),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          reverse: true,
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = messages[messages.length - 1 - index];
                            return Padding(
                              padding: const EdgeInsets.all(8),
                              child: _bubble(context, msg),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                decoration: const InputDecoration(hintText: 'message...'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onLongPress: () {
                                HapticFeedback.heavyImpact();
                                ref.read(groupChatProvider.notifier).update((state) {
                                  return [...state, const ChatMessage('Pulse ping sent', sender: 'You', isMine: true, pulse: true)];
                                });
                              },
                              child: FloatingActionButton.small(
                                onPressed: () {
                                  final text = _controller.text.trim();
                                  if (text.isEmpty) {
                                    return;
                                  }
                                  HapticFeedback.mediumImpact();
                                  ref.read(groupChatProvider.notifier).update((state) {
                                    return [...state, ChatMessage(text, sender: 'You', isMine: true)];
                                  });
                                  _controller.clear();
                                },
                                backgroundColor: AppColors.green.withValues(alpha: 0.15),
                                foregroundColor: AppColors.green,
                                child: const Icon(Icons.arrow_forward),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bubble(BuildContext context, ChatMessage msg) {
    if (msg.system) {
      return Align(
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(msg.text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.green.withValues(alpha: 0.75))),
        ),
      );
    }

    if (msg.pulse) {
      return Align(
        alignment: Alignment.center,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 240),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.blue.withValues(alpha: 0.25), width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PULSE PING', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.blue)),
              const SizedBox(height: 2),
              Text(msg.text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.blue)),
            ],
          ),
        ),
      );
    }

    final mine = msg.isMine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!mine)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(msg.sender, style: Theme.of(context).textTheme.labelSmall),
            ),
          Container(
            constraints: const BoxConstraints(maxWidth: 250),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: mine ? AppColors.green.withValues(alpha: 0.15) : AppColors.surface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: mine ? AppColors.green.withValues(alpha: 0.22) : AppColors.white.withValues(alpha: 0.1),
                width: 0.8,
              ),
            ),
            child: Text(msg.text),
          ),
        ],
      ),
    );
  }
}
