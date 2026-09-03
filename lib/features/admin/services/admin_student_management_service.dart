import 'package:flutter/foundation.dart';
import '../../../core/models/user_app_version_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/timezone_helper.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/student_approvals_provider.dart';
import '../models/admin_student_overview_model.dart';

class AdminStudentManagementService {
  AdminStudentManagementService._();
  static final AdminStudentManagementService instance = AdminStudentManagementService._();

  /// High-performance batch RPC with resilient direct-query fallback
  Future<List<AdminStudentOverviewModel>> fetchStudentsOverview() async {
    if (!SupabaseService.isInitialized) {
      return _buildFallbackOverviewList([]);
    }

    // 1. Try server RPC first (fastest, pre-joined on PostgreSQL)
    try {
      final res = await SupabaseService.client.rpc('get_admin_students_overview');
      if (res is List && res.isNotEmpty) {
        final list = res
            .map((item) => AdminStudentOverviewModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        if (list.isNotEmpty) return list;
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ get_admin_students_overview RPC unavailable, using resilient direct query: $e');
      }
    }

    // 2. Resilient Fallback: Direct query on profiles table
    try {
      final profilesData = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('role', 'student')
          .order('full_name', ascending: true);

      if (profilesData is List) {
        return await _buildFallbackOverviewList(profilesData);
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Direct profiles query error: $e');
      }
    }

    return _buildFallbackOverviewList([]);
  }

  /// Builds AdminStudentOverviewModel list from raw profile maps + optional presence & versions
  Future<List<AdminStudentOverviewModel>> _buildFallbackOverviewList(List<dynamic> profilesData) async {
    final serverNow = AppTimezoneHelper.serverNowUtc;
    final List<AdminStudentOverviewModel> result = [];

    // Optional presence lookup map
    final Map<String, Map<String, dynamic>> presenceMap = {};
    try {
      final presRes = await SupabaseService.client.from('user_presence').select();
      if (presRes is List) {
        for (final p in presRes) {
          final uid = p['user_id']?.toString();
          if (uid != null) presenceMap[uid] = Map<String, dynamic>.from(p);
        }
      }
    } catch (_) {}

    // Optional app version lookup map
    final Map<String, Map<String, dynamic>> versionMap = {};
    try {
      final verRes = await SupabaseService.client.from('user_app_versions').select();
      if (verRes is List) {
        for (final v in verRes) {
          final uid = v['user_id']?.toString();
          if (uid != null) versionMap[uid] = Map<String, dynamic>.from(v);
        }
      }
    } catch (_) {}

    for (final raw in profilesData) {
      final p = Map<String, dynamic>.from(raw);
      final id = p['id']?.toString() ?? '';
      final pres = presenceMap[id];
      final ver = versionMap[id];

      final isOnline = pres?['is_online'] == true;
      final lastSeenAt = DateTime.tryParse(pres?['last_seen_at']?.toString() ?? '') ??
          DateTime.tryParse(p['updated_at']?.toString() ?? '') ??
          DateTime.tryParse(p['created_at']?.toString() ?? '') ??
          serverNow.subtract(const Duration(days: 1));

      final diff = serverNow.difference(lastSeenAt.toUtc()).inSeconds;
      final effectiveOnline = isOnline && diff <= 120;

      final platform = ver?['platform']?.toString() ?? 'android';
      final vName = ver?['version_name']?.toString() ?? '';
      final vCode = (ver?['version_code'] as num?)?.toInt() ?? 0;
      final devInfo = ver?['device_info']?.toString() ?? '';
      final repAt = DateTime.tryParse(ver?['last_reported_at']?.toString() ?? '');

      final rawClass = p['student_classification'] ?? p['classification'];
      final parsedClass = StudentClassification.fromString(rawClass?.toString());

      result.add(AdminStudentOverviewModel(
        studentId: id,
        fullName: p['full_name']?.toString() ?? 'طالب امتياز',
        universityCode: p['university_code']?.toString() ?? '',
        email: p['email']?.toString() ?? '',
        phoneNumber: p['phone_number']?.toString() ?? '',
        gpa: (p['gpa'] as num?)?.toDouble(),
        studentGroup: p['group_name']?.toString() ?? p['student_group']?.toString() ?? 'بدون جروب',
        studentGroupId: p['student_group_id']?.toString(),
        classification: parsedClass,
        departmentName: p['department_name']?.toString(),
        supervisorDoctorName: p['supervisor_doctor_name']?.toString(),
        previousWorkExperience: p['previous_work_experience'] == true,
        previousWorkplace: p['previous_workplace']?.toString(),
        previousWorkDepartment: p['previous_work_department']?.toString(),
        registrationStatus: p['registration_status']?.toString() ?? 'approved',
        isApproved: p['is_approved'] == true,
        avatarUrl: p['avatar_url']?.toString() ?? '',
        isOnline: isOnline,
        effectiveIsOnline: effectiveOnline,
        lastSeenAt: lastSeenAt,
        appPlatform: platform,
        installedVersionName: vName,
        installedVersionCode: vCode,
        deviceInfo: devInfo,
        versionReportedAt: repAt,
        latestPlatformVersionName: '1.3.0',
        latestPlatformVersionCode: 4,
        updateStatus: vCode > 0 ? (vCode >= 4 ? AppUpdateStatus.upToDate : AppUpdateStatus.outdated) : AppUpdateStatus.unknown,
        serverNow: serverNow,
      ));
    }

    // Merge any registered local registry students if not already present
    try {
      final localList = getRegisteredStudentsList();
      for (final localStudent in localList) {
        if (!result.any((s) => s.universityCode == localStudent.universityCode || s.studentId == localStudent.id)) {
          final isApproved = localStudent.registrationStatus == RegistrationStatus.approved;
          final grp = localStudent.studentGroup?.code ?? 'A';
          result.add(AdminStudentOverviewModel(
            studentId: localStudent.id,
            fullName: localStudent.fullName,
            universityCode: localStudent.universityCode,
            email: localStudent.email,
            phoneNumber: localStudent.phoneNumber,
            gpa: localStudent.gpa,
            studentGroup: grp,
            registrationStatus: localStudent.registrationStatus.name,
            isApproved: isApproved,
            avatarUrl: localStudent.avatarUrl ?? '',
            isOnline: false,
            effectiveIsOnline: false,
            lastSeenAt: serverNow.subtract(const Duration(days: 1)),
            appPlatform: 'android',
            installedVersionName: '',
            installedVersionCode: 0,
            deviceInfo: '',
            latestPlatformVersionName: '1.3.0',
            latestPlatformVersionCode: 4,
            updateStatus: AppUpdateStatus.unknown,
            serverNow: serverNow,
          ));
        }
      }
    } catch (_) {}

    return result;
  }

  /// Fetches complete tabbed administrative profile for a specific student
  Future<Map<String, dynamic>?> fetchStudentFullProfile(String studentId) async {
    // 1. Try server RPC first
    try {
      final res = await SupabaseService.client.rpc(
        'get_admin_student_full_profile',
        params: {'p_student_id': studentId},
      );
      if (res is Map && res.isNotEmpty && res['error'] == null) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ get_admin_student_full_profile RPC fallback: $e');
      }
    }

    // 2. Fallback: Direct query
    try {
      final profileRes = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', studentId)
          .maybeSingle();

      if (profileRes != null) {
        final serverNow = AppTimezoneHelper.serverNowUtc;
        // Look up group name if student has a group
        String groupName = 'بدون جروب';
        String? deptName;
        String? docName;
        final grpId = profileRes['student_group_id']?.toString();
        if (grpId != null && grpId.isNotEmpty) {
          try {
            final grpRes = await SupabaseService.client
                .from('student_groups')
                .select('name, departments(name_ar), profiles:supervisor_doctor_id(full_name)')
                .eq('id', grpId)
                .maybeSingle();
            if (grpRes != null) {
              groupName = grpRes['name']?.toString() ?? 'بدون جروب';
              final d = grpRes['departments'] as Map<String, dynamic>?;
              deptName = d?['name_ar']?.toString();
              final p = grpRes['profiles'] as Map<String, dynamic>?;
              docName = p?['full_name']?.toString();
            }
          } catch (_) {}
        }

        return {
          'student_id': profileRes['id'],
          'full_name': profileRes['full_name'],
          'university_code': profileRes['university_code'],
          'email': profileRes['email'],
          'phone_number': profileRes['phone_number'],
          'gpa': profileRes['gpa'],
          'student_group': groupName,
          'student_group_id': grpId,
          'group_name': groupName,
          'department_name': deptName,
          'supervisor_doctor_name': docName,
          'student_classification': profileRes['student_classification'],
          'previous_work_experience': profileRes['previous_work_experience'] == true,
          'previous_workplace': profileRes['previous_workplace'],
          'previous_work_department': profileRes['previous_work_department'],
          'previous_work_experience_details': profileRes['previous_work_experience_details'],
          'registration_status': profileRes['registration_status'] ?? 'approved',
          'is_approved': profileRes['is_approved'] ?? true,
          'avatar_url': profileRes['avatar_url'],
          'national_id': profileRes['national_id'] ?? '••••••••••••••',
          'residence_address': profileRes['residence_address'] ?? 'محافظة مطروح',
          'emergency_contact': profileRes['emergency_contact'],
          'created_at': profileRes['created_at'],
          'presence': {
            'is_online': false,
            'effective_is_online': false,
            'last_seen_at': profileRes['updated_at'] ?? serverNow.toIso8601String(),
          },
          'app_version': {
            'platform': 'android',
            'version_name': 'غير معروف',
            'version_code': 0,
            'device_info': '',
            'latest_version_name': '1.3.0',
            'latest_version_code': 4,
            'update_status': 'unknown',
          },
          'today_shift': {'status': 'off', 'label': 'راحة'},
          'attendance_stats': {
            'total': 0,
            'present': 0,
            'late': 0,
            'absent': 0,
            'attendance_percentage': 100.0,
          },
          'rewards': [],
          'penalties': [],
          'evaluations': [],
          'quizzes': [],
          'server_now': serverNow.toIso8601String(),
        };
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ fetchStudentFullProfile fallback error: $e');
    }

    return null;
  }

  /// Approves a student account
  Future<bool> approveStudent(String studentId) async {
    try {
      await SupabaseService.client
          .from('profiles')
          .update({
            'registration_status': 'approved',
            'is_approved': true,
            'rejection_reason': null,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', studentId);
      return true;
    } catch (e) {
      if (kDebugMode) print('⚠️ approveStudent error: $e');
      return false;
    }
  }

  /// Rejects a student registration request with a reason
  Future<bool> rejectStudent(String studentId, String reason) async {
    try {
      await SupabaseService.client
          .from('profiles')
          .update({
            'registration_status': 'rejected',
            'is_approved': false,
            'rejection_reason': reason,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', studentId);
      return true;
    } catch (e) {
      if (kDebugMode) print('⚠️ rejectStudent error: $e');
      return false;
    }
  }

  /// Returns student account to pending review
  Future<bool> returnForReview(String studentId) async {
    try {
      await SupabaseService.client
          .from('profiles')
          .update({
            'registration_status': 'pending',
            'is_approved': false,
            'rejection_reason': null,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', studentId);
      return true;
    } catch (e) {
      if (kDebugMode) print('⚠️ returnForReview error: $e');
      return false;
    }
  }

  /// Deletes or permanently purges a student account
  Future<bool> deleteStudent(String studentId) async {
    try {
      try { await SupabaseService.client.from('user_presence').delete().eq('user_id', studentId); } catch (_) {}
      try { await SupabaseService.client.from('user_app_versions').delete().eq('user_id', studentId); } catch (_) {}
      try { await SupabaseService.client.from('attendance').delete().eq('student_id', studentId); } catch (_) {}
      try { await SupabaseService.client.from('disciplinary_actions').delete().eq('student_id', studentId); } catch (_) {}
      try { await SupabaseService.client.from('evaluations').delete().eq('student_id', studentId); } catch (_) {}
      try { await SupabaseService.client.from('quiz_attempts').delete().eq('student_id', studentId); } catch (_) {}
      try { await SupabaseService.client.from('roster_entries').delete().eq('student_id', studentId); } catch (_) {}

      await SupabaseService.client.from('profiles').delete().eq('id', studentId);
      return true;
    } catch (e) {
      if (kDebugMode) print('⚠️ deleteStudent error: $e');
      return false;
    }
  }

  /// Securely updates a student's GPA via PostgreSQL RPC (Super Admin only)
  Future<bool> updateStudentGpa({
    required String studentId,
    required double newGpa,
  }) async {
    if (newGpa < 0.0 || newGpa > 4.0) {
      throw Exception('يجب أن يكون المعدل التراكمي بين 0.00 و 4.00');
    }

    try {
      // 1. Try secure RPC
      try {
        final res = await SupabaseService.client.rpc('update_student_gpa', params: {
          'p_student_id': studentId,
          'p_new_gpa': newGpa,
        });
        if (res is Map && res['success'] == true) return true;
      } catch (e) {
        if (kDebugMode) print('update_student_gpa RPC fallback: $e');
        if (e.toString().contains('Unauthorized') || e.toString().contains('Invalid GPA')) {
          rethrow;
        }
      }

      // 2. Direct update fallback (enforced by RLS)
      await SupabaseService.client.from('profiles').update({
        'gpa': double.parse(newGpa.toStringAsFixed(2)),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', studentId);

      return true;
    } catch (e) {
      if (kDebugMode) print('⚠️ updateStudentGpa error: $e');
      rethrow;
    }
  }

  /// Securely updates a student's classification via PostgreSQL RPC (Super Admin only)
  Future<bool> updateStudentClassification({
    required String studentId,
    required StudentClassification classification,
  }) async {
    try {
      // 1. Try secure RPC
      try {
        final res = await SupabaseService.client.rpc('update_student_classification', params: {
          'p_student_id': studentId,
          'p_classification': classification.code,
        });
        if (res is Map && res['success'] == true) return true;
      } catch (e) {
        if (kDebugMode) print('update_student_classification RPC fallback: $e');
        if (e.toString().contains('Unauthorized')) rethrow;
      }

      // 2. Direct update fallback (enforced by RLS)
      await SupabaseService.client.from('profiles').update({
        'student_classification': classification.code,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', studentId);

      return true;
    } catch (e) {
      if (kDebugMode) print('⚠️ updateStudentClassification error: $e');
      rethrow;
    }
  }
}
