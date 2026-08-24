import 'package:flutter/foundation.dart';
import '../../../core/services/supabase_service.dart';
import '../models/admin_student_overview_model.dart';

class AdminStudentManagementService {
  AdminStudentManagementService._();
  static final AdminStudentManagementService instance = AdminStudentManagementService._();

  /// High-performance batch RPC to fetch all students with presence and app version tracking
  Future<List<AdminStudentOverviewModel>> fetchStudentsOverview() async {
    try {
      final res = await SupabaseService.client.rpc('get_admin_students_overview');
      if (res is List) {
        return res
            .map((item) => AdminStudentOverviewModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ fetchStudentsOverview error: $e');
      }
      return [];
    }
  }

  /// Fetches complete tabbed administrative profile for a specific student
  Future<Map<String, dynamic>?> fetchStudentFullProfile(String studentId) async {
    try {
      final res = await SupabaseService.client.rpc(
        'get_admin_student_full_profile',
        params: {'p_student_id': studentId},
      );
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ fetchStudentFullProfile error: $e');
      }
      return null;
    }
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
      // 1. Delete dependent records cleanly
      try { await SupabaseService.client.from('user_presence').delete().eq('user_id', studentId); } catch (_) {}
      try { await SupabaseService.client.from('user_app_versions').delete().eq('user_id', studentId); } catch (_) {}
      try { await SupabaseService.client.from('attendance').delete().eq('student_id', studentId); } catch (_) {}
      try { await SupabaseService.client.from('disciplinary_actions').delete().eq('student_id', studentId); } catch (_) {}
      try { await SupabaseService.client.from('evaluations').delete().eq('student_id', studentId); } catch (_) {}
      try { await SupabaseService.client.from('quiz_attempts').delete().eq('student_id', studentId); } catch (_) {}
      try { await SupabaseService.client.from('roster_entries').delete().eq('student_id', studentId); } catch (_) {}

      // 2. Delete profile
      await SupabaseService.client.from('profiles').delete().eq('id', studentId);
      return true;
    } catch (e) {
      if (kDebugMode) print('⚠️ deleteStudent error: $e');
      return false;
    }
  }
}
