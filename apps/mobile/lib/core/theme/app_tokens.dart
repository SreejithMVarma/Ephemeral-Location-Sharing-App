import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0A0A0F);
  static const surface = Color(0xFF111120);
  static const surface2 = Color(0xFF161628);
  static const green = Color(0xFF00FF88);
  static const blue = Color(0xFF00D4FF);
  static const danger = Color(0xFFFF3B5C);
  static const purple = Color(0xFFA855F7);
  static const amber = Color(0xFFFFB347);
  static const white = Color(0xFFFFFFFF);
  static const grid = Color(0xFF1A1A2E);
  static const textDim = Color(0x80FFFFFF);

  static const radarGreen = green;
  static const electricBlue = blue;
  static const backgroundPrimary = bg;
  static const backgroundSecondary = surface;
  static const textPrimary = white;
  static const textSecondary = textDim;
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 40.0;
  static const xxl = 64.0;
}

class AppRadius {
  static const sm = 12.0;
  static const md = 12.0;
  static const lg = 20.0;
  static const button = 14.0;
  static const sheet = 28.0;
  static const pill = 100.0;
}

class AppTypography {
  static const display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  static const mono = TextStyle(
    fontSize: 12,
    fontFamily: 'monospace',
    color: AppColors.textSecondary,
  );
}

class RadarAnimationDurations {
  static const kRadarSweepDuration = Duration(milliseconds: 4000);
  static const kCompassLerpDuration = Duration(milliseconds: 300);
  static const kBlipFadeOut = Duration(milliseconds: 800);
}
