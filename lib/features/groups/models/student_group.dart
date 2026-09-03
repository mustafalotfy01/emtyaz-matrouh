import 'package:flutter/foundation.dart';

@immutable
class StudentGroupModel {
  final String id;
  final String name;
  final String? description;
  final String? supervisorDoctorId;
  final String? supervisorDoctorName;
  final String? currentMonthDepartmentId;
  final String? currentMonthDepartmentName;
  final String? departmentId; // Legacy / Fallback
  final String? departmentName; // Legacy / Fallback
  final int studentCount;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StudentGroupModel({
    required this.id,
    required this.name,
    this.description,
    this.supervisorDoctorId,
    this.supervisorDoctorName,
    this.currentMonthDepartmentId,
    this.currentMonthDepartmentName,
    this.departmentId,
    this.departmentName,
    this.studentCount = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  String get effectiveDepartmentName =>
      currentMonthDepartmentName ?? departmentName ?? 'لم يتم تحديد قسم لهذا الشهر';

  factory StudentGroupModel.fromJson(Map<String, dynamic> json) {
    return StudentGroupModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      supervisorDoctorId: json['supervisor_doctor_id']?.toString() ?? json['doctor_id']?.toString(),
      supervisorDoctorName: json['supervisor_doctor_name']?.toString() ??
          json['doctor_name']?.toString() ??
          (json['profiles'] is Map ? json['profiles']['full_name']?.toString() : null),
      currentMonthDepartmentId: json['current_month_department_id']?.toString(),
      currentMonthDepartmentName: json['current_month_department_name']?.toString(),
      departmentId: json['department_id']?.toString(),
      departmentName: json['department_name']?.toString() ??
          (json['departments'] is Map ? json['departments']['name_ar']?.toString() : null),
      studentCount: (json['student_count'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] != false,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'supervisor_doctor_id': supervisorDoctorId,
      'supervisor_doctor_name': supervisorDoctorName,
      'current_month_department_id': currentMonthDepartmentId,
      'current_month_department_name': currentMonthDepartmentName,
      'department_id': departmentId,
      'department_name': departmentName,
      'student_count': studentCount,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  StudentGroupModel copyWith({
    String? id,
    String? name,
    String? description,
    String? supervisorDoctorId,
    String? supervisorDoctorName,
    String? currentMonthDepartmentId,
    String? currentMonthDepartmentName,
    String? departmentId,
    String? departmentName,
    int? studentCount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudentGroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      supervisorDoctorId: supervisorDoctorId ?? this.supervisorDoctorId,
      supervisorDoctorName: supervisorDoctorName ?? this.supervisorDoctorName,
      currentMonthDepartmentId: currentMonthDepartmentId ?? this.currentMonthDepartmentId,
      currentMonthDepartmentName: currentMonthDepartmentName ?? this.currentMonthDepartmentName,
      departmentId: departmentId ?? this.departmentId,
      departmentName: departmentName ?? this.departmentName,
      studentCount: studentCount ?? this.studentCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
