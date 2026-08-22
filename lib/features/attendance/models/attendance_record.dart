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

  static AttendanceStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'late':
        return AttendanceStatus.late;
      case 'absent':
        return AttendanceStatus.absent;
      case 'early_leave':
        return AttendanceStatus.earlyLeave;
      case 'excused':
        return AttendanceStatus.excused;
      case 'present':
      default:
        return AttendanceStatus.present;
    }
  }

  String toDbString() {
    switch (this) {
      case AttendanceStatus.late:
        return 'late';
      case AttendanceStatus.absent:
        return 'absent';
      case AttendanceStatus.earlyLeave:
        return 'early_leave';
      case AttendanceStatus.excused:
        return 'excused';
      case AttendanceStatus.present:
        return 'present';
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

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? 'طالب امتياز',
      departmentName: json['departments'] != null && json['departments']['name_ar'] != null
          ? json['departments']['name_ar'].toString()
          : (json['department_name']?.toString() ?? 'قسم الطوارئ والعناية'),
      checkInTime: json['check_in_time'] != null
          ? DateTime.parse(json['check_in_time'].toString())
          : DateTime.now(),
      checkOutTime: json['check_out_time'] != null
          ? DateTime.parse(json['check_out_time'].toString())
          : null,
      checkInLat: (json['check_in_latitude'] as num?)?.toDouble() ?? 31.3543,
      checkInLon: (json['check_in_longitude'] as num?)?.toDouble() ?? 27.2373,
      checkInGpsAccuracy: (json['gps_accuracy'] as num?)?.toDouble(),
      checkOutLat: (json['check_out_latitude'] as num?)?.toDouble(),
      checkOutLon: (json['check_out_longitude'] as num?)?.toDouble(),
      geofenceDistanceMeters: (json['geofence_distance'] as num?)?.toDouble(),
      isGeofenceVerified: json['geofence_status'] == true,
      isBiometricVerified: json['biometric_verified'] == true,
      biometricMethod: json['biometric_method']?.toString() ?? 'fingerprint',
      status: AttendanceStatus.fromString(json['status']?.toString()),
      lateMinutes: (json['late_minutes'] as num?)?.toInt() ?? 0,
      earlyLeaveMinutes: (json['early_leave_minutes'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toSupabasePayload() {
    return {
      'student_id': studentId,
      'check_in_time': checkInTime.toIso8601String(),
      if (checkOutTime != null) 'check_out_time': checkOutTime!.toIso8601String(),
      'check_in_latitude': checkInLat,
      'check_in_longitude': checkInLon,
      'geofence_status': isGeofenceVerified,
      'biometric_verified': isBiometricVerified,
      'status': status.toDbString(),
      'late_minutes': lateMinutes,
    };
  }

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
