import 'package:flutter/foundation.dart';
import '../../roster/models/roster_entry.dart';

@immutable
class ClinicalPermissionModel {
  final String id;
  final String studentId;
  final String? studentName;
  final String? groupId;
  final String? departmentId;
  final String? departmentName;
  final DateTime permissionDate;
  final String leaveTime; // HH:mm or HH:mm:ss
  final ShiftType? shiftType;
  final String? reason;
  final String grantedBy;
  final String? grantedByName;
  final DateTime createdAt;

  const ClinicalPermissionModel({
    required this.id,
    required this.studentId,
    this.studentName,
    this.groupId,
    this.departmentId,
    this.departmentName,
    required this.permissionDate,
    required this.leaveTime,
    this.shiftType,
    this.reason,
    required this.grantedBy,
    this.grantedByName,
    required this.createdAt,
  });

  factory ClinicalPermissionModel.fromJson(Map<String, dynamic> json) {
    return ClinicalPermissionModel(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['profiles'] is Map ? json['profiles']['full_name']?.toString() : json['student_name']?.toString(),
      groupId: json['group_id']?.toString(),
      departmentId: json['department_id']?.toString(),
      departmentName: json['departments'] is Map ? json['departments']['name_ar']?.toString() : json['department_name']?.toString(),
      permissionDate: json['permission_date'] != null
          ? DateTime.parse(json['permission_date'].toString())
          : DateTime.now(),
      leaveTime: json['leave_time']?.toString() ?? '12:00',
      shiftType: json['shift_type'] != null ? ShiftType.fromString(json['shift_type'].toString()) : null,
      reason: json['reason']?.toString(),
      grantedBy: json['granted_by']?.toString() ?? '',
      grantedByName: json['granted_by_profile'] is Map ? json['granted_by_profile']['full_name']?.toString() : null,
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
      'permission_date': '${permissionDate.year}-${permissionDate.month.toString().padLeft(2, '0')}-${permissionDate.day.toString().padLeft(2, '0')}',
      'leave_time': leaveTime,
      'shift_type': shiftType?.name,
      'reason': reason,
      'granted_by': grantedBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
