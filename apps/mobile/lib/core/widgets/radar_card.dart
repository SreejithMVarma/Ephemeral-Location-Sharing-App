import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class RadarCard extends StatelessWidget {
  const RadarCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.2), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.08),
            blurRadius: 18,
            spreadRadius: -6,
          ),
        ],
      ),
      child: child,
    );
  }
}
