import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/app_config.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/radar_snackbar.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  late MobileScannerController _controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      cameraResolution: const Size(1920, 1080),
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
      autoZoom: true,
      lensType: CameraLensType.normal,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleScan(BarcodeCapture capture) async {
    if (_isProcessing || capture.barcodes.isEmpty) {
      return;
    }

    try {
      _isProcessing = true;

      final raw = capture.barcodes.first.rawValue;
      debugPrint('[QrScanner] raw QR scanned: $raw');

      if (raw == null || raw.isEmpty) {
        debugPrint('[QrScanner] QR value is empty');
        _isProcessing = false;
        return;
      }

      final uri = Uri.tryParse(raw);
      if (uri == null) {
        debugPrint('[QrScanner] failed to parse URI: $raw');
        if (mounted) {
          RadarSnackbar.show(
            context,
            message: 'Malformed deep link',
            type: RadarSnackType.warning,
          );
        }
        _isProcessing = false;
        return;
      }

      debugPrint('[QrScanner] parsed URI: $uri');
      debugPrint('[QrScanner] URI scheme: ${uri.scheme}');
      debugPrint('[QrScanner] URI host: ${uri.host}');
      debugPrint('[QrScanner] URI path: ${uri.path}');

      final config = ref.read(appConfigProvider);
      debugPrint('[QrScanner] expected deep link scheme: ${config.deepLinkScheme}');

      // Check if scheme is valid: custom scheme OR http/https
      final schemeOk = uri.scheme.isNotEmpty && (
        (config.deepLinkScheme.isNotEmpty && uri.scheme == config.deepLinkScheme) ||
        uri.isScheme('http') ||
        uri.isScheme('https')
      );

      if (!schemeOk) {
        debugPrint('[QrScanner] ❌ rejected: invalid scheme "${uri.scheme}" (expected: "${config.deepLinkScheme}")');
        if (mounted) {
          RadarSnackbar.show(
            context,
            message: 'Invalid QR code scheme',
            type: RadarSnackType.warning,
          );
        }
        _isProcessing = false;
        return;
      }

      debugPrint('[QrScanner] ✓ scheme is valid');

      // Check if this is a join target
      final isJoinTarget =
          uri.host == 'join' ||
          uri.path == '/join' ||
          uri.path == 'join';

      debugPrint('[QrScanner] is join target: $isJoinTarget');

      // Extract parameters
      final sessionId = uri.queryParameters['s'];
      final passkey = uri.queryParameters['p'];
      final region = uri.queryParameters['r'] ?? 'us-east';

      debugPrint('[QrScanner] session_id: $sessionId');
      debugPrint('[QrScanner] passkey: ${passkey != null ? '[REDACTED]' : 'null'}');
      debugPrint('[QrScanner] region: $region');

      // Validate required parameters
      final hasJoinParams =
          sessionId != null &&
          sessionId.isNotEmpty &&
          passkey != null &&
          passkey.isNotEmpty;

      if (!isJoinTarget || !hasJoinParams) {
        debugPrint('[QrScanner] ❌ rejected: invalid join target or missing params');
        if (mounted) {
          RadarSnackbar.show(
            context,
            message: 'Invalid radar code',
            type: RadarSnackType.warning,
          );
        }
        _isProcessing = false;
        return;
      }

      debugPrint('[QrScanner] ✅ valid radar code - navigating to join with s=$sessionId, p=[REDACTED], r=$region');

      // Stop camera before navigation
      await _controller.stop();

      if (mounted) {
        // Navigate with all parameters
        context.pop(); // Close scanner
        context.push('/join?s=$sessionId&p=$passkey&r=$region');
      }
    } catch (e, st) {
      debugPrint('[QrScanner] ❌ error: $e\n$st');
      _isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full-screen camera preview
          MobileScanner(
            controller: _controller,
            onDetect: _handleScan,
          ),

          // Close button (top left)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: CircleAvatar(
              backgroundColor: AppColors.black.withOpacity(0.6),
              child: IconButton(
                icon: const Icon(Icons.close, color: AppColors.white),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.pop();
                },
              ),
            ),
          ),

          // Scan overlay (center)
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.primary,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Align QR Code',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.white,
                      shadows: [
                        Shadow(
                          color: AppColors.black.withOpacity(0.7),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Instruction text (bottom)
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Scan a radar code to join a session',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.white,
                  shadows: [
                    Shadow(
                      color: AppColors.black.withOpacity(0.7),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
