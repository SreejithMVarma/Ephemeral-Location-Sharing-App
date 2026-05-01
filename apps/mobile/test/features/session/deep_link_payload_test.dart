import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/session/domain/deep_link_payload.dart';

void main() {
  test('deep link payload serializes compact JSON keys', () {
    const payload = DeepLinkPayload(sessionId: 'abc', passkey: '1234', region: 'us-east');

    final decoded = jsonDecode(payload.toMinifiedJson()) as Map<String, dynamic>;

    expect(decoded, {'s': 'abc', 'p': '1234', 'r': 'us-east'});
  });

  test('deep link payload generates join URL', () {
    const payload = DeepLinkPayload(sessionId: 'abc', passkey: '1234', region: 'us-east');

    expect(payload.toLink('radarapp'), 'radarapp://join?s=abc&p=1234&r=us-east');
  });
}
