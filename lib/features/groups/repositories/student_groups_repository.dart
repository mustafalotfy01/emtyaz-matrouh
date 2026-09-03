import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/timezone_helper.dart';
import '../../auth/models/user_profile.dart';
import '../../departments/models/department.dart';
import '../models/group_monthly_department.dart';
import '../models/student_group.dart';

class StudentGroupsRepository {
  final SupabaseClient _client;

  StudentGroupsRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  /// Fetch all active student groups with supervisor doctor and monthly department details
  Future<List<StudentGroupModel>> fetchGroups({int? year, int? month}) async {
    final cairoNow = AppTimezoneHelper.serverNowUtc;
    final targetYear = year ?? cairoNow.year;
    final targetMonth = month ?? cairoNow.month;

    try {
      // 1. Attempt using optimized summary RPC with year and month
      try {
        final rpcRes = await _client.rpc('get_student_groups_summary', params: {
          'p_year': targetYear,
          'p_month': targetMonth,
        });
        if (rpcRes is List) {
          return rpcRes.map((json) => StudentGroupModel.fromJson(json as Map<String, dynamic>)).toList();
        }
      } catch (e) {
        if (kDebugMode) print('get_student_groups_summary RPC fallback: $e');
      }

      // 2. Direct relational query fallback
      final res = await _client
          .from('student_groups')
          .select('''
            id,
            name,
            description,
            supervisor_doctor_id,
            is_active,
            created_at,
            updated_at,
            departments:department_id(name_ar),
            profiles:supervisor_doctor_id(full_name)
          ''')
          .eq('is_active', true)
          .order('created_at', ascending: true);

      final List<StudentGroupModel> groups = [];
      for (final row in (res as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final doc = map['profiles'] as Map<String, dynamic>?;

        // Check monthly assignment for this group, year, month
        String? curDeptId;
        String? curDeptName;
        try {
          final mRes = await _client
              .from('group_monthly_departments')
              .select('department_id, departments(name_ar)')
              .eq('group_id', map['id'])
              .eq('year', targetYear)
              .eq('month', targetMonth)
              .maybeSingle();

          if (mRes != null) {
            curDeptId = mRes['department_id']?.toString();
            curDeptName = mRes['departments']?['name_ar']?.toString();
          }
        } catch (_) {}

        // Fallback to static department if monthly is not configured yet
        if (curDeptName == null && map['departments'] is Map) {
          curDeptName = map['departments']['name_ar']?.toString();
          curDeptId = map['department_id']?.toString();
        }

        // Fetch live student count
        int count = 0;
        try {
          final countRes = await _client
              .from('profiles')
              .select('id')
              .eq('student_group_id', map['id'])
              .eq('role', 'student');
          count = (countRes as List).length;
        } catch (_) {}

        groups.add(StudentGroupModel(
          id: map['id']?.toString() ?? '',
          name: map['name']?.toString() ?? '',
          description: map['description']?.toString(),
          supervisorDoctorId: map['supervisor_doctor_id']?.toString(),
          supervisorDoctorName: doc?['full_name']?.toString(),
          currentMonthDepartmentId: curDeptId,
          currentMonthDepartmentName: curDeptName,
          studentCount: count,
          isActive: map['is_active'] != false,
          createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
          updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
        ));
      }

      return groups;
    } catch (e) {
      if (kDebugMode) print('[StudentGroupsRepository] fetchGroups error: $e');
      return [];
    }
  }

  /// Create a new dynamic student group (NAME & DESCRIPTION ONLY)
  Future<StudentGroupModel?> createGroup({
    required String name,
    String? description,
  }) async {
    try {
      // 1. Try RPC first
      try {
        final rpcRes = await _client.rpc('create_student_group', params: {
          'p_name': name.trim(),
          'p_description': description?.trim(),
        });
        if (rpcRes != null) {
          final newId = rpcRes.toString();
          return StudentGroupModel(
            id: newId,
            name: name.trim(),
            description: description?.trim(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }
      } catch (e) {
        if (kDebugMode) print('create_student_group RPC fallback: $e');
      }

      // 2. Direct insert fallback
      final res = await _client
          .from('student_groups')
          .insert({
            'name': name.trim(),
            'description': description?.trim(),
            'is_active': true,
          })
          .select()
          .single();

      return StudentGroupModel.fromJson(res);
    } catch (e) {
      if (kDebugMode) print('[StudentGroupsRepository] createGroup error: $e');
      rethrow;
    }
  }

  /// Assign an evaluating doctor directly to the group
  Future<bool> assignDoctorToGroup({
    required String groupId,
    required String? doctorId,
  }) async {
    try {
      try {
        final rpcRes = await _client.rpc('assign_doctor_to_group', params: {
          'p_group_id': groupId,
          'p_doctor_id': doctorId,
        });
        if (rpcRes is Map && rpcRes['success'] == true) return true;
      } catch (e) {
        if (kDebugMode) print('assign_doctor_to_group RPC fallback: $e');
      }

      await _client.from('student_groups').update({
        'supervisor_doctor_id': doctorId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', groupId);

      return true;
    } catch (e) {
      if (kDebugMode) print('[StudentGroupsRepository] assignDoctorToGroup error: $e');
      return false;
    }
  }

  /// Set or update the monthly department for a group (DOES NOT ASK FOR DOCTOR)
  Future<bool> setGroupMonthlyDepartment({
    required String groupId,
    required String departmentId,
    required int year,
    required int month,
  }) async {
    try {
      try {
        final rpcRes = await _client.rpc('set_group_monthly_department', params: {
          'p_group_id': groupId,
          'p_department_id': departmentId,
          'p_year': year,
          'p_month': month,
        });
        if (rpcRes is Map && rpcRes['success'] == true) return true;
      } catch (e) {
        if (kDebugMode) print('set_group_monthly_department RPC fallback: $e');
      }

      await _client.from('group_monthly_departments').upsert(
        {
          'group_id': groupId,
          'department_id': departmentId,
          'year': year,
          'month': month,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'group_id,year,month',
      );

      return true;
    } catch (e) {
      if (kDebugMode) print('[StudentGroupsRepository] setGroupMonthlyDepartment error: $e');
      return false;
    }
  }

  /// Fetch monthly department timeline/history for a group
  Future<List<GroupMonthlyDepartmentModel>> fetchGroupMonthlyTimeline(String groupId) async {
    try {
      try {
        final rpcRes = await _client.rpc('get_group_monthly_timeline', params: {
          'p_group_id': groupId,
        });
        if (rpcRes is List) {
          return rpcRes.map((json) => GroupMonthlyDepartmentModel.fromJson(json as Map<String, dynamic>)).toList();
        }
      } catch (e) {
        if (kDebugMode) print('get_group_monthly_timeline RPC fallback: $e');
      }

      final res = await _client
          .from('group_monthly_departments')
          .select('id, group_id, department_id, year, month, created_at, updated_at, departments(name_ar)')
          .eq('group_id', groupId)
          .order('year', ascending: false)
          .order('month', ascending: false);

      return (res as List).map((row) => GroupMonthlyDepartmentModel.fromJson(row as Map<String, dynamic>)).toList();
    } catch (e) {
      if (kDebugMode) print('[StudentGroupsRepository] fetchGroupMonthlyTimeline error: $e');
      return [];
    }
  }

  /// Update group basic details
  Future<bool> updateGroup({
    required String groupId,
    required String name,
    String? description,
    bool? isActive,
  }) async {
    try {
      await _client.from('student_groups').update({
        'name': name.trim(),
        'description': description?.trim(),
        if (isActive != null) 'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', groupId);

      return true;
    } catch (e) {
      if (kDebugMode) print('[StudentGroupsRepository] updateGroup error: $e');
      return false;
    }
  }

  /// Assign a student to a dynamic group
  Future<bool> assignStudentToGroup({
    required String studentId,
    required String groupId,
  }) async {
    try {
      try {
        final rpcRes = await _client.rpc('assign_student_to_group', params: {
          'p_student_id': studentId,
          'p_group_id': groupId,
        });
        if (rpcRes is Map && rpcRes['success'] == true) return true;
      } catch (e) {
        if (kDebugMode) print('assign_student_to_group RPC fallback: $e');
      }

      await _client.from('profiles').update({
        'student_group_id': groupId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', studentId);

      return true;
    } catch (e) {
      if (kDebugMode) print('[StudentGroupsRepository] assignStudentToGroup error: $e');
      return false;
    }
  }

  /// Remove student from their current group
  Future<bool> removeStudentFromGroup(String studentId) async {
    try {
      try {
        final rpcRes = await _client.rpc('remove_student_from_group', params: {
          'p_student_id': studentId,
        });
        if (rpcRes is Map && rpcRes['success'] == true) return true;
      } catch (e) {
        if (kDebugMode) print('remove_student_from_group RPC fallback: $e');
      }

      await _client.from('profiles').update({
        'student_group_id': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', studentId);

      return true;
    } catch (e) {
      if (kDebugMode) print('[StudentGroupsRepository] removeStudentFromGroup error: $e');
      return false;
    }
  }

  /// Batch assign students to a group
  Future<bool> batchAssignStudents({
    required List<String> studentIds,
    required String groupId,
  }) async {
    if (studentIds.isEmpty) return true;
    try {
      for (final sId in studentIds) {
        await assignStudentToGroup(studentId: sId, groupId: groupId);
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('[StudentGroupsRepository] batchAssignStudents error: $e');
      return false;
    }
  }

  /// Fetch all students enrolled in a group
  Future<List<UserProfile>> fetchStudentsInGroup(String groupId) async {
    try {
      final res = await _client
          .from('profiles')
          .select()
          .eq('student_group_id', groupId)
          .eq('role', 'student')
          .order('full_name', ascending: true);

      return (res as List).map((json) => UserProfile.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      if (kDebugMode) print('[StudentGroupsRepository] fetchStudentsInGroup error: $e');
      return [];
    }
  }

  /// Fetch evaluating doctors only (Role = evaluating_doctor)
  Future<List<UserProfile>> fetchEvaluatingDoctors() async {
    try {
      final res = await _client
          .from('profiles')
          .select()
          .eq('role', 'evaluating_doctor')
          .order('full_name', ascending: true);

      return (res as List).map((json) => UserProfile.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      if (kDebugMode) print('[StudentGroupsRepository] fetchEvaluatingDoctors error: $e');
      return [];
    }
  }

  /// Fetch active departments
  Future<List<Department>> fetchActiveDepartments() async {
    try {
      final res = await _client
          .from('departments')
          .select()
          .eq('is_active', true)
          .order('name_ar', ascending: true);

      return (res as List).map((json) => Department.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      if (kDebugMode) print('[StudentGroupsRepository] fetchActiveDepartments error: $e');
      return [];
    }
  }
}
