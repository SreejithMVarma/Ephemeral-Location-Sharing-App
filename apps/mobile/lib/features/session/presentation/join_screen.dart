import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error_handling/error_messages.dart';
import '../../../core/error_handling/retry.dart';
import '../../../core/telemetry/telemetry_service.dart';
import '../../auth/application/auth_state.dart';
import '../application/privacy_providers.dart';
import '../infrastructure/network_providers.dart';

import '../../../core/widgets/radar_button.dart';
import '../../../core/widgets/radar_card.dart';
import '../../../core/widgets/radar_text_field.dart';

class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({
    super.key,
    required this.sessionId,
    required this.passkey,
  });

  final String sessionId;
  final String passkey;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final TextEditingController _nameController = TextEditingController(text: 'Explorer');
  PrivacyMode _preJoinMode = PrivacyMode.directionDistance;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _joinSession() async {
    final displayName = _nameController.text.trim();
    if (displayName.isEmpty) {
      return;
    }

    setState(() {
      _loading = true;
    });

    final now = DateTime.now().millisecondsSinceEpoch;
    final userId = 'user_$now';
    final api = ref.read(apiClientProvider);
    final notifications = ref.read(notificationServiceProvider);

    try {
      await notifications.requestJoinPermission();
      final token = await notifications.currentToken();

      await retryWithBackoff(
        task: () => api.postJson(
          '/api/v1/sessions/${widget.sessionId}/join',
          body: {
            'user_id': userId,
            'display_name': displayName,
            'privacy_mode': _preJoinMode.name,
            if (token != null && token.isNotEmpty) 'fcm_token': token,
          },
        ),
      );

      notifications.bindTokenRefresh(sessionId: widget.sessionId, userId: userId);
      await TelemetryService.logEvent(
        'session_joined',
        parameters: {
          'source': 'deep_link',
        },
      );
      ref.read(isAuthenticatedProvider.notifier).state = true;

      if (mounted) {
        context.push('/radar');
      }
    } catch (error) {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join as yourself')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: RadarCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Join via deep link', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Session: ${widget.sessionId}'),
              Text('Passkey: ${widget.passkey}'),
              const SizedBox(height: 12),
              RadarTextField(
                label: 'Display Name',
                controller: _nameController,
              ),
              const SizedBox(height: 16),
              Text(
                'YOUR VISIBILITY',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _modeChip(context, PrivacyMode.directionOnly, 'Direction'),
                  _modeChip(context, PrivacyMode.directionDistance, '+ Distance'),
                  _modeChip(context, PrivacyMode.fullMap, 'Full map'),
                ],
              ),
              const SizedBox(height: 12),
              RadarButton(
                label: _loading ? 'Joining...' : 'Verify & Continue',
                onPressed: _loading ? null : _joinSession,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeChip(BuildContext context, PrivacyMode mode, String label) {
    final selected = _preJoinMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _preJoinMode = mode;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0x1A00FF88) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0x8000FF88) : const Color(0x1FFFFFFF),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: selected ? const Color(0xFF00FF88) : const Color(0x80FFFFFF),
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
