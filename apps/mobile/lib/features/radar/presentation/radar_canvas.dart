import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../domain/radar_blip.dart';

class RadarCanvas extends StatelessWidget {
  const RadarCanvas({
    super.key,
    required this.blips,
    required this.sweepAngle,
  });

  final List<RadarBlip> blips;
  final double sweepAngle;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _RadarPainter(blips: blips, sweepAngle: sweepAngle),
        size: const Size.square(320),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.blips, required this.sweepAngle});

  final List<RadarBlip> blips;
  final double sweepAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 10;

    final ringPaint = Paint()
      ..color = AppColors.green.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, ringPaint);
    canvas.drawCircle(center, radius * 0.66, ringPaint..color = AppColors.green.withValues(alpha: 0.06));
    canvas.drawCircle(center, radius * 0.33, ringPaint..color = AppColors.green.withValues(alpha: 0.04));

    final axisPaint = Paint()
      ..color = AppColors.green.withValues(alpha: 0.04)
      ..strokeWidth = 0.6;
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), axisPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), axisPaint);

    final angle = sweepAngle * pi / 180;
    final trailPaint = Paint()
      ..shader = SweepGradient(
        startAngle: angle - 0.5,
        endAngle: angle,
        colors: [
          AppColors.green.withValues(alpha: 0.0),
          AppColors.green.withValues(alpha: 0.06),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), angle - 0.5, 0.5, true, trailPaint);

    final sweepLinePaint = Paint()
      ..color = AppColors.green.withValues(alpha: 0.65)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(center.dx + cos(angle) * radius, center.dy + sin(angle) * radius),
      sweepLinePaint,
    );

    canvas.drawCircle(center, 5, Paint()..color = AppColors.green);
    canvas.drawCircle(center, 2.5, Paint()..color = AppColors.bg);

    const palette = [AppColors.blue, AppColors.purple, AppColors.amber, AppColors.green];

    for (var i = 0; i < blips.length; i++) {
      final blip = blips[i];
      final blipRadius = blip.directionOnly ? radius : (radius * (blip.distanceMeters.clamp(5, 200) / 200));
      final angle = blip.bearing * pi / 180;
      final point = Offset(
        center.dx + cos(angle) * blipRadius,
        center.dy + sin(angle) * blipRadius,
      );

      final color = palette[i % palette.length];
      canvas.drawCircle(
        point,
        11,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color.withValues(alpha: 0.4),
      );
      canvas.drawCircle(point, 9, Paint()..color = color.withValues(alpha: 0.18));

      final text = TextPainter(
        text: TextSpan(
          text: blip.displayName.isEmpty ? '?' : blip.displayName[0].toUpperCase(),
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, point.translate(-text.width / 2, -text.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle || oldDelegate.blips != blips;
  }
}
