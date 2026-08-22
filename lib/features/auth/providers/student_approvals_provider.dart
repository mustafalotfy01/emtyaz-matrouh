import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../models/user_profile.dart';
import 'auth_provider.dart';

class StudentApprovalsNotifier extends StateNotifier<AsyncValue<List<UserProfile>>> {
  final Ref ref;

  StudentApprovalsNotifier(this.ref) : super(const AsyncValue.loading()) {
    fetchStudentRequests();
  }

  Future<void> fetchStudentRequests() async {
    state = const AsyncValue.loading();
    try {
      final List<UserProfile> combined = [];

      // 1. Fetch from Supabase using admin client to bypass RLS restrictions
      if (SupabaseService.isInitialized) {
        try {
          // Fetch reviewer names for audit logs
          try {
            final reviewersData = await SupabaseService.client
                .from('profiles')
                .select('id, full_name, role');
            for (final r in reviewersData) {
              final id = r['id']?.toString();
              final name = r['full_name']?.toString();
              final role = r['role']?.toString();
              if (id != null && name != null) {
                final roleArabic = role == 'leader'
                    ? 'منسق'
                    : (role == 'super_admin' ? 'مدير النظام' : (role == 'evaluating_doctor' ? 'مشرف طبي' : ''));
                _reviewerNames[id] = roleArabic.isNotEmpty ? '$name — $roleArabic' : name;
              }
            }
          } catch (_) {}

          final data = await SupabaseService.client
              .from('profiles')
              .select()
              .eq('role', 'student')
              .order('created_at', ascending: false);

          Map<String, double> userGpas = {};
          try {
            final authUsers = await SupabaseService.client.auth.admin.listUsers();
            for (final u in authUsers) {
              final g = u.userMetadata?['gpa'];
              if (g != null) {
                final gVal = (g is num) ? g.toDouble() : double.tryParse(g.toString());
                if (gVal != null) {
                  userGpas[u.id] = gVal;
                }
              }
            }
          } catch (_) {}

          final list = (data as List).map((json) {
            var p = UserProfile.fromJson(json);
            if (p.gpa == null && userGpas.containsKey(p.id)) {
              p = p.copyWith(gpa: userGpas[p.id]);
            }
            return p;
          }).toList();
          combined.addAll(list);
        } catch (e) {
          if (kDebugMode) print('Supabase fetch error in approvals: $e');
        }
      }

      // 2. Add any newly registered students from local registry if not already present
      final localList = getRegisteredStudentsList();
      for (final localStudent in localList) {
        if (!combined.any((s) => s.universityCode == localStudent.universityCode || s.id == localStudent.id)) {
          combined.add(localStudent);
        }
      }

      state = AsyncValue.data(combined);
    } catch (e, st) {
      if (kDebugMode) print('Error fetching student approvals: $e');
      state = AsyncValue.error(e, st);
    }
  }

  final Map<String, String> _reviewerNames = {};

  String resolveReviewerName(String? reviewerId) {
    if (reviewerId == null || reviewerId.isEmpty) return 'مسؤول النظام';
    if (_reviewerNames.containsKey(reviewerId)) {
      return _reviewerNames[reviewerId]!;
    }
    // If it is a known static ID
    if (reviewerId.startsWith('leader')) return 'منسق الامتياز والجدولة';
    if (reviewerId.startsWith('admin')) return 'مدير النظام العام';
    if (reviewerId.startsWith('supervisor') || reviewerId.startsWith('doctor')) return 'المشرف الطبي المقيّم';
    return 'مسؤول النظام';
  }

