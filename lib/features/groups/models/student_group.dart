import 'package:flutter/foundation.dart';

@immutable
class StudentGroupModel {
  final String id;
  final String name;
  final String? description;
  final String? departmentId;
  final String? departmentName;
  final String? supervisorDoctorId;
  final String? supervisorDoctorName;
  final int studentCount;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StudentGroupModel({
    required this.id,
    required this.name,
    this.description,
    this.departmentId,
    this.departmentName,
    this.supervisorDoctorId,
    this.supervisorDoctorName,
    this.studentCount = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory StudentGroupModel.fromJson(Map<String, dynamic> json) {
    return StudentGroupModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      departmentId: json['department_id']?.toString(),
      departmentName: json['department_name']?.toString() ??
          (json['departments'] is Map ? json['departments']['name_ar']?.toString() : null),
      supervisorDoctorId: json['supervisor_doctor_id']?.toString(),
      supervisorDoctorName: json['supervisor_doctor_name']?.toString() ??
          (json['profiles'] is Map ? json['profiles']['full_name']?.toString() : null),
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
      'department_id': departmentId,
      'department_name': departmentName,
      'supervisor_doctor_id': supervisorDoctorId,
      'supervisor_doctor_name': supervisorDoctorName,
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
    String? departmentId,
    String? departmentName,
    String? supervisorDoctorId,
    String? supervisorDoctorName,
    int? studentCount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudentGroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      departmentId: departmentId ?? this.departmentId,
      departmentName: departmentName ?? this.departmentName,
      supervisorDoctorId: supervisorDoctorId ?? this.supervisorDoctorId,
      supervisorDoctorName: supervisorDoctorName ?? this.supervisorDoctorName,
      studentCount: studentCount ?? this.studentCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
