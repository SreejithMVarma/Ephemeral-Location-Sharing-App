import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/widgets/radar_button.dart';

class BlurredRadarBlocker extends StatelessWidget {
  const BlurredRadarBlocker({
    super.key,
    required this.onOpenSettings,
    required this.onLeave,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Background Location Required'),
                  const SizedBox(height: 12),
                  const Text('Radar requires background location permission to continue.'),
                  const SizedBox(height: 16),
                  RadarButton(label: 'Go to Settings', onPressed: onOpenSettings),
                  const SizedBox(height: 8),
                  RadarButton(
                    label: 'Leave Session',
                    variant: RadarButtonVariant.danger,
                    onPressed: onLeave,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
