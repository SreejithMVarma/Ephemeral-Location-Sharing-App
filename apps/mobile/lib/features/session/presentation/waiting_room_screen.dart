import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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
  late List<_WaitingRoomMember> _members;
  late String _sessionId;
  late String _passkey;
  late String _adminId;
  late String _wsUrl;
  WebSocketChannel? _wsChannel;
  bool _isAdmin = false;
  
  @override
  void initState() {
    super.initState();
    _members = [];
    _initializeAndConnect();
  }

  Future<void> _initializeAndConnect() async {
    final linkData = _parseDeepLink();
    _sessionId = linkData.sessionId;
    _passkey = linkData.passkey;
    
    // Get initial data including admin info
    await _loadInitialData();
    
    // Then connect to WebSocket
    _connectWebSocket();
  }

  Future<void> _loadInitialData() async {
    try {
      final api = ref.read(apiClientProvider);
      
      // Get verify response to check admin and WebSocket URL
      final verify = await retryWithBackoff(
        task: () => api.getJson(
          '/api/v1/sessions/verify',
          query: {'s': _sessionId, 'p': _passkey},
        ),
      );
      
      _adminId = verify['host_name'] as String? ?? '';
      _wsUrl = verify['websocket_url'] as String? ?? 'ws://10.0.2.2:8000';
      
      // Get members list
      final members = await retryWithBackoff(
        task: () => api.getJson(
          '/api/v1/sessions/$_sessionId/members',
          query: {'p': _passkey},
        ),
      );
      
      // Determine if current user is admin
      // In the waiting room context, only the admin has access (they created the session)
      _isAdmin = true;
      
      if (mounted) {
        setState(() {
          _members = (members as List)
              .map((m) => _WaitingRoomMember(
                userId: m['user_id'] ?? '',
                displayName: m['display_name'] ?? '',
                avatarUrl: m['avatar_url'] ?? '',
                privacyMode: m['privacy_mode'] ?? 'direction_distance',
              ))
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load members: ${ErrorMessages.fromException(e)}')),
        );
      }
    }
  }

  void _connectWebSocket() {
    try {
      final uri = Uri.parse('$_wsUrl/ws/$_sessionId?token=$_adminId');
      _wsChannel = WebSocketChannel.connect(uri);
      
      // Listen for WebSocket events
      _wsChannel?.stream.listen(
        (dynamic message) {
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;
            final type = data['type'] as String?;
            
            if (type == 'USER_CONNECTED') {
              final payload = data['payload'] as Map<String, dynamic>? ?? {};
              final userId = payload['user_id'] as String? ?? '';
              final displayName = payload['display_name'] as String? ?? '';
              final privacyMode = payload['privacy_mode'] as String? ?? 'direction_distance';
              
              if (mounted) {
                setState(() {
                  // Check if already exists
                  final existingIndex = _members.indexWhere((m) => m.userId == userId);
                  if (existingIndex == -1 && userId.isNotEmpty) {
                    _members.add(_WaitingRoomMember(
                      userId: userId,
                      displayName: displayName,
                      avatarUrl: '',
                      privacyMode: privacyMode,
                    ));
                  }
                });
              }
            } else if (type == 'USER_DISCONNECTED') {
              final payload = data['payload'] as Map<String, dynamic>? ?? {};
              final userId = payload['user_id'] as String? ?? '';
              
              if (mounted) {
                setState(() {
                  _members.removeWhere((m) => m.userId == userId);
                });
              }
            }
          } catch (e) {
            // Ignore JSON parse errors
          }
        },
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Connection error: $error')),
            );
          }
        },
        onDone: () {
          // WebSocket closed
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect WebSocket: ${ErrorMessages.fromException(e)}')),
        );
      }
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
    _wsChannel?.sink.close();
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
                        Text(
                          '${_members.length} ${_members.length == 1 ? 'person is here' : 'people are here'}',
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
    required this.avatarUrl,
    required this.privacyMode,
  });

  final String userId;
  final String displayName;
  final String avatarUrl;
  final String privacyMode;
}
