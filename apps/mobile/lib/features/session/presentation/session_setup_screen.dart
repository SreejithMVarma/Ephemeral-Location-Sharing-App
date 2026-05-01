import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_handling/error_messages.dart';
import '../../../core/error_handling/retry.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/radar_button.dart';
import '../../../core/widgets/radar_text_field.dart';
import '../application/rejoin_service.dart';
import '../application/session_state.dart';
import '../domain/session_cache.dart';
import '../infrastructure/network_providers.dart';

class SessionSetupScreen extends ConsumerStatefulWidget {
  const SessionSetupScreen({super.key});

  @override
  ConsumerState<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends ConsumerState<SessionSetupScreen> {
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _sessionNameController = TextEditingController();
  bool _groupChatEnabled = true;
  bool _loading = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _sessionNameController.dispose();
    super.dispose();
  }

  Future<void> _createSession() async {
    final sessionName = _sessionNameController.text.trim();
    final displayName = _displayNameController.text.trim();
    debugPrint('[Generate QR] pressed sessionName="$sessionName" displayName="$displayName" chatEnabled=$_groupChatEnabled');
    if (sessionName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a session name')),
      );
      return;
    }
    if (displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    final api = ref.read(apiClientProvider);
    final adminId = 'admin_${DateTime.now().millisecondsSinceEpoch}';

    try {
      debugPrint('[Generate QR] creating session adminId=$adminId via ${api.runtimeType}');
      final response = await retryWithBackoff(
        task: () => api.postJson(
          '/api/v1/sessions',
          body: {
            'session_name': sessionName,
            'admin_id': adminId,
            'admin_display_name': displayName,
            'chat_enabled': _groupChatEnabled,
            'region': 'us-east',
          },
        ),
      );

      final deepLinkUrl = (response['deep_link_url'] as String?) ?? '';
      if (deepLinkUrl.isEmpty) {
        debugPrint('[Generate QR] create-session response: $response');
        throw StateError('Backend did not return a deep link');
      }
      debugPrint('[Generate QR] backend returned empty deep_link_url');

      // Save session state for the admin/creator
      ref.read(sessionStateProvider.notifier).setSession(
        sessionId: adminId,
        sessionName: sessionName,
        userId: adminId,
        displayName: displayName,
        privacyMode: 'full_map',
      );

      // Save to local storage history with timestamp
      final storage = await ref.read(localStorageServiceProvider.future);
      final now = DateTime.now().toIso8601String();
      await storage.saveSession(
        SessionCache(
          sessionId: adminId,
          authToken: adminId, // Use admin ID as token for creator
          sessionName: sessionName,
          joinedAt: now,
        ),
      );

      if (!mounted) {
        debugPrint('[Generate QR] deep link ready, navigating to waiting room');
        return;
      }

      context.push('/waiting?link=${Uri.encodeComponent(deepLinkUrl)}');
    } catch (error) {
      debugPrint('[Generate QR] failed: ${error.runtimeType} $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorMessages.fromException(error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      debugPrint('[Generate QR] finished, loading=$_loading');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Session Setup'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SESSION SETUP',
              style: textTheme.labelSmall?.copyWith(
                letterSpacing: 1.5,
                color: AppColors.green,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Name your radar',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            RadarTextField(
              label: 'YOUR NAME',
              controller: _displayNameController,
            ),
            const SizedBox(height: AppSpacing.md),
            RadarTextField(
              label: 'SESSION NAME',
              controller: _sessionNameController,
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: AppColors.white.withValues(alpha: 0.08),
                  width: 0.6,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Group chat',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Members can message',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() => _groupChatEnabled = !_groupChatEnabled);
                    },
                    child: Container(
                      width: 44,
                      height: 26,
                      decoration: BoxDecoration(
                        color: _groupChatEnabled
                            ? AppColors.green
                            : AppColors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      alignment:
                          _groupChatEnabled ? Alignment.centerRight : Alignment.centerLeft,
                      padding: const EdgeInsets.all(3),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _groupChatEnabled ? AppColors.bg : AppColors.white.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: RadarButton(
                label: _loading ? 'Creating...' : 'Generate QR',
                onPressed: _loading ? null : _createSession,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
