import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

enum RadarButtonVariant { primary, secondary, danger }

class RadarButton extends StatelessWidget {
  const RadarButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = RadarButtonVariant.primary,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final RadarButtonVariant variant;
  final double height;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    switch (variant) {
      case RadarButtonVariant.secondary:
        bg = AppColors.white.withValues(alpha: 0.06);
        fg = AppColors.white.withValues(alpha: 0.85);
        break;
      case RadarButtonVariant.danger:
        bg = AppColors.danger;
        fg = AppColors.white;
        break;
      case RadarButtonVariant.primary:
        bg = AppColors.green;
        fg = AppColors.bg;
        break;
    }

    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        height: height,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            side: variant == RadarButtonVariant.secondary
                ? BorderSide(color: AppColors.white.withValues(alpha: 0.12), width: 0.6)
                : null,
            textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          onPressed: onPressed,
          child: Text(label),
        ),
      ),
    );
  }
}
