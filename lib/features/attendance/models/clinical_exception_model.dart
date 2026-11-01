import 'package:flutter/foundation.dart';
import '../../roster/models/roster_entry.dart';

@immutable
class ClinicalExceptionModel {
  final String id;
  final String studentId;
  final String? studentName;
  final String? groupId;
  final String? departmentId;
  final String? departmentName;
  final DateTime exceptionDate;
  final ShiftType shiftType;
  final String impact;
  final String impactDescriptionAr;
  final String? note;
  final String recordedBy;
  final String? recordedByName;
  final DateTime createdAt;

  const ClinicalExceptionModel({
    required this.id,
    required this.studentId,
    this.studentName,
    this.groupId,
    this.departmentId,
    this.departmentName,
    required this.exceptionDate,
    required this.shiftType,
    required this.impact,
    required this.impactDescriptionAr,
    this.note,
    required this.recordedBy,
    this.recordedByName,
    required this.createdAt,
  });

  /// Rule-based helper: Long shift arrives at 14:00, Morning is absent
  static String calculateImpact(ShiftType shift) {
    if (shift == ShiftType.long) {
      return 'long_shift_late_arrival_2pm';
    } else if (shift == ShiftType.morning) {
      return 'morning_shift_absent';
    }
    return 'standard_exception';
  }

  static String calculateImpactAr(ShiftType shift) {
    if (shift == ShiftType.long) {
      return 'شيفت طويل (Long): حضور الساعة 02:00 ظهراً';
    } else if (shift == ShiftType.morning) {
      return 'شيفت صباحي: عدم حضور هذا الشيفت';
    }
    return 'استثناء عارضة معتمد';
  }

  factory ClinicalExceptionModel.fromJson(Map<String, dynamic> json) {
    final shift = ShiftType.fromString(json['shift_type']?.toString());
    return ClinicalExceptionModel(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['profiles'] is Map ? json['profiles']['full_name']?.toString() : json['student_name']?.toString(),
      groupId: json['group_id']?.toString(),
      departmentId: json['department_id']?.toString(),
      departmentName: json['departments'] is Map ? json['departments']['name_ar']?.toString() : json['department_name']?.toString(),
      exceptionDate: json['exception_date'] != null
          ? DateTime.parse(json['exception_date'].toString())
          : DateTime.now(),
      shiftType: shift,
      impact: json['impact']?.toString() ?? calculateImpact(shift),
      impactDescriptionAr: json['impact_description_ar']?.toString() ?? calculateImpactAr(shift),
      note: json['note']?.toString(),
      recordedBy: json['recorded_by']?.toString() ?? '',
      recordedByName: json['recorded_by_profile'] is Map ? json['recorded_by_profile']['full_name']?.toString() : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'group_id': groupId,
      'department_id': departmentId,
      'exception_date': '${exceptionDate.year}-${exceptionDate.month.toString().padLeft(2, '0')}-${exceptionDate.day.toString().padLeft(2, '0')}',
      'shift_type': shiftType.name,
      'impact': impact,
      'impact_description_ar': impactDescriptionAr,
      'note': note,
      'recorded_by': recordedBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
