import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/models/user_profile.dart';
import '../../departments/models/department.dart';
import '../models/student_group.dart';

class StudentGroupsRepository {
  final SupabaseClient _client;

  StudentGroupsRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  /// Fetch all active student groups with department and supervisor doctor details
  Future<List<StudentGroupModel>> fetchGroups() async {
    try {
      // 1. Attempt using optimized summary RPC
      try {
        final rpcRes = await _client.rpc('get_student_groups_summary');
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
            department_id,
            supervisor_doctor_id,
            is_active,
            created_at,
            updated_at,
            departments:department_id(name_ar),
            profiles:supervisor_doctor_id(full_name)
          ''')
          .eq('is_active', true)
          .order('name', ascending: true);

      final List<StudentGroupModel> groups = [];
      for (final row in (res as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final dept = map['departments'] as Map<String, dynamic>?;
        final doc = map['profiles'] as Map<String, dynamic>?;

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
          departmentId: map['department_id']?.toString(),
          departmentName: dept?['name_ar']?.toString(),
          supervisorDoctorId: map['supervisor_doctor_id']?.toString(),
          supervisorDoctorName: doc?['full_name']?.toString(),
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

  /// Create a new dynamic student group
  Future<StudentGroupModel?> createGroup({
    required String name,
    String? description,
    String? departmentId,
    String? supervisorDoctorId,
  }) async {
    try {
      // 1. Try RPC first
      try {
        final rpcRes = await _client.rpc('create_student_group', params: {
          'p_name': name.trim(),
          'p_description': description?.trim(),
          'p_department_id': departmentId,
          'p_supervisor_doctor_id': supervisorDoctorId,
        });
        if (rpcRes is Map && rpcRes['success'] == true) {
          final newId = rpcRes['group_id']?.toString() ?? '';
          return StudentGroupModel(
            id: newId,
            name: name.trim(),
            description: description?.trim(),
            departmentId: departmentId,
            supervisorDoctorId: supervisorDoctorId,
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
            'department_id': departmentId,
            'supervisor_doctor_id': supervisorDoctorId,
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

  /// Update group details
  Future<bool> updateGroup({
    required String groupId,
    required String name,
    String? description,
    String? departmentId,
    String? supervisorDoctorId,
    bool? isActive,
  }) async {
    try {
      try {
        final rpcRes = await _client.rpc('update_student_group', params: {
          'p_group_id': groupId,
          'p_name': name.trim(),
          'p_description': description?.trim(),
          'p_department_id': departmentId,
          'p_supervisor_doctor_id': supervisorDoctorId,
          'p_is_active': isActive ?? true,
        });
        if (rpcRes is Map && rpcRes['success'] == true) return true;
      } catch (e) {
        if (kDebugMode) print('update_student_group RPC fallback: $e');
      }

      await _client.from('student_groups').update({
        'name': name.trim(),
        'description': description?.trim(),
        'department_id': departmentId,
        'supervisor_doctor_id': supervisorDoctorId,
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

  /// Fetch evaluating doctors only
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
