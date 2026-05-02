import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/app_animations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/radar_card.dart';
import '../../../core/widgets/radar_bottom_sheet.dart';
import '../../chat/presentation/chat_overlay.dart';
import '../../session/application/session_state.dart';
import '../../session/infrastructure/location_broadcaster.dart';
import '../../session/presentation/privacy_sheet.dart';
import '../application/radar_providers.dart';
import '../domain/radar_blip.dart';
import 'radar_canvas.dart';

class RadarView extends ConsumerStatefulWidget {
  const RadarView({super.key});

  @override
  ConsumerState<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends ConsumerState<RadarView> with TickerProviderStateMixin {
  late final AnimationController _sweepController;
  late final AnimationController _entryController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: AppAnimations.radarSweep,
    )..repeat();
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    )..forward();

    // Connect to WebSocket and start broadcasting own location once the
    // widget tree is ready (providers are available via ref).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(radarWsLifecycleProvider.notifier).connect();
      ref.read(locationBroadcasterProvider)?.start();
    });
  }

  @override
  void dispose() {
    _sweepController.dispose();
    _entryController.dispose();
    // Disconnect WS and stop GPS broadcasting when leaving radar.
    ref.read(radarWsLifecycleProvider.notifier).disconnect();
    ref.read(locationBroadcasterProvider)?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blipIds = ref.watch(radarBlipIdsProvider);
    final blips = blipIds
        .map((id) => ref.watch(radarBlipProvider(id)))
        .whereType<RadarBlip>()
        .toList(growable: false);
    final session = ref.watch(sessionStateProvider);
    final sessionName = session?.sessionName ?? 'Unnamed Session';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sessionName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            Text(
                              '${blips.length} active',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.green),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          context.go('/');
                        },
                        icon: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.danger.withValues(alpha: 0.15),
                            border: Border.all(color: AppColors.danger.withValues(alpha: 0.45), width: 0.8),
                          ),
                          child: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_sweepController, _entryController]),
                    builder: (context, _) {
                      return Transform.scale(
                        scale: Tween<double>(begin: 0.92, end: 1).transform(_entryController.value),
                        child: Opacity(
                          opacity: Curves.easeOut.transform(_entryController.value),
                          child: RadarCanvas(
                            blips: blips,
                            sweepAngle: _sweepController.value * 360,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: DraggableScrollableSheet(
                    initialChildSize: 0.22,
                    minChildSize: 0.18,
                    maxChildSize: 0.6,
                    builder: (context, scrollController) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.surface.withValues(alpha: 0.88),
                              AppColors.surface2.withValues(alpha: 0.96),
                            ],
                          ),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          border: Border.all(color: AppColors.white.withValues(alpha: 0.08), width: 0.6),
                        ),
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
                          children: [
                            Center(
                              child: Container(
                                width: 32,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: AppColors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              height: 78,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: blips.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  final blip = blips[index];
                                  final curveStart = (index * 0.08).clamp(0, 0.9).toDouble();
                                  final appear = CurvedAnimation(
                                    parent: _entryController,
                                    curve: Interval(curveStart, 1, curve: Curves.elasticOut),
                                  );
                                  return ScaleTransition(
                                    scale: appear,
                                    child: GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        context.push('/compass/${blip.userId}');
                                      },
                                      child: Column(
                                        children: [
                                          Hero(
                                            tag: 'avatar-${blip.userId}',
                                            child: Container(
                                              width: 42,
                                              height: 42,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: AppColors.blue.withValues(alpha: 0.14),
                                                border: Border.all(color: AppColors.blue.withValues(alpha: 0.65), width: 1),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                blip.displayName.isEmpty ? '?' : blip.displayName[0].toUpperCase(),
                                                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.blue, fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${blip.distanceMeters.round()}m',
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textDim),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            for (final blip in blips)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: RadarCard(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(blip.displayName, style: Theme.of(context).textTheme.titleMedium),
                                      ),
                                      Text('${blip.distanceMeters.round()}m', style: Theme.of(context).textTheme.labelSmall),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 104,
            right: 16,
            child: FloatingActionButton.small(
              backgroundColor: AppColors.blue.withValues(alpha: 0.15),
              foregroundColor: AppColors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(99),
                side: BorderSide(color: AppColors.blue.withValues(alpha: 0.45), width: 0.6),
              ),
              onPressed: () {
                RadarBottomSheet.show(
                  context,
                  PrivacySheet(
                    onLeave: () {
                      Navigator.of(context).pop();
                      context.go('/');
                    },
                  ),
                );
              },
              child: const Icon(Icons.tune_rounded),
            ),
          ),
          const ChatOverlay(),
        ],
      ),
    );
  }
}
