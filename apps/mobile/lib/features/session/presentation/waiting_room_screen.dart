import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/error_handling/error_messages.dart';
import '../../../core/error_handling/retry.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/radar_button.dart';
import '../infrastructure/network_providers.dart';

class WaitingRoomScreen extends ConsumerStatefulWidget {
  const WaitingRoomScreen({
    super.key,
    required this.link,
  });

  final String link;

  @override
  ConsumerState<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends ConsumerState<WaitingRoomScreen> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        setState(() {
          // Rebuild to trigger a fresh backend fetch.
        });
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  ({String sessionId, String passkey}) _parseDeepLink() {
    final uri = Uri.tryParse(widget.link);
    if (uri == null) {
      throw const FormatException('Invalid session link');
    }
    final sessionId = uri.queryParameters['s'] ?? '';
    final passkey = uri.queryParameters['p'] ?? '';
    if (sessionId.isEmpty || passkey.isEmpty) {
      throw const FormatException('Session link is missing required parameters');
    }
    return (sessionId: sessionId, passkey: passkey);
  }

  Future<_WaitingRoomData> _loadData() async {
    final linkData = _parseDeepLink();
    final api = ref.read(apiClientProvider);

    final verify = await retryWithBackoff(
      task: () => api.getJson(
        '/api/v1/sessions/verify',
        query: {
          's': linkData.sessionId,
          'p': linkData.passkey,
        },
      ),
    );

    // TODO: Re-enable in V2 - /members endpoint was removed in MVP
    // final members = await retryWithBackoff(
    //   task: () => api.getJson('/api/v1/sessions/${linkData.sessionId}/members'),
    // );

    // MVP: Use only verify response (contains session_name and active_members)
    final sessionName = (verify['session_name'] as String?) ?? 'Unnamed session';
    final activeMembers = (verify['active_members'] as int?) ?? 0;
    // MVP: Member roster disabled - will be enabled in V2
    const roster = <_WaitingRoomMember>[];

    return _WaitingRoomData(
      sessionId: linkData.sessionId,
      sessionName: sessionName,
      activeMembers: activeMembers,
      members: roster,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<_WaitingRoomData>(
          future: _loadData(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    ErrorMessages.fromException(snapshot.error!),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!;
            final textTheme = Theme.of(context).textTheme;
            final hasMembers = data.members.isNotEmpty;

            return Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.sessionName,
                              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${data.activeMembers} ${data.activeMembers == 1 ? 'person is here' : 'people are here'}',
                              style: textTheme.labelSmall?.copyWith(color: AppColors.green),
                            ),
                          ],
                        ),
                      ),
                      RadarButton(
                        label: 'Launch Radar',
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          context.push('/radar');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.green.withValues(alpha: 0.5), width: 1.2),
                        boxShadow: [
                          BoxShadow(color: AppColors.green.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 1),
                        ],
                      ),
                      child: QrImageView(
                        data: widget.link,
                        size: 288,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColors.bg,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.bg,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    widget.link,
                    textAlign: TextAlign.center,
                    style: textTheme.labelSmall?.copyWith(color: AppColors.textDim),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.blue.withValues(alpha: 0.3), width: 0.8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "WHO'S HERE",
                            style: textTheme.labelSmall?.copyWith(color: AppColors.blue),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (!hasMembers)
                            Expanded(
                              child: Center(
                                child: Text(
                                  'Waiting for real people to join...',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyMedium?.copyWith(color: AppColors.textDim),
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: ListView.separated(
                                itemCount: data.members.length,
                                separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (context, index) {
                                  final member = data.members[index];
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                                    decoration: BoxDecoration(
                                      color: AppColors.white.withValues(alpha: 0.04),
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      border: Border.all(color: AppColors.white.withValues(alpha: 0.08), width: 0.8),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: _colorForIndex(index),
                                          child: Text(
                                            member.displayName.isNotEmpty ? member.displayName[0].toUpperCase() : '?',
                                            style: textTheme.labelMedium?.copyWith(
                                              color: AppColors.bg,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                member.displayName,
                                                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                member.privacyMode.replaceAll('_', ' '),
                                                style: textTheme.bodySmall?.copyWith(color: AppColors.textDim),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Text(
                                          'Joined',
                                          style: textTheme.labelSmall?.copyWith(color: AppColors.green),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: RadarButton(
                      label: 'Share Link',
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Share.share(widget.link);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Color _colorForIndex(int index) {
    final palette = [AppColors.green, AppColors.blue, AppColors.purple, AppColors.amber];
    return palette[index % palette.length];
  }
}

class _WaitingRoomData {
  const _WaitingRoomData({
    required this.sessionId,
    required this.sessionName,
    required this.activeMembers,
    required this.members,
  });

  final String sessionId;
  final String sessionName;
  final int activeMembers;
  final List<_WaitingRoomMember> members;
}

class _WaitingRoomMember {
  const _WaitingRoomMember({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.privacyMode,
  });

  final String userId;
  final String displayName;
  final String avatarUrl;
  final String privacyMode;
}
