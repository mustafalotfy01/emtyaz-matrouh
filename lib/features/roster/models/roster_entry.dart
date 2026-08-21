enum ShiftType {
  morning,
  evening,
  long,
  night,
  absence,
  leave;

  String get displayNameAr {
    switch (this) {
      case ShiftType.morning:
        return 'صباحي (08:00 AM - 02:00 PM)';
      case ShiftType.evening:
        return 'مسائي (02:00 PM - 08:00 PM)';
      case ShiftType.long:
        return 'طويل Long (08:00 AM - 08:00 PM)';
      case ShiftType.night:
        return 'سهر Night (08:00 PM - 08:00 AM)';
      case ShiftType.absence:
        return 'غياب';
      case ShiftType.leave:
        return 'إجازة رسمية';
    }
  }

  String get shortCode {
    switch (this) {
      case ShiftType.morning:
        return 'Morning';
      case ShiftType.evening:
        return 'Evening';
      case ShiftType.long:
        return 'Long';
      case ShiftType.night:
        return 'Night';
      case ShiftType.absence:
        return 'Absence';
      case ShiftType.leave:
        return 'Leave';
    }
  }

  String get timingShortAr {
    switch (this) {
      case ShiftType.morning:
        return '08:00 - 14:00';
      case ShiftType.evening:
        return '14:00 - 20:00';
      case ShiftType.long:
        return '08:00 - 20:00';
      case ShiftType.night:
        return '20:00 - 08:00';
      case ShiftType.absence:
        return 'غياب';
      case ShiftType.leave:
        return 'إجازة';
    }
  }

  static ShiftType fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'morning':
        return ShiftType.morning;
      case 'evening':
        return ShiftType.evening;
      case 'long':
        return ShiftType.long;
      case 'night':
        return ShiftType.night;
      case 'absence':
        return ShiftType.absence;
      case 'leave':
        return ShiftType.leave;
      default:
        return ShiftType.morning;
    }
  }
}

enum ShiftStatus {
  pending,
  approved,
  rejected,
  published;

  String get displayNameAr {
    switch (this) {
      case ShiftStatus.pending:
        return 'قيد المراجعة';
      case ShiftStatus.approved:
        return 'معتمد';
      case ShiftStatus.rejected:
        return 'مرفوض';
      case ShiftStatus.published:
        return 'منشور رسميًا';
    }
  }

  static ShiftStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'approved':
        return ShiftStatus.approved;
      case 'rejected':
        return ShiftStatus.rejected;
      case 'published':
        return ShiftStatus.published;
      case 'pending':
      default:
        return ShiftStatus.pending;
    }
  }
}

class RosterEntry {
  final String id;
  final String? rosterId;
  final String studentId;
  final String studentName;
  final String departmentId;
  final String departmentName;
  final DateTime shiftDate;
  final ShiftType shiftType;
  final ShiftStatus status;
  final String? sourcePreferenceId;
  final String? preferenceType; // 'A' or 'B' or null
  final String? rejectionReason;
  final String? approvedBy;
  final DateTime? approvedAt;

  RosterEntry({
    required this.id,
    this.rosterId,
    required this.studentId,
    required this.studentName,
    required this.departmentId,
    required this.departmentName,
    required this.shiftDate,
    required this.shiftType,
    this.status = ShiftStatus.pending,
    this.sourcePreferenceId,
    this.preferenceType,
    this.rejectionReason,
    this.approvedBy,
    this.approvedAt,
  });

  bool get isApprovedOrPublished =>
      status == ShiftStatus.approved || status == ShiftStatus.published;

  factory RosterEntry.fromJson(Map<String, dynamic> json) {
    return RosterEntry(
      id: json['id']?.toString() ?? '',
      rosterId: json['roster_id']?.toString(),
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['profiles']?['full_name'] ?? json['student_name'] ?? 'طالب الامتياز',
      departmentId: json['department_id']?.toString() ?? 'a0000001-0000-0000-0000-000000000001',
      departmentName: json['departments']?['name_ar'] ?? json['department_name'] ?? 'قسم الطوارئ',
      shiftDate: DateTime.parse(json['shift_date']),
      shiftType: ShiftType.fromString(json['shift_type'] ?? json['final_shift_type']),
      status: ShiftStatus.fromString(json['status']),
      sourcePreferenceId: json['source_preference_id']?.toString(),
      preferenceType: json['preference_type']?.toString(),
      rejectionReason: json['rejection_reason'],
      approvedBy: json['approved_by']?.toString(),
      approvedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roster_id': rosterId,
      'student_id': studentId,
      'department_id': departmentId,
      'shift_date': '${shiftDate.year.toString().padLeft(4, '0')}-${shiftDate.month.toString().padLeft(2, '0')}-${shiftDate.day.toString().padLeft(2, '0')}',
      'shift_type': shiftType.name,
      'status': status.name,
      'source_preference_id': sourcePreferenceId,
      'preference_type': preferenceType,
      'rejection_reason': rejectionReason,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
    };
  }

  RosterEntry copyWith({
    String? departmentId,
    String? departmentName,
    ShiftType? shiftType,
    ShiftStatus? status,
    String? preferenceType,
    String? rejectionReason,
    String? approvedBy,
    DateTime? approvedAt,
  }) {
    return RosterEntry(
      id: id,
      rosterId: rosterId,
      studentId: studentId,
      studentName: studentName,
      departmentId: departmentId ?? this.departmentId,
      departmentName: departmentName ?? this.departmentName,
      shiftDate: shiftDate,
      shiftType: shiftType ?? this.shiftType,
      status: status ?? this.status,
      sourcePreferenceId: sourcePreferenceId,
      preferenceType: preferenceType ?? this.preferenceType,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
    );
  }
}
