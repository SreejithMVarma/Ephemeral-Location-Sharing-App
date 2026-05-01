import 'package:flutter/material.dart';

enum RadarSnackType { info, warning, danger }

class RadarSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    RadarSnackType type = RadarSnackType.info,
  }) {
    final color = switch (type) {
      RadarSnackType.info => Colors.blueGrey,
      RadarSnackType.warning => Colors.orange,
      RadarSnackType.danger => Colors.redAccent,
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
