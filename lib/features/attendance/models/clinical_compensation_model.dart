import 'package:flutter/foundation.dart';
import '../../roster/models/roster_entry.dart';

enum CompensationStatus {
  due,
  completed,
  cancelled;

  String get displayNameAr {
    switch (this) {
      case CompensationStatus.due:
        return 'مستحق';
      case CompensationStatus.completed:
        return 'تم تنفيذه';
      case CompensationStatus.cancelled:
        return 'ملغي';
    }
  }

  static CompensationStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'completed':
        return CompensationStatus.completed;
      case 'cancelled':
        return CompensationStatus.cancelled;
      case 'due':
      default:
        return CompensationStatus.due;
    }
  }
}

@immutable
class ClinicalCompensationModel {
  final String id;
  final String studentId;
  final String? studentName;
  final String? groupId;
  final String? departmentId;
  final String? departmentName;
  final DateTime? originalDate;
  final DateTime compensationDate;
  final ShiftType shiftType;
  final String? reason;
  final String? notes;
  final CompensationStatus status;
  final String recordedBy;
  final String? recordedByName;
  final DateTime? executedAt;
  final DateTime createdAt;

  const ClinicalCompensationModel({
    required this.id,
    required this.studentId,
    this.studentName,
    this.groupId,
    this.departmentId,
    this.departmentName,
    this.originalDate,
    required this.compensationDate,
    required this.shiftType,
    this.reason,
    this.notes,
    this.status = CompensationStatus.due,
    required this.recordedBy,
    this.recordedByName,
    this.executedAt,
    required this.createdAt,
  });

  factory ClinicalCompensationModel.fromJson(Map<String, dynamic> json) {
    return ClinicalCompensationModel(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['profiles'] is Map ? json['profiles']['full_name']?.toString() : json['student_name']?.toString(),
      groupId: json['group_id']?.toString(),
      departmentId: json['department_id']?.toString(),
      departmentName: json['departments'] is Map ? json['departments']['name_ar']?.toString() : json['department_name']?.toString(),
      originalDate: json['original_date'] != null
          ? DateTime.parse(json['original_date'].toString())
          : null,
      compensationDate: json['compensation_date'] != null
          ? DateTime.parse(json['compensation_date'].toString())
          : DateTime.now(),
      shiftType: ShiftType.fromString(json['shift_type']?.toString()),
      reason: json['reason']?.toString(),
      notes: json['notes']?.toString(),
      status: CompensationStatus.fromString(json['status']?.toString()),
      recordedBy: json['recorded_by']?.toString() ?? '',
      recordedByName: json['recorded_by_profile'] is Map ? json['recorded_by_profile']['full_name']?.toString() : null,
      executedAt: json['executed_at'] != null
          ? DateTime.parse(json['executed_at'].toString())
          : null,
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
      'original_date': originalDate != null
          ? '${originalDate!.year}-${originalDate!.month.toString().padLeft(2, '0')}-${originalDate!.day.toString().padLeft(2, '0')}'
          : null,
      'compensation_date': '${compensationDate.year}-${compensationDate.month.toString().padLeft(2, '0')}-${compensationDate.day.toString().padLeft(2, '0')}',
      'shift_type': shiftType.name,
      'reason': reason,
      'notes': notes,
      'status': status.name,
      'recorded_by': recordedBy,
      'executed_at': executedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  ClinicalCompensationModel copyWith({
    CompensationStatus? status,
    DateTime? executedAt,
  }) {
    return ClinicalCompensationModel(
      id: id,
      studentId: studentId,
      studentName: studentName,
      groupId: groupId,
      departmentId: departmentId,
      departmentName: departmentName,
      originalDate: originalDate,
      compensationDate: compensationDate,
      shiftType: shiftType,
      reason: reason,
      notes: notes,
      status: status ?? this.status,
      recordedBy: recordedBy,
      recordedByName: recordedByName,
      executedAt: executedAt ?? this.executedAt,
      createdAt: createdAt,
    );
  }
}
