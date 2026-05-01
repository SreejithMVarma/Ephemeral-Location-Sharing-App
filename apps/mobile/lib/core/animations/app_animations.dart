import 'package:flutter/animation.dart';

class AppAnimations {
  static const radarSweep = Duration(milliseconds: 4000);
  static const blipEntrance = Duration(milliseconds: 300);
  static const blipStagger = Duration(milliseconds: 80);
  static const compassLerp = Duration(milliseconds: 300);
  static const chatSlide = Duration(milliseconds: 250);
  static const sheetExpand = Duration(milliseconds: 350);
  static const blipFadeOut = Duration(milliseconds: 800);
  static const heroTransit = Duration(milliseconds: 400);
  static const pageTransit = Duration(milliseconds: 350);

  static const sweepCurve = Curves.linear;
  static const entranceCurve = Curves.elasticOut;
  static const compassCurve = Curves.easeOutCubic;
  static const slideCurve = Curves.easeOutCubic;
}
