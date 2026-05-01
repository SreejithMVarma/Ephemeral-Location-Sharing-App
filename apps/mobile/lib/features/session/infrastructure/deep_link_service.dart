import 'dart:async';

import 'package:app_links/app_links.dart';

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();

  Future<Uri?> getInitial() => _appLinks.getInitialLink();

  Stream<Uri> get stream => _appLinks.uriLinkStream;
}