  Future<bool> approveStudent(String studentId) async {
    final currentReviewer = ref.read(authProvider).user;
    final reviewerId = currentReviewer?.id ?? 'leader-001';
    final reviewerRole = currentReviewer?.role.toDbString() ?? 'leader';

    try {
      updateStudentApprovalInRegistry(studentId, RegistrationStatus.approved, null);

      if (SupabaseService.isInitialized) {
        try {
          await SupabaseService.client.from('profiles').update({
            'registration_status': 'approved',
            'is_approved': true,
            'reviewed_by': reviewerId,
            'reviewed_at': DateTime.now().toIso8601String(),
            'rejection_reason': null,
          }).or('id.eq.$studentId,university_code.eq.$studentId');

          // Audit Log
          await SupabaseService.client.from('audit_logs').insert({
            'user_id': reviewerId,
            'action_type': 'REGISTRATION_APPROVED',
            'entity_name': 'profiles',
            'entity_id': studentId,
            'new_values': {
              'reviewer_role': reviewerRole,
              'reviewer_name': currentReviewer?.fullName,
              'timestamp': DateTime.now().toIso8601String(),
            }
          });
        } catch (e) {
          if (kDebugMode) print('Approve error in Supabase: $e');
        }
      }

      // Update local state
      state = state.whenData((list) {
        return list.map((student) {
          if (student.id == studentId || student.universityCode == studentId) {
            return student.copyWith(
              registrationStatus: RegistrationStatus.approved,
              reviewedBy: reviewerId,
              reviewedAt: DateTime.now(),
              rejectionReason: null,
            );
          }
          return student;
        }).toList();
      });

      return true;
    } catch (e) {
      if (kDebugMode) print('Approve student error: $e');
      return false;
    }
  }

  Future<bool> rejectStudent(String studentId, String reason) async {
    final currentReviewer = ref.read(authProvider).user;
    final reviewerId = currentReviewer?.id ?? 'leader-001';
    final reviewerRole = currentReviewer?.role.toDbString() ?? 'leader';

    try {
      updateStudentApprovalInRegistry(studentId, RegistrationStatus.rejected, reason);

      if (SupabaseService.isInitialized) {
        try {
          await SupabaseService.client.from('profiles').update({
            'registration_status': 'rejected',
            'is_approved': false,
            'reviewed_by': reviewerId,
            'reviewed_at': DateTime.now().toIso8601String(),
            'rejection_reason': reason,
          }).or('id.eq.$studentId,university_code.eq.$studentId');

          // Audit Log
          await SupabaseService.client.from('audit_logs').insert({
            'user_id': reviewerId,
            'action_type': 'REGISTRATION_REJECTED',
            'entity_name': 'profiles',
            'entity_id': studentId,
            'new_values': {
              'reviewer_role': reviewerRole,
              'reviewer_name': currentReviewer?.fullName,
              'reason': reason,
              'timestamp': DateTime.now().toIso8601String(),
            }
          });
        } catch (e) {
          if (kDebugMode) print('Reject error in Supabase: $e');
        }
      }

      state = state.whenData((list) {
        return list.map((student) {
          if (student.id == studentId || student.universityCode == studentId) {
            return student.copyWith(
              registrationStatus: RegistrationStatus.rejected,
              reviewedBy: reviewerId,
              reviewedAt: DateTime.now(),
              rejectionReason: reason,
            );
          }
          return student;
        }).toList();
      });

      return true;
    } catch (e) {
      if (kDebugMode) print('Reject student error: $e');
      return false;
    }
  }

