import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../../features/auth/application/auth_state.dart';
import '../../features/compass/presentation/compass_view.dart';
import '../../features/radar/presentation/radar_view.dart';
import '../../features/session/presentation/entry_screen.dart';
import '../../features/session/presentation/join_screen.dart';
import '../../features/session/presentation/qr_scanner_screen.dart';
import '../../features/session/presentation/session_setup_screen.dart';
import '../../features/session/presentation/waiting_room_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthed = ref.read(isAuthenticatedProvider);
      final joining = state.uri.path == '/join';
      final scanning = state.uri.path == '/scan-qr';
      final setupPath = state.uri.path == '/session-setup';
      final waitingPath = state.uri.path == '/waiting';
      final radarPath = state.uri.path == '/radar';
      if (!isAuthed && !joining && !scanning && !setupPath && !waitingPath && !radarPath && state.uri.path != '/') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const EntryScreen(),
      ),
      GoRoute(
        path: '/scan-qr',
        builder: (context, state) => const QrScannerScreen(),
      ),
      GoRoute(
        path: '/session-setup',
        builder: (context, state) => const SessionSetupScreen(),
      ),
      GoRoute(
        path: '/join',
        builder: (context, state) {
          final sessionId = state.uri.queryParameters['s'] ?? '';
          final passkey = state.uri.queryParameters['p'] ?? '';
          final displayName = state.uri.queryParameters['d'];
          final privacyMode = state.uri.queryParameters['m'];
          return JoinScreen(
            sessionId: sessionId,
            passkey: passkey,
            autoJoinDisplayName: displayName,
            autoJoinPrivacyMode: privacyMode,
          );
        },
      ),
      GoRoute(
        path: '/waiting',
        builder: (context, state) {
          final link = Uri.decodeComponent(state.uri.queryParameters['link'] ?? '');
          return WaitingRoomScreen(link: link);
        },
      ),
      GoRoute(
        path: '/radar',
        builder: (context, state) => const RadarView(),
      ),
      GoRoute(
        path: '/compass/:userId',
        pageBuilder: (context, state) {
          final userId = state.pathParameters['userId'] ?? 'unknown';
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: CompassView(userId: userId),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final fade = CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);
              return FadeTransition(opacity: fade, child: child);
            },
            transitionDuration: const Duration(milliseconds: 400),
          );
        },
      ),
    ],
    errorBuilder: (context, state) => const EntryScreen(),
  );
});
