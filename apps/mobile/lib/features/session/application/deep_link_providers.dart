import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_router.dart';
import '../infrastructure/deep_link_service.dart';

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  return DeepLinkService();
});

final deepLinkBootstrapProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(deepLinkServiceProvider);
  final initial = await service.getInitial();
  if (initial != null) {
    final router = ref.read(appRouterProvider);
    router.go(initial.toString());
  }
});
