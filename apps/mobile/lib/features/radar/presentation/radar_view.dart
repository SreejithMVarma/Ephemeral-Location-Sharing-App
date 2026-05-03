import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/app_animations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/radar_card.dart';
import '../../../core/widgets/radar_bottom_sheet.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../session/application/session_state.dart';
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
  bool _sessionEndedHandled = false;
  // Snapshot blips stored locally so the FutureProvider is not re-watched
  // on every animation frame (which caused a /members API call every ~300ms).
  Map<String, RadarBlip> _snapshotBlips = {};
  // Track known peer IDs so we can detect when a brand-new user appears.
  final Set<String> _knownPeerIds = {};
  // Proximity tracking: last distance per peer and last time we alerted.
  final Map<String, double> _lastDistance = {};
  final Map<String, int> _lastProximityAlertMs = {};
  // Distance threshold (metres) to trigger a "met" alert.
  static const double _metThresholdM = 30.0;
  // Minimum gap between repeated alerts for the same peer (ms).
  static const int _metCooldownMs = 60000;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(radarBlipsProvider.notifier).setPaused(false);
      // Reset session-ended flag when entering the radar
      ref.read(sessionEndedProvider.notifier).state = false;
      _sessionEndedHandled = false;
    });
  }

  @override
  void dispose() {
    _sweepController.dispose();
    _entryController.dispose();
    ref.read(radarBlipsProvider.notifier).setPaused(true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveBlips = ref.watch(radarBlipsProvider);

    // Watch the snapshot only to merge new results into local state —
    // never drive animation rebuilds from this provider directly.
    ref.listen<AsyncValue<Map<String, RadarBlip>>>(liveRadarBlipsProvider, (_, next) {
      next.whenData((snapshot) {
        if (mounted) setState(() => _snapshotBlips = snapshot);
      });
    });

    // Detect new peers and proximity alerts when blips update.
    ref.listen<Map<String, RadarBlip>>(radarBlipsProvider, (prev, next) {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final entry in next.entries) {
        final id = entry.key;
        final blip = entry.value;
        final name = blip.displayName.isNotEmpty ? blip.displayName : id;

        // ── New peer appeared ──
        if (!_knownPeerIds.contains(id)) {
          _knownPeerIds.add(id);
          debugPrint('[NEW PEER] *** $name ($id) just appeared on radar ***');
          if (!mounted) continue;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$name appeared on radar!'),
              backgroundColor: const Color(0xFF00C853),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }

        // ── Proximity "met" alert ──
        final prevDist = _lastDistance[id] ?? double.infinity;
        final currDist = blip.distanceMeters;
        _lastDistance[id] = currDist;

        final lastAlert = _lastProximityAlertMs[id] ?? 0;
        final cooldownOk = (now - lastAlert) >= _metCooldownMs;

        if (currDist < _metThresholdM && prevDist >= _metThresholdM && cooldownOk) {
          _lastProximityAlertMs[id] = now;
          debugPrint('[NEAR] met $name at ${currDist.toStringAsFixed(0)}m');
          HapticFeedback.heavyImpact();
          if (!mounted) continue;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Text('🎉 ', style: TextStyle(fontSize: 18)),
                  Expanded(
                    child: Text(
                      "You've reached $name!",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF6200EA),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    });

    final allIds = <String>{..._snapshotBlips.keys, ...liveBlips.keys}.toList()..sort();

    final blips = allIds.map((id) {
      if (liveBlips.containsKey(id)) return liveBlips[id]!;
      return _snapshotBlips[id]!;
    }).toList(growable: false);

    final session = ref.watch(sessionStateProvider);
    final sessionName = session?.sessionName ?? 'Unnamed Session';

    // Listen for SESSION_ENDED and show dialog once
    final sessionEnded = ref.watch(sessionEndedProvider);
    if (sessionEnded && !_sessionEndedHandled) {
      _sessionEndedHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showSessionEndedDialog(context));
    }

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
                          ref.read(sessionStateProvider.notifier).clearSession();
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
                            // Avatar row
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
                            // Member list rows — tap to open DM
                            for (final blip in blips)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    ChatScreen.show(context, initialDmUserId: blip.userId);
                                  },
                                  child: RadarCard(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(blip.displayName, style: Theme.of(context).textTheme.titleMedium),
                                              Text(
                                                '${blip.distanceMeters.round()}m away',
                                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textDim),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            const Icon(Icons.chat_bubble_outline, color: AppColors.blue, size: 16),
                                            const SizedBox(width: 6),
                                            Text('${blip.distanceMeters.round()}m', style: Theme.of(context).textTheme.labelSmall),
                                          ],
                                        ),
                                      ],
                                    ),
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
          // Chat FAB — above the filter FAB
          Positioned(
            bottom: 158,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'chat_fab',
              backgroundColor: AppColors.blue.withValues(alpha: 0.15),
              foregroundColor: AppColors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(99),
                side: BorderSide(color: AppColors.blue.withValues(alpha: 0.45), width: 0.6),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                ChatScreen.show(context);
              },
              child: const Icon(Icons.chat_bubble_outline_rounded),
            ),
          ),
          // Filter / privacy FAB
          Positioned(
            bottom: 104,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'filter_fab',
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
                      ref.read(sessionStateProvider.notifier).clearSession();
                      context.go('/');
                    },
                  ),
                );
              },
              child: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
    );
  }

  void _showSessionEndedDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.amber),
            const SizedBox(width: 8),
            const Text('Session Ended'),
          ],
        ),
        content: const Text('The host has ended this radar session.'),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(sessionStateProvider.notifier).clearSession();
              if (mounted) context.go('/');
            },
            child: const Text('OK', style: TextStyle(color: AppColors.bg)),
          ),
        ],
      ),
    );
  }
}
