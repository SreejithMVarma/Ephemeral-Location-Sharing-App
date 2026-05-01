import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/app_animations.dart';
import '../../../main.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/radar_button.dart';
import '../../../core/widgets/radar_card.dart';
import '../../../core/widgets/radar_snackbar.dart';
import '../application/rejoin_service.dart';

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
    final rejoin = ref.watch(rejoinCacheProvider);
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
                    rejoin.when(
                      data: (cache) {
                        if (cache == null) {
                          return const SizedBox.shrink();
                        }
                        return _stagger(
                          5,
                          child: RadarCard(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text('Rejoin: ${cache.sessionName}', style: AppTypography.body),
                                ),
                                TextButton(
                                  onPressed: () {
                                    context.push('/join?s=${cache.sessionId}&p=rejoin');
                                  },
                                  child: const Text('Rejoin'),
                                ),
                              ],
                            ),
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
