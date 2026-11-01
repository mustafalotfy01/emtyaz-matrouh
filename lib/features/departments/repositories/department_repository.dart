import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/models/user_profile.dart';
import '../models/department.dart';

class DepartmentRepository {
  final SupabaseClient _client;

  DepartmentRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  /// Fetch all departments with active supervisor and live capacity stats
  Future<List<Department>> fetchDepartments() async {
    try {
      final deptsResponse = await _client
          .from('departments')
          .select()
          .order('name_ar', ascending: true);

      final List<Department> departments = [];

      for (final rawDept in (deptsResponse as List)) {
        final deptId = rawDept['id'] as String;
        // Call RPC for stats & supervisor join
        try {
          final statsRes = await _client.rpc('get_department_with_stats', params: {
            'p_department_id': deptId,
          });

          if (statsRes != null && statsRes is Map<String, dynamic> && statsRes['found'] == true) {
            departments.add(Department.fromJson(statsRes));
            continue;
          }
        } catch (_) {}

        // Fallback to basic row if RPC fails
        departments.add(Department.fromJson(rawDept as Map<String, dynamic>));
      }

      return departments;
    } catch (e) {
      throw Exception('فشل في جلب قائمة الأقسام: $e');
    }
  }

  /// Fetch list of real evaluating doctors from profiles
  Future<List<UserProfile>> fetchEvaluatingDoctors() async {
    try {
      final res = await _client
          .from('profiles')
          .select()
          .eq('role', 'evaluating_doctor')
          .order('full_name', ascending: true);

      return (res as List)
          .map((json) => UserProfile.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('فشل في جلب قائمة الأطباء المقيّمين: $e');
    }
  }

  /// Create new department
  Future<Department> createDepartment({
    required String nameAr,
    required String nameEn,
    String? description,
    required int maleCapacity,
    required int femaleCapacity,
  }) async {
    try {
      final res = await _client
          .from('departments')
          .insert({
            'name_ar': nameAr,
            'name_en': nameEn,
            'description': description,
            'male_capacity': maleCapacity,
            'female_capacity': femaleCapacity,
            'is_active': true,
          })
          .select()
          .single();

      return Department.fromJson(res);
    } catch (e) {
      throw Exception('فشل في إضافة القسم: $e');
    }
  }

  /// Update department details and global capacity
  Future<void> updateDepartment(Department department) async {
    try {
      // 1. Try secure atomic RPC first
      try {
        final rpcRes = await _client.rpc('update_department', params: {
          'p_department_id': department.id,
          'p_name_ar': department.nameAr,
          'p_name_en': department.nameEn.isEmpty ? department.nameAr : department.nameEn,
          'p_description': department.description,
          'p_male_capacity': department.maleCapacity,
          'p_female_capacity': department.femaleCapacity,
          'p_is_active': department.isActive,
        });
        if (rpcRes != null && (rpcRes is Map && rpcRes['success'] == true)) {
          return;
        }
      } catch (rpcErr) {
        final errStr = rpcErr.toString();
        if (errStr.contains('Unauthorized') || errStr.contains('غير موجود')) {
          throw Exception(errStr.replaceAll('Exception: ', ''));
        }
      }

      // 2. Direct update with select() verification
      final res = await _client.from('departments').update({
        'name_ar': department.nameAr.trim(),
        'name_en': department.nameEn.trim().isEmpty ? department.nameAr.trim() : department.nameEn.trim(),
        'description': department.description,
        'male_capacity': department.maleCapacity,
        'female_capacity': department.femaleCapacity,
        'is_active': department.isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', department.id).select();

      if ((res as List).isEmpty) {
        throw Exception('تعذر حفظ تعديلات القسم في قاعدة البيانات. يرجى التأكد من تسجيل الدخول بحساب مسؤول (Leader أو Super Admin).');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Toggle department active status
  Future<void> toggleDepartmentStatus(String departmentId, bool isActive) async {
    try {
      await _client.from('departments').update({
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', departmentId).select();
    } catch (e) {
      throw Exception('فشل في تعديل حالة القسم: $e');
    }
  }

  /// Delete department safely with cascade cleaning
  Future<void> deleteDepartment(String departmentId, {bool forceCascade = false}) async {
    try {
      // 1. Try secure RPC first
      try {
        final rpcRes = await _client.rpc('delete_department', params: {
          'p_department_id': departmentId,
          'p_force_cascade': forceCascade,
        });
        if (rpcRes != null && (rpcRes is Map && rpcRes['success'] == true)) {
          return;
        }
      } catch (rpcErr) {
        final errStr = rpcErr.toString();
        if (errStr.contains('لا يمكن حذف') || errStr.contains('Unauthorized') || errStr.contains('شيفت')) {
          throw Exception(errStr.replaceAll('Exception: ', ''));
        }
      }

      // 2. Client-side fallback: check active roster entries
      final countRes = await _client
          .from('roster_entries')
          .select('id')
          .eq('department_id', departmentId);

      if ((countRes as List).isNotEmpty && !forceCascade) {
        throw Exception('لا يمكن حذف هذا القسم لاحتوائه على ${countRes.length} شيفت مسجل للطلاب. يرجى تعطيل القسم بدلاً من حذفه.');
      }

      // Clean up supervisor links and monthly assignments to prevent FK violation
      try {
        await _client.from('department_supervisors').delete().eq('department_id', departmentId);
      } catch (_) {}

      try {
        await _client.from('group_monthly_departments').delete().eq('department_id', departmentId);
      } catch (_) {}

      try {
        await _client.from('student_groups').update({'department_id': null}).eq('department_id', departmentId);
      } catch (_) {}

      final res = await _client.from('departments').delete().eq('id', departmentId).select();
      if ((res as List).isEmpty) {
        throw Exception('تعذر حذف القسم. تأكد من امتلاك صلاحية الإدارة أو أن القسم غير مسجل في شيفتات سابقة.');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Assign or change supervising doctor for a department
  Future<void> assignDoctorToDepartment({
    required String departmentId,
    required String doctorId,
    required int maleCapacity,
    required int femaleCapacity,
    String? assignedBy,
  }) async {
    try {
      // Deactivate any previous active supervisor for this department
      await _client
          .from('department_supervisors')
          .update({'is_active': false, 'updated_at': DateTime.now().toIso8601String()})
          .eq('department_id', departmentId)
          .eq('is_active', true);

      // Insert new supervisor assignment
      await _client.from('department_supervisors').upsert(
        {
          'department_id': departmentId,
          'doctor_id': doctorId,
          'male_capacity': maleCapacity,
          'female_capacity': femaleCapacity,
          'is_active': true,
          'assignment_status': 'approved',
          'assigned_by': assignedBy ?? _client.auth.currentUser?.id,
          'approved_by': assignedBy ?? _client.auth.currentUser?.id,
          'approved_at': DateTime.now().toIso8601String(),
          'assigned_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'department_id,doctor_id',
      );

      // Also sync global department capacity with assigned doctor's capacity
      await _client.from('departments').update({
        'male_capacity': maleCapacity,
        'female_capacity': femaleCapacity,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', departmentId);
    } catch (e) {
      throw Exception('فشل في تعيين الدكتور المشرف: $e');
    }
  }

  /// Remove doctor assignment (deactivate supervisor)
  Future<void> removeDoctorAssignment(String supervisorId, String departmentId) async {
    try {
      await _client.from('department_supervisors').update({
        'is_active': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', supervisorId);
    } catch (e) {
      throw Exception('فشل في إلغاء تكليف الدكتور المشرف: $e');
    }
  }

  /// Fetch assigned departments for a specific doctor
  Future<List<DoctorDepartmentDuty>> fetchDoctorDuties(String doctorId) async {
    try {
      final res = await _client.rpc('get_departments_for_doctor', params: {
        'p_doctor_id': doctorId,
      });

      if (res != null && res is List) {
        return res
            .map((json) => DoctorDepartmentDuty.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Fallback: Direct table query if RPC is not yet loaded in schema cache
      try {
        final directRes = await _client
            .from('department_supervisors')
            .select('''
              id,
              male_capacity,
              female_capacity,
              assignment_status,
              assigned_at,
              department:department_id (
                id,
                name_ar,
                name_en,
                description
              )
            ''')
            .eq('doctor_id', doctorId)
            .eq('is_active', true);

        if (directRes.isNotEmpty) {
          return directRes.map((map) {
            final dept = map['department'] as Map<String, dynamic>? ?? {};
            final maleCap = (map['male_capacity'] as num?)?.toInt() ?? 0;
            final femaleCap = (map['female_capacity'] as num?)?.toInt() ?? 0;
            return DoctorDepartmentDuty(
              departmentId: dept['id']?.toString() ?? '',
              nameAr: dept['name_ar']?.toString() ?? '',
              nameEn: dept['name_en']?.toString() ?? '',
              description: dept['description']?.toString(),
              supervisorId: map['id']?.toString() ?? '',
              maleCapacity: maleCap,
              femaleCapacity: femaleCap,
              totalCapacity: maleCap + femaleCap,
              currentMale: 0,
              currentFemale: 0,
              currentTotal: 0,
              remainingMale: maleCap,
              remainingFemale: femaleCap,
              remainingTotal: maleCap + femaleCap,
              evaluationsCount: 0,
              pendingHandoversCount: 0,
              assignmentStatus: map['assignment_status']?.toString() ?? 'approved',
              assignedAt: map['assigned_at'] != null ? DateTime.tryParse(map['assigned_at'].toString()) : null,
            );
          }).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  /// Fetch distribution matrix for Leader & Admin
  Future<List<DistributionMatrixRow>> fetchDistributionMatrix() async {
    try {
      final res = await _client.rpc('get_distribution_matrix');

      if (res != null && res is List) {
        return (res)
            .map((json) => DistributionMatrixRow.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      try {
        final depts = await _client.from('departments').select().order('name_ar', ascending: true);
        return depts.map((map) {
          final mCap = (map['male_capacity'] as num?)?.toInt() ?? 0;
          final fCap = (map['female_capacity'] as num?)?.toInt() ?? 0;
          return DistributionMatrixRow(
            departmentId: map['id']?.toString() ?? '',
            departmentName: map['name_ar']?.toString() ?? '',
            doctorId: null,
            doctorName: 'لم يتم التعيين',
            maleCapacity: mCap,
            femaleCapacity: fCap,
            totalCapacity: mCap + fCap,
            currentMale: 0,
            currentFemale: 0,
            currentTotal: 0,
            remainingMale: mCap,
            remainingFemale: fCap,
            remainingTotal: mCap + fCap,
            assignmentStatus: 'approved',
          );
        }).toList();
      } catch (_) {}
    }
    return [];
  }
}
