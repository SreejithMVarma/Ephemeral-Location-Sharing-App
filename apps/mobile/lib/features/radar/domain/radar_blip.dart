class RadarBlip {
  const RadarBlip({
    required this.userId,
    required this.displayName,
    required this.bearing,
    required this.distanceMeters,
    required this.directionOnly,
  });

  final String userId;
  final String displayName;
  final double bearing;
  final double distanceMeters;
  final bool directionOnly;
}
