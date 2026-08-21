class GeofenceZone {
  final String id;
  final String hospitalName;
  final String departmentName;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  /// Max GPS accuracy (meters) acceptable for check-in in this zone.
  /// Defaults to [AppConfig.gpsAccuracyThresholdMeters] but can be overridden per zone.
  final double gpsAccuracyThresholdMeters;

  GeofenceZone({
    required this.id,
    required this.hospitalName,
    required this.departmentName,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 150.0,
    this.gpsAccuracyThresholdMeters = 30.0,
  });

  GeofenceZone copyWith({
    String? hospitalName,
    String? departmentName,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    double? gpsAccuracyThresholdMeters,
  }) {
    return GeofenceZone(
      id: id,
      hospitalName: hospitalName ?? this.hospitalName,
      departmentName: departmentName ?? this.departmentName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      gpsAccuracyThresholdMeters:
          gpsAccuracyThresholdMeters ?? this.gpsAccuracyThresholdMeters,
    );
  }

  static GeofenceZone matrouhGeneralHospitalEmergency() {
    return GeofenceZone(
      id: 'zone-matrouh-1',
      hospitalName: 'مستشفى مطروح العام',
      departmentName: 'قسم الطوارئ والعنايات',
      latitude: 31.3543,
      longitude: 27.2373,
      radiusMeters: 150.0,
      gpsAccuracyThresholdMeters: 30.0,
    );
  }
}
