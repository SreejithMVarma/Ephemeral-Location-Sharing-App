import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../radar/application/radar_providers.dart';
import '../../session/application/location_providers.dart';
import '../../session/domain/location_mode.dart';
import '../domain/bearing_utils.dart';

class CompassView extends ConsumerStatefulWidget {
  const CompassView({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<CompassView> createState() => _CompassViewState();
}

class _CompassViewState extends ConsumerState<CompassView> {
  double _current = 0;
  bool _proximityPulse = false;
  int _lastPulseAt = 0;

  @override
  void initState() {
    super.initState();
    ref.read(locationModeProvider.notifier).state = LocationMode.compass;
  }

  @override
  void dispose() {
    ref.read(locationModeProvider.notifier).state = LocationMode.radar;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get live blip for this user
    final liveBlips = ref.watch(radarBlipsProvider);
    final snapshotBlips = ref.watch(liveRadarBlipsProvider).valueOrNull ?? {};

    final blip = liveBlips[widget.userId] ?? snapshotBlips[widget.userId];

    final bearing = blip?.bearing ?? 0.0;
    final distanceMeters = blip?.distanceMeters ?? 0.0;
    final displayName = (blip?.displayName.isNotEmpty ?? false)
        ? blip!.displayName
        : widget.userId;

    // Smooth interpolation toward current bearing
    final delta = shortestDelta(_current, bearing);
    _current = normalize360(_current + delta * 0.15);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Top bar
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                  const Spacer(),
                  if (blip != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.green.withValues(alpha: 0.35), width: 0.7),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          Text('LIVE', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.green)),
                        ],
                      ),
                    )
                  else
                    Text('WAITING...', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textDim)),
                ],
              ),
              const SizedBox(height: 8),

              // Name and distance
              Text(
                displayName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  key: ValueKey(distanceMeters.round()),
                  distanceMeters < 1 ? 'right next to you' : '${distanceMeters.round()} m away',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.amber),
                ),
              ),
              const SizedBox(height: 18),

              // Compass
              Expanded(
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: _current, end: bearing),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    onEnd: () {
                      final now = DateTime.now().millisecondsSinceEpoch;
                      if (distanceMeters <= 20 && now - _lastPulseAt > 30000) {
                        _lastPulseAt = now;
                        HapticFeedback.mediumImpact();
                        setState(() => _proximityPulse = true);
                        Future<void>.delayed(const Duration(milliseconds: 700), () {
                          if (mounted) setState(() => _proximityPulse = false);
                        });
                      }
                    },
                    builder: (context, value, _) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 220,
                            height: 220,
                            child: CustomPaint(painter: _CompassRingPainter(heading: value)),
                          ),
                          if (_proximityPulse)
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 1, end: 1.4),
                              duration: const Duration(milliseconds: 600),
                              builder: (context, pulse, _) {
                                return Opacity(
                                  opacity: (1.4 - pulse).clamp(0, 1),
                                  child: Container(
                                    width: 160 * pulse,
                                    height: 160 * pulse,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.green, width: 1),
                                    ),
                                  ),
                                );
                              },
                            ),
                          Transform.rotate(
                            angle: degToRad(value),
                            child: SizedBox(
                              width: 92,
                              height: 140,
                              child: CustomPaint(painter: _CompassArrowPainter()),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // Message button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ChatScreen.show(context, initialDmUserId: widget.userId);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.blue.withValues(alpha: 0.3), width: 0.8),
                  ),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'avatar-${widget.userId}',
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.blue.withValues(alpha: 0.14),
                            border: Border.all(color: AppColors.blue.withValues(alpha: 0.65), width: 1),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            displayName.isEmpty ? '?' : displayName[0].toUpperCase(),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.blue, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Message $displayName', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                            Text('open direct message', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textDim)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward, color: AppColors.blue),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompassRingPainter extends CustomPainter {
  _CompassRingPainter({required this.heading});

  final double heading;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.blue.withValues(alpha: 0.2);
    canvas.drawCircle(center, radius, ringPaint);
    canvas.drawCircle(center, radius - 12, ringPaint..color = AppColors.blue.withValues(alpha: 0.1));

    for (var i = 0; i < 72; i++) {
      final deg = i * 5;
      final isMajor = deg % 45 == 0;
      final angle = degToRad(deg - heading);
      final outer = Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle));
      final inner = Offset(
        center.dx + (radius - (isMajor ? 10 : 5)) * math.cos(angle),
        center.dy + (radius - (isMajor ? 10 : 5)) * math.sin(angle),
      );
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = AppColors.white.withValues(alpha: isMajor ? 0.45 : 0.18)
          ..strokeWidth = isMajor ? 1 : 0.6,
      );
    }

    _label(canvas, center, radius - 16, 'N', -90 - heading, AppColors.blue.withValues(alpha: 0.7));
    _label(canvas, center, radius - 16, 'E', 0 - heading, AppColors.white.withValues(alpha: 0.25));
    _label(canvas, center, radius - 16, 'S', 90 - heading, AppColors.white.withValues(alpha: 0.25));
    _label(canvas, center, radius - 16, 'W', 180 - heading, AppColors.white.withValues(alpha: 0.25));
  }

  void _label(Canvas canvas, Offset center, double radius, String text, double angle, Color color) {
    final rad = degToRad(angle);
    final point = Offset(center.dx + radius * math.cos(rad), center.dy + radius * math.sin(rad));
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, point.translate(-painter.width / 2, -painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _CompassRingPainter oldDelegate) => oldDelegate.heading != heading;
}

class _CompassArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    final north = Path()
      ..moveTo(center.dx, 6)
      ..lineTo(center.dx + 13, h * 0.44)
      ..lineTo(center.dx, h * 0.36)
      ..lineTo(center.dx - 13, h * 0.44)
      ..close();
    final northPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.blue, Color(0x5500D4FF)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(north, northPaint);

    final south = Path()
      ..moveTo(center.dx, h - 6)
      ..lineTo(center.dx + 13, h * 0.56)
      ..lineTo(center.dx, h * 0.64)
      ..lineTo(center.dx - 13, h * 0.56)
      ..close();
    canvas.drawPath(south, Paint()..color = AppColors.white.withValues(alpha: 0.12));

    canvas.drawCircle(center, 7, Paint()..color = AppColors.blue);
    canvas.drawCircle(center, 3, Paint()..color = AppColors.bg);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
