class RadarBlip {
  const RadarBlip({
    required this.userId,
    required this.displayName,
    required this.bearing,
    required this.distanceMeters,
    required this.directionOnly,
    this.remoteLat,
    this.remoteLng,
  });

  final String userId;
  final String displayName;
  final double bearing;
  final double distanceMeters;
  final bool directionOnly;
  /// Last known latitude of this peer — used to recompute distance when our own GPS updates.
  final double? remoteLat;
  /// Last known longitude of this peer — used to recompute distance when our own GPS updates.
  final double? remoteLng;

  RadarBlip copyWith({
    String? userId,
    String? displayName,
    double? bearing,
    double? distanceMeters,
    bool? directionOnly,
    double? remoteLat,
    double? remoteLng,
  }) {
    return RadarBlip(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      bearing: bearing ?? this.bearing,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      directionOnly: directionOnly ?? this.directionOnly,
      remoteLat: remoteLat ?? this.remoteLat,
      remoteLng: remoteLng ?? this.remoteLng,
    );
  }
}
