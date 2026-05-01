import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/compass/domain/bearing_utils.dart';

void main() {
  group('bearing utils', () {
    test('normalize360 wraps negative and positive values', () {
      expect(normalize360(-15), 345);
      expect(normalize360(370), 10);
    });

    test('shortestDelta returns shortest signed arc', () {
      expect(shortestDelta(350, 10), 20);
      expect(shortestDelta(10, 350), -20);
    });

    test('computeBearing computes expected cardinal direction', () {
      final north = computeBearing(
        fromLat: 37.7749,
        fromLng: -122.4194,
        toLat: 37.7849,
        toLng: -122.4194,
      );
      expect(north, inInclusiveRange(0, 1));
    });

    test('relativeBearing subtracts heading and normalizes', () {
      expect(relativeBearing(absoluteBearing: 20, deviceHeading: 350), 30);
    });
  });
}
