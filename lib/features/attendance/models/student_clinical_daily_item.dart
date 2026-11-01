import 'package:flutter/foundation.dart';
import '../../auth/models/user_profile.dart';
import '../../roster/models/roster_entry.dart';
import '../models/attendance_record.dart';
import 'clinical_compensation_model.dart';
import 'clinical_exception_model.dart';
import 'clinical_permission_model.dart';

enum ClinicalAttendanceState {
  unrecorded,
  present,
  absent,
  exception; // عارضة

  String get displayNameAr {
    switch (this) {
      case ClinicalAttendanceState.present:
        return 'موجود';
      case ClinicalAttendanceState.absent:
        return 'غياب';
      case ClinicalAttendanceState.exception:
        return 'عارضة';
      case ClinicalAttendanceState.unrecorded:
        return 'لم يتم التسجيل';
    }
  }
}

@immutable
class StudentClinicalDailyItem {
  final UserProfile student;
  final RosterEntry? todayShift;
  final AttendanceRecord? todayAttendance;
  final ClinicalExceptionModel? todayException;
  final ClinicalPermissionModel? todayPermission;
  final ClinicalCompensationModel? todayCompensation;

  /// In-memory pending selection before clicking "Save Batch"
  final ClinicalAttendanceState pendingState;
  final bool isDirty;

  const StudentClinicalDailyItem({
    required this.student,
    this.todayShift,
    this.todayAttendance,
    this.todayException,
    this.todayPermission,
    this.todayCompensation,
    this.pendingState = ClinicalAttendanceState.unrecorded,
    this.isDirty = false,
  });

  String get studentId => student.id;
  String get studentName => student.fullName;
  String get universityCode => student.universityCode;
  String? get avatarUrl => student.avatarUrl;

  ShiftType get effectiveShiftType => todayShift?.shiftType ?? ShiftType.morning;

  String get shiftDisplayNameAr {
    if (todayShift == null) return 'غير محدد بالروستر';
    switch (todayShift!.shiftType) {
      case ShiftType.morning:
        return 'صباحي (08:00 - 14:00)';
      case ShiftType.evening:
        return 'مسائي (14:00 - 20:00)';
      case ShiftType.long:
        return 'طويل Long (08:00 - 20:00)';
      case ShiftType.night:
        return 'سهر Night (20:00 - 08:00)';
      case ShiftType.absence:
        return 'غياب مسبق';
      case ShiftType.leave:
        return 'راحة / إجازة';
    }
  }

  bool get isOffDay =>
      todayShift?.shiftType == ShiftType.leave ||
      todayShift?.shiftType == ShiftType.absence;

  bool get hasException => todayException != null;
  bool get hasPermission => todayPermission != null;
  bool get hasCompensation => todayCompensation != null;

  StudentClinicalDailyItem copyWith({
    UserProfile? student,
    RosterEntry? todayShift,
    AttendanceRecord? todayAttendance,
    ClinicalExceptionModel? todayException,
    ClinicalPermissionModel? todayPermission,
    ClinicalCompensationModel? todayCompensation,
    ClinicalAttendanceState? pendingState,
    bool? isDirty,
  }) {
    return StudentClinicalDailyItem(
      student: student ?? this.student,
      todayShift: todayShift ?? this.todayShift,
      todayAttendance: todayAttendance ?? this.todayAttendance,
      todayException: todayException ?? this.todayException,
      todayPermission: todayPermission ?? this.todayPermission,
      todayCompensation: todayCompensation ?? this.todayCompensation,
      pendingState: pendingState ?? this.pendingState,
      isDirty: isDirty ?? this.isDirty,
    );
  }
}
