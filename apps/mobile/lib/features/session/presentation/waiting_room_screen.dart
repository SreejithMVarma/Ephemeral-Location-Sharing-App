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
import '../application/rejoin_service.dart';
import '../application/session_state.dart';
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
  List<_WaitingRoomMember> _members = [];
  String _sessionId = '';
  String _passkey = '';
  String _adminId = '';
  bool _isAdmin = false;
  bool _initialLoading = true;

  /// HTTP polling timer — refreshes member list every 5 seconds
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _initializeAndStartPolling();
  }

  Future<void> _initializeAndStartPolling() async {
    final linkData = _parseDeepLink();
    _sessionId = linkData.sessionId;
    _passkey = linkData.passkey;

    await _loadInitialData();
    setState(() => _initialLoading = false);

    // Poll member list every 5 s for live updates
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchMembers());
  }

  Future<void> _loadInitialData() async {
    try {
      final api = ref.read(apiClientProvider);

      final verify = await retryWithBackoff(
        task: () => api.getJson(
          '/api/v1/sessions/verify',
          query: {'s': _sessionId, 'p': _passkey},
        ),
      );

      _adminId = verify['host_name'] as String? ?? '';

      // Determine if current user is admin by checking local history
      final storage = await ref.read(localStorageServiceProvider.future);
      final history = await storage.readSessionHistory();
      final currentSession = history.where((s) => s.sessionId == _sessionId).firstOrNull;
      _isAdmin = currentSession?.isCreatedByMe ?? false;

      await _fetchMembers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load session: ${ErrorMessages.fromException(e)}')),
        );
      }
    }
  }

  Future<void> _fetchMembers() async {
    try {
      final api = ref.read(apiClientProvider);
      final members = await retryWithBackoff(
        task: () => api.getJsonList(
          '/api/v1/sessions/$_sessionId/members',
          query: {'p': _passkey},
        ),
      );

      if (mounted) {
        setState(() {
          _members = members
              .map((m) => _WaitingRoomMember(
                    userId: m['user_id'] ?? '',
                    displayName: m['display_name'] ?? '',
                    privacyMode: m['privacy_mode'] ?? 'direction_distance',
                  ))
              .toList();
        });
      }
    } catch (e) {
      // Silently ignore polling errors (don't spam snackbars)
      debugPrint('[WaitingRoom] Poll error: $e');
    }
  }

  Future<void> _removeMember(String userId) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.deleteRequest(
        '/api/v1/sessions/$_sessionId/members/$userId',
        query: {'admin_id': _adminId},
      );

      if (mounted) {
        setState(() {
          _members.removeWhere((m) => m.userId == userId);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove member: ${ErrorMessages.fromException(e)}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<String> _fetchWsUrl(WidgetRef ref, String sessionId, String passkey) async {
    try {
      final api = ref.read(apiClientProvider);
      final verify = await retryWithBackoff(
        task: () => api.getJson(
          '/api/v1/sessions/verify',
          query: {'s': sessionId, 'p': passkey},
        ),
      );
      return (verify['websocket_url'] as String?) ?? '';
    } catch (e) {
      debugPrint('[WaitingRoom] Could not fetch WS URL: $e');
      return '';
    }
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (_initialLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final hasMembers = _members.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Padding(
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
                          'Waiting room',
                          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${_members.length} ${_members.length == 1 ? 'person is here' : 'people are here'}',
                              style: textTheme.labelSmall?.copyWith(color: AppColors.green),
                            ),
                            const SizedBox(width: 6),
                            // Live indicator dot
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  RadarButton(
                    label: 'Launch Radar',
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      // Restore sessionStateProvider from local history before navigating
                      final storage = await ref.read(localStorageServiceProvider.future);
                      final history = await storage.readSessionHistory();
                      final cached = history.where((s) => s.sessionId == _sessionId).firstOrNull;
                      if (cached != null && ref.read(sessionStateProvider) == null) {
                        ref.read(sessionStateProvider.notifier).setSession(
                          sessionId: cached.sessionId,
                          sessionName: cached.sessionName,
                          userId: cached.userId.isNotEmpty ? cached.userId : cached.adminId,
                          displayName: cached.displayName,
                          privacyMode: cached.privacyMode,
                          passkey: cached.authToken,
                          wsUrl: (await _fetchWsUrl(ref, cached.sessionId, cached.authToken)),
                        );
                      }
                      if (!mounted) return;
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
                    size: 240,
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
                      Row(
                        children: [
                          Text(
                            "WHO'S HERE",
                            style: textTheme.labelSmall?.copyWith(color: AppColors.blue),
                          ),
                          const Spacer(),
                          Text(
                            'refreshes every 5s',
                            style: textTheme.labelSmall?.copyWith(color: AppColors.textDim),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (!hasMembers)
                        Expanded(
                          child: Center(
                            child: Text(
                              'Waiting for people to join...',
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(color: AppColors.textDim),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            itemCount: _members.length,
                            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              final member = _members[index];
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
                                    if (_isAdmin)
                                      GestureDetector(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          _removeMember(member.userId);
                                        },
                                        child: Icon(
                                          Icons.close,
                                          size: 20,
                                          color: AppColors.textDim,
                                        ),
                                      )
                                    else
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
        ),
      ),
    );
  }

  Color _colorForIndex(int index) {
    final palette = [AppColors.green, AppColors.blue, AppColors.purple, AppColors.amber];
    return palette[index % palette.length];
  }
}

class _WaitingRoomMember {
  const _WaitingRoomMember({
    required this.userId,
    required this.displayName,
    required this.privacyMode,
  });

  final String userId;
  final String displayName;
  final String privacyMode;
}
