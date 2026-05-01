import 'dart:math';

double degToRad(double deg) => deg * pi / 180.0;
double radToDeg(double rad) => rad * 180.0 / pi;

double normalize360(double value) {
  final mod = value % 360;
  return mod < 0 ? mod + 360 : mod;
}

double shortestDelta(double current, double target) {
  return ((target - current + 540) % 360) - 180;
}

double computeBearing({
  required double fromLat,
  required double fromLng,
  required double toLat,
  required double toLng,
}) {
  final lat1 = degToRad(fromLat);
  final lat2 = degToRad(toLat);
  final dLng = degToRad(toLng - fromLng);
  final y = sin(dLng) * cos(lat2);
  final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
  return normalize360(radToDeg(atan2(y, x)));
}

double relativeBearing({required double absoluteBearing, required double deviceHeading}) {
  return normalize360(absoluteBearing - deviceHeading);
}
