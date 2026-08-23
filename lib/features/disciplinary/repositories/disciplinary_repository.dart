import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../models/disciplinary_action.dart';

class DisciplinaryRepository {
  final SupabaseClient _client;

  DisciplinaryRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  /// Fetch all disciplinary and reward actions for management review
  Future<List<DisciplinaryAction>> fetchAllActions() async {
    try {
      final res = await _client
          .from('disciplinary_actions')
          .select('''
            *,
            student:student_id(id, full_name, university_code),
            creator:created_by(id, full_name),
            approver:approved_by(id, full_name),
            department:department_id(id, name_ar)
          ''')
          .order('action_date', ascending: false);

      return (res as List)
          .map((json) => DisciplinaryAction.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('فشل في جلب سجل الجزاءات والمكافآت: $e');
    }
  }

  /// Fetch disciplinary actions for a specific student
  Future<List<DisciplinaryAction>> fetchStudentActions(String studentId) async {
    try {
      final res = await _client
          .from('disciplinary_actions')
          .select('''
            *,
            student:student_id(id, full_name, university_code),
            creator:created_by(id, full_name),
            approver:approved_by(id, full_name),
            department:department_id(id, name_ar)
          ''')
          .eq('student_id', studentId)
          .eq('status', 'approved')
          .order('action_date', ascending: false);

      return (res as List)
          .map((json) => DisciplinaryAction.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('فشل في جلب سجل الطالب: $e');
    }
  }

  /// Create action directly by Super Admin or Leader (auto-approved)
  Future<DisciplinaryAction> createDirectAdminAction({
    required String studentId,
    required String departmentId,
    required DisciplinaryActionType actionType,
    required String reason,
    required String description,
    required double deductionValue,
    String deductionUnit = 'points',
    int severity = 1,
    String? adminNote,
  }) async {
    try {
      // 1. Try secure RPC first
      try {
        final rpcRes = await _client.rpc('apply_direct_disciplinary_action', params: {
          'p_student_id': studentId,
          'p_department_id': departmentId,
          'p_action_type': actionType.toDbString(),
          'p_reason': reason,
          'p_description': description,
          'p_deduction_value': deductionValue,
          'p_deduction_unit': deductionUnit,
          'p_severity': severity,
          'p_admin_note': adminNote,
        });

        if (rpcRes != null) {
          return DisciplinaryAction.fromJson(Map<String, dynamic>.from(rpcRes as Map));
        }
      } catch (rpcErr) {
        if (kDebugMode) print('Direct disciplinary RPC fallback: $rpcErr');
      }

      // 2. Direct table insert fallback
      final adminId = _client.auth.currentUser?.id;
      final profileRes = adminId != null
          ? await _client.from('profiles').select('role').eq('id', adminId).maybeSingle()
          : null;
      final callerRole = profileRes?['role']?.toString() ?? 'super_admin';
      final now = DateTime.now().toIso8601String();

      final res = await _client
          .from('disciplinary_actions')
          .insert({
            'student_id': studentId,
            'department_id': departmentId,
            'created_by': adminId,
            'created_by_role': callerRole,
            'approved_by': adminId,
            'action_type': actionType.toDbString(),
            'severity': severity,
            'reason': reason,
            'description': description,
            'deduction_value': deductionValue,
            'deduction_unit': deductionUnit,
            'status': 'approved',
            'admin_note': adminNote,
            'action_date': now.split('T')[0],
            'created_at': now,
            'updated_at': now,
          })
          .select('''
            *,
            student:student_id(id, full_name, university_code),
            creator:created_by(id, full_name),
            approver:approved_by(id, full_name),
            department:department_id(id, name_ar)
          ''')
          .single();

      return DisciplinaryAction.fromJson(res);
    } catch (e) {
      throw Exception('فشل في تطبيق الإجراء المباشر: $e');
    }
  }

  /// Create action by Doctor (pending admin review)
  Future<DisciplinaryAction> createDoctorAction({
    required String studentId,
    required String departmentId,
    required DisciplinaryActionType actionType,
    required String reason,
    required String description,
    required double deductionValue,
    String deductionUnit = 'points',
    int severity = 1,
  }) async {
    try {
      final doctorId = _client.auth.currentUser?.id;
      final now = DateTime.now().toIso8601String();

      final res = await _client
          .from('disciplinary_actions')
          .insert({
            'student_id': studentId,
            'department_id': departmentId,
            'created_by': doctorId,
            'created_by_role': 'evaluating_doctor',
            'action_type': actionType.toDbString(),
            'severity': severity,
            'reason': reason,
            'description': description,
            'deduction_value': deductionValue,
            'deduction_unit': deductionUnit,
            'status': 'pending',
            'action_date': now.split('T')[0],
            'created_at': now,
            'updated_at': now,
          })
          .select('''
            *,
            student:student_id(id, full_name, university_code),
            creator:created_by(id, full_name),
            approver:approved_by(id, full_name),
            department:department_id(id, name_ar)
          ''')
          .single();

      return DisciplinaryAction.fromJson(res);
    } catch (e) {
      throw Exception('فشل في رفع الإجراء للاعتماد: $e');
    }
  }

  /// Admin approves pending action
  Future<void> approveAction({
    required String actionId,
    String? adminComment,
  }) async {
    try {
      final adminId = _client.auth.currentUser?.id;
      await _client.from('disciplinary_actions').update({
        'status': 'approved',
        'approved_by': adminId,
        'review_comment': adminComment,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', actionId);
    } catch (e) {
      throw Exception('فشل في اعتماد الإجراء: $e');
    }
  }

  /// Admin rejects pending action
  Future<void> rejectAction({
    required String actionId,
    required String reason,
  }) async {
    try {
      final adminId = _client.auth.currentUser?.id;
      await _client.from('disciplinary_actions').update({
        'status': 'rejected',
        'approved_by': adminId,
        'review_comment': reason,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', actionId);
    } catch (e) {
      throw Exception('فشل في رفض الإجراء: $e');
    }
  }
}
