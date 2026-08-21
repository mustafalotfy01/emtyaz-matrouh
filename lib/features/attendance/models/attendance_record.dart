enum AttendanceStatus {
  present,
  late,
  absent,
  earlyLeave,
  excused;

  String get displayNameAr {
    switch (this) {
      case AttendanceStatus.present:
        return 'حاضر';
      case AttendanceStatus.late:
        return 'متأخر';
      case AttendanceStatus.absent:
        return 'غائب';
      case AttendanceStatus.earlyLeave:
        return 'انصراف مبكر';
      case AttendanceStatus.excused:
        return 'إجازة معتمدة';
    }
  }
}

class AttendanceRecord {
  final String id;
  final String studentId;
  final String studentName;
  final String departmentName;

  final DateTime checkInTime;
  final DateTime? checkOutTime;

  // Check-in location
  final double checkInLat;
  final double checkInLon;
  final double? checkInGpsAccuracy;

  // Check-out location (optional)
  final double? checkOutLat;
  final double? checkOutLon;

  // Geofence audit
  final double? geofenceDistanceMeters;
  final bool isGeofenceVerified;

  // Biometric audit
  final bool isBiometricVerified;

  /// How identity was verified: 'fingerprint', 'face', 'pin', 'webauthn', 'web_session'
  final String biometricMethod;

  final AttendanceStatus status;
  final int lateMinutes;
  final int earlyLeaveMinutes;

  AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.departmentName,
    required this.checkInTime,
    this.checkOutTime,
    required this.checkInLat,
    required this.checkInLon,
    this.checkInGpsAccuracy,
    this.checkOutLat,
    this.checkOutLon,
    this.geofenceDistanceMeters,
    this.isGeofenceVerified = true,
    this.isBiometricVerified = true,
    this.biometricMethod = 'fingerprint',
    this.status = AttendanceStatus.present,
    this.lateMinutes = 0,
    this.earlyLeaveMinutes = 0,
  });

  AttendanceRecord copyWith({
    DateTime? checkOutTime,
    double? checkOutLat,
    double? checkOutLon,
    AttendanceStatus? status,
    int? earlyLeaveMinutes,
  }) {
    return AttendanceRecord(
      id: id,
      studentId: studentId,
      studentName: studentName,
      departmentName: departmentName,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      checkInLat: checkInLat,
      checkInLon: checkInLon,
      checkInGpsAccuracy: checkInGpsAccuracy,
      checkOutLat: checkOutLat ?? this.checkOutLat,
      checkOutLon: checkOutLon ?? this.checkOutLon,
      geofenceDistanceMeters: geofenceDistanceMeters,
      isGeofenceVerified: isGeofenceVerified,
      isBiometricVerified: isBiometricVerified,
      biometricMethod: biometricMethod,
      status: status ?? this.status,
      lateMinutes: lateMinutes,
      earlyLeaveMinutes: earlyLeaveMinutes ?? this.earlyLeaveMinutes,
    );
  }
}