  Future<bool> returnToPending(String studentId) async {
    final currentReviewer = ref.read(authProvider).user;
    final reviewerId = currentReviewer?.id ?? 'leader-001';
    final reviewerRole = currentReviewer?.role.toDbString() ?? 'leader';

    try {
      updateStudentApprovalInRegistry(studentId, RegistrationStatus.pending, null);

      if (SupabaseService.isInitialized) {
        try {
          await SupabaseService.client.from('profiles').update({
            'registration_status': 'pending',
            'is_approved': false,
            'reviewed_by': reviewerId,
            'reviewed_at': DateTime.now().toIso8601String(),
            'rejection_reason': null,
          }).or('id.eq.$studentId,university_code.eq.$studentId');

          // Audit Log
          await SupabaseService.client.from('audit_logs').insert({
            'user_id': reviewerId,
            'action_type': 'REGISTRATION_RETURNED_TO_PENDING',
            'entity_name': 'profiles',
            'entity_id': studentId,
            'new_values': {
              'reviewer_role': reviewerRole,
              'reviewer_name': currentReviewer?.fullName,
              'action': 'Returned from Rejected to Pending review',
              'timestamp': DateTime.now().toIso8601String(),
            }
          });
        } catch (e) {
          if (kDebugMode) print('Return to pending error in Supabase: $e');
        }
      }

      state = state.whenData((list) {
        return list.map((student) {
          if (student.id == studentId || student.universityCode == studentId) {
            return student.copyWith(
              registrationStatus: RegistrationStatus.pending,
              reviewedBy: reviewerId,
              reviewedAt: DateTime.now(),
              rejectionReason: null,
            );
          }
          return student;
        }).toList();
      });

      return true;
    } catch (e) {
      if (kDebugMode) print('Return to pending student error: $e');
      return false;
    }
  }

  Future<bool> deleteStudent(String studentId) async {
    final currentReviewer = ref.read(authProvider).user;
    final reviewerId = currentReviewer?.id ?? 'admin-001';

    try {
      // 1. Remove from local in-memory registry so it never resurrects
      removeStudentFromRegistry(studentId);

      if (SupabaseService.isInitialized) {
        try {
          // Try RPC first for clean atomic server-side cascade
          try {
            await SupabaseService.client.rpc('delete_student_account', params: {
              'p_student_id': studentId,
            });
          } catch (_) {
            // Fallback manual cascades
            await SupabaseService.client.from('roster_entries').delete().eq('student_id', studentId);
            await SupabaseService.client.from('roster_preferences').delete().eq('student_id', studentId);
            await SupabaseService.client.from('notifications').delete().eq('user_id', studentId);
            await SupabaseService.client.from('attendance').delete().eq('student_id', studentId);
            await SupabaseService.client.from('quiz_answers').delete().eq('student_id', studentId);
            await SupabaseService.client.from('quiz_attempts').delete().eq('student_id', studentId);
            await SupabaseService.client.from('evaluations').delete().eq('student_id', studentId);
            await SupabaseService.client.from('case_handovers').delete().or('from_student_id.eq.$studentId,to_student_id.eq.$studentId');
            await SupabaseService.client.from('cases').delete().eq('student_id', studentId);
            await SupabaseService.client.from('disciplinary_actions').delete().eq('student_id', studentId);
            await SupabaseService.client.from('confirmation_requests').delete().or('target_student_id.eq.$studentId,sender_id.eq.$studentId');
            await SupabaseService.client.from('community_comments').delete().eq('author_id', studentId);
            await SupabaseService.client.from('community_posts').delete().eq('author_id', studentId);
            
            // Delete from profiles
            await SupabaseService.client.from('profiles').delete().or('id.eq.$studentId,university_code.eq.$studentId');
          }

          // Delete from Auth if valid UUID
          try {
            await SupabaseService.client.auth.admin.deleteUser(studentId);
          } catch (_) {}

          // Audit Log
          try {
            await SupabaseService.client.from('audit_logs').insert({
              'user_id': reviewerId,
              'action_type': 'STUDENT_PERMANENTLY_DELETED',
              'entity_name': 'profiles',
              'entity_id': studentId,
              'new_values': {
                'deleted_by': currentReviewer?.fullName,
                'timestamp': DateTime.now().toIso8601String(),
              }
            });
          } catch (_) {}
        } catch (e) {
          if (kDebugMode) print('Delete student error in Supabase: $e');
        }
      }

      // Remove from local list state
      state = state.whenData((list) {
        return list.where((s) => s.id != studentId && s.universityCode != studentId).toList();
      });

      return true;
    } catch (e) {
      if (kDebugMode) print('Delete student error: $e');
      return false;
    }
  }
}

final studentApprovalsProvider =
    StateNotifierProvider<StudentApprovalsNotifier, AsyncValue<List<UserProfile>>>((ref) {
  return StudentApprovalsNotifier(ref);
});
