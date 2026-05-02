import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/animations/app_animations.dart';
import '../../../core/error_handling/error_messages.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/radar_button.dart';
import '../application/rejoin_service.dart';
import '../domain/session_cache.dart';
import '../infrastructure/network_providers.dart';

class EntryScreen extends ConsumerStatefulWidget {
  const EntryScreen({super.key});

  @override
  ConsumerState<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends ConsumerState<EntryScreen> with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _heroController;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _heroController = AnimationController(
      vsync: this,
      duration: AppAnimations.radarSweep,
    )..repeat();
  }

  @override
  void dispose() {
    _introController.dispose();
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _EntryBackdrop()),
          SafeArea(
            child: SizedBox(
              width: double.infinity,
               height: double.infinity,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _stagger(
                      0,
                      child: Text(
                        'FIND YOUR CREW',
                        style: textTheme.labelSmall?.copyWith(letterSpacing: 2.5, color: AppColors.textDim),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _stagger(1, child: _HeroRadar(controller: _heroController)),
                    const SizedBox(height: AppSpacing.md),
                    _stagger(
                      2,
                      child: Text(
                        'Radar',
                        style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.white),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _stagger(
                      3,
                      child: Text(
                        'ephemeral. private. live.',
                        style: textTheme.bodySmall?.copyWith(color: AppColors.textDim),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _stagger(
                      4,
                      child: Column(
                        children: [
                          RadarButton(
                            label: 'Create a Radar',
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              context.push('/session-setup');
                            },
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          RadarButton(
                            label: 'Scan to Join',
                            variant: RadarButtonVariant.secondary,
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              context.push('/scan-qr');
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ref.watch(sessionHistoryProvider).when(
                      data: (history) {
                        return _stagger(
                          5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'RECENT SESSIONS',
                                style: textTheme.labelSmall?.copyWith(
                                  letterSpacing: 1.5,
                                  color: AppColors.blue,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              if (history.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppColors.textDim.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'No recent sessions',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: AppColors.textDim,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ...history.map((session) => _SessionHistoryItem(
                                  session: session,
                                  onRejoin: () {
                                    HapticFeedback.lightImpact();
                                    // If created by me, auto-fill form with saved config
                                    if (session.isCreatedByMe && session.displayName.isNotEmpty) {
                                      context.push(
                                        '/join?s=${session.sessionId}&p=${session.authToken}&d=${Uri.encodeComponent(session.displayName)}&m=${session.privacyMode}',
                                      );
                                    } else {
                                      context.push('/join?s=${session.sessionId}&p=${session.authToken}');
                                    }
                                  },
                                  onViewQr: session.isCreatedByMe ? () {
                                    HapticFeedback.lightImpact();
                                    _showQrBottomSheet(context, session);
                                  } : null,
                                  onDelete: session.isCreatedByMe ? () {
                                    _showDeleteConfirmation(context, session);
                                  } : null,
                                )),
                            ],
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stagger(int index, {required Widget child}) {
    final begin = index * 0.1;
    final end = (begin + 0.4).clamp(0.0, 1.0);
    final curved = CurvedAnimation(
      parent: _introController,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }

  void _showQrBottomSheet(BuildContext context, SessionCache session) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _QrShareSheet(session: session),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  void _showDeleteConfirmation(BuildContext context, SessionCache session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Radar?'),
        content: Text(
          'Are you sure you want to delete "${session.sessionName}"? This will end the session for everyone.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSession(session);
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFe74c3c))),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSession(SessionCache session) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.deleteRequest(
        '/api/v1/sessions/${session.sessionId}',
        query: {'admin_id': session.adminId},
      );

      if (mounted) {
        ref.invalidate(sessionHistoryProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete session: ${ErrorMessages.fromException(e)}')),
        );
      }
    }
  }
}

class _EntryBackdrop extends StatelessWidget {
  const _EntryBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _EntryBackdropPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _EntryBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.22);
    final gradient = RadialGradient(
      colors: [
        AppColors.green.withValues(alpha: 0.12),
        AppColors.bg,
      ],
      stops: const [0.0, 1.0],
      radius: 0.75,
    );
    final paint = Paint()..shader = gradient.createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);

    final ringPaint = Paint()
      ..color = AppColors.green.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(center, 48 + (i * 34), ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeroRadar extends StatelessWidget {
  const _HeroRadar({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 110,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return CustomPaint(painter: _HeroRadarPainter(sweep: controller.value));
        },
      ),
    );
  }
}

class _HeroRadarPainter extends CustomPainter {
  _HeroRadarPainter({required this.sweep});

  final double sweep;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.green.withValues(alpha: 0.24);
    canvas.drawCircle(center, radius, grid);
    canvas.drawCircle(center, radius * 0.66, grid..color = AppColors.green.withValues(alpha: 0.16));
    canvas.drawCircle(center, radius * 0.34, grid..color = AppColors.green.withValues(alpha: 0.12));

    final angle = sweep * 6.28318530718;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: angle - 0.35,
        endAngle: angle,
        colors: [
          AppColors.green.withValues(alpha: 0),
          AppColors.green.withValues(alpha: 0.25),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), angle - 0.4, 0.4, true, sweepPaint);

    final line = Paint()
      ..color = AppColors.green
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, Offset(center.dx + radius * 0.85, center.dy), line);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawLine(center, Offset(center.dx, center.dy - radius), line);
    canvas.restore();
    canvas.drawCircle(center, 4, Paint()..color = AppColors.green);
  }

  @override
  bool shouldRepaint(covariant _HeroRadarPainter oldDelegate) => oldDelegate.sweep != sweep;
}

class _SessionHistoryItem extends StatelessWidget {
  const _SessionHistoryItem({
    required this.session,
    required this.onRejoin,
    this.onViewQr,
    this.onDelete,
  });

  final SessionCache session;
  final VoidCallback onRejoin;
  final VoidCallback? onViewQr;
  final VoidCallback? onDelete;

  String _formatTimeAgo(String joinedAtStr) {
    try {
      final joinedAt = DateTime.parse(joinedAtStr);
      final now = DateTime.now();
      final diff = now.difference(joinedAt);
      
      if (diff.inMinutes < 1) {
        return 'just now';
      } else if (diff.inHours < 1) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inDays < 1) {
        return '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      } else {
        return joinedAtStr.split('T')[0];
      }
    } catch (e) {
      return 'unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final timeAgo = _formatTimeAgo(session.joinedAt);
    
    return GestureDetector(
      onTap: onRejoin,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.08), width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.sessionName,
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeAgo,
                    style: textTheme.labelSmall?.copyWith(color: AppColors.textDim),
                  ),
                ],
              ),
            ),
            if (onViewQr != null)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: onViewQr,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.blue.withValues(alpha: 0.3), width: 0.6),
                        ),
                        child: const Icon(Icons.qr_code, color: AppColors.blue, size: 18),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (onDelete != null)
                      GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.danger.withValues(alpha: 0.3), width: 0.6),
                          ),
                          child: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                        ),
                      ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Icon(Icons.arrow_forward, color: AppColors.textDim, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

class _QrShareSheet extends StatelessWidget {
  const _QrShareSheet({required this.session});

  final SessionCache session;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Share Radar',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textDim),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (session.deepLinkUrl.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.green.withValues(alpha: 0.5), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.green.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    QrImageView(
                      data: session.deepLinkUrl,
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
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      session.deepLinkUrl,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textDim),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Clipboard.setData(ClipboardData(text: session.deepLinkUrl)).then((_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copied to clipboard')),
                        );
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.blue.withValues(alpha: 0.3), width: 0.8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.link, color: AppColors.blue, size: 16),
                          const SizedBox(width: 6),
                          Text('Copy Link', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.blue)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Share.share(session.deepLinkUrl);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.green.withValues(alpha: 0.3), width: 0.8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.share, color: AppColors.green, size: 16),
                          const SizedBox(width: 6),
                          Text('Share', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.green)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
