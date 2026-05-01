import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/radar_button.dart';
import '../../../core/widgets/radar_bottom_sheet.dart';
import '../application/privacy_providers.dart';

class PrivacySheet extends ConsumerWidget {
  const PrivacySheet({super.key, required this.onLeave});

  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(privacyModeProvider);
    final apply = ref.watch(applyPrivacyModeProvider);

    Widget modeTile(PrivacyMode mode, String label, String subtitle, Color color) {
      final selected = current == mode;
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          apply(mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? AppColors.green.withValues(alpha: 0.07) : AppColors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.green.withValues(alpha: 0.3) : AppColors.white.withValues(alpha: 0.08),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                  border: Border.all(color: color.withValues(alpha: selected ? 1 : 0.4), width: 1),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? color : Colors.transparent,
                    border: Border.all(color: color, width: 1),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: selected ? AppColors.white : AppColors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(subtitle, style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
              if (selected)
                Text('active', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.green)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your visibility', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Others see what you broadcast', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textDim)),
          const SizedBox(height: 16),
          modeTile(PrivacyMode.directionOnly, 'Direction only', 'Arrow bearing, no distance', AppColors.purple),
          modeTile(PrivacyMode.directionDistance, 'Direction + distance', 'Arrow + how far you are', AppColors.green),
          modeTile(PrivacyMode.fullMap, 'Full map', 'Exact GPS on map', AppColors.blue),
          const SizedBox(height: 8),
          Divider(color: AppColors.danger.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              RadarBottomSheet.show(
                context,
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Leave radar?', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                        'Your blip disappears for everyone.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textDim),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: RadarButton(
                              label: 'Cancel',
                              variant: RadarButtonVariant.secondary,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RadarButton(
                              label: 'Leave',
                              variant: RadarButtonVariant.danger,
                              onPressed: () {
                                HapticFeedback.heavyImpact();
                                Navigator.of(context).pop();
                                onLeave();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.22), width: 0.8),
              ),
              alignment: Alignment.center,
              child: Text('Leave session', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
