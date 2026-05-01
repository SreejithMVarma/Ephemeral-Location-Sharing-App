import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class RadarTextField extends StatelessWidget {
  const RadarTextField({
    super.key,
    this.controller,
    required this.label,
  });

  final TextEditingController? controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: TextField(
        controller: controller,
        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.surface2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(color: AppColors.white.withValues(alpha: 0.12), width: 0.6),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(color: AppColors.green.withValues(alpha: 0.5), width: 1),
          ),
        ),
      ),
    );
  }
}
