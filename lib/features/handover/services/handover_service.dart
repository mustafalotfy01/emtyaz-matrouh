import 'package:flutter/foundation.dart';
import '../../../core/services/supabase_service.dart';
import '../models/handover_model.dart';

class HandoverService {
  HandoverService._();

  /// Loads handovers relevant to the current user (sent, received, or all for staff)
  static Future<List<HandoverModel>> fetchHandovers({
    required String userId,
    required bool isStaff,
  }) async {
    if (!SupabaseService.isInitialized) return [];

    try {
      var query = SupabaseService.client
          .from('case_handovers')
          .select('''
            *,
            from_profile:profiles!from_student_id(full_name, avatar_url),
            to_profile:profiles!to_student_id(full_name, avatar_url),
            evaluator_profile:profiles!evaluated_by(full_name)
          ''');

      if (!isStaff) {
        query = query.or('from_student_id.eq.$userId,to_student_id.eq.$userId');
      }

      final res = await query.order('created_at', ascending: false);
      return (res as List).map((json) => HandoverModel.fromJson(json)).toList();
    } catch (e) {
      if (kDebugMode) print('[HandoverService] fetchHandovers error: $e');
      return [];
    }
  }

  /// Submits a new handover
  static Future<bool> createHandover(HandoverModel handover) async {
    if (!SupabaseService.isInitialized) return true;

    try {
      await SupabaseService.client
          .from('case_handovers')
          .insert(handover.toSupabasePayload());
      return true;
    } catch (e) {
      if (kDebugMode) print('[HandoverService] createHandover error: $e');
      return false;
    }
  }

  /// Receiver responds: Accept or Reject
  static Future<bool> respondToHandover({
    required String handoverId,
    required bool accept,
    String? rejectionReason,
  }) async {
    if (!SupabaseService.isInitialized) return true;

    try {
      if (accept) {
        await SupabaseService.client
            .from('case_handovers')
            .update({
              'status': 'accepted',
              'accepted_at': DateTime.now().toIso8601String(),
            })
            .eq('id', handoverId);
      } else {
        await SupabaseService.client
            .from('case_handovers')
            .update({
              'status': 'rejected',
              'rejected_at': DateTime.now().toIso8601String(),
              'rejection_reason': rejectionReason ?? 'تم الرفض بواسطة المستلم',
            })
            .eq('id', handoverId);
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('[HandoverService] respondToHandover error: $e');
      return false;
    }
  }

  /// Doctor evaluates the handover and assigns points
  static Future<bool> evaluateHandover({
    required String handoverId,
    required String doctorId,
    required double points,
    required String comment,
  }) async {
    if (!SupabaseService.isInitialized) return true;

    try {
      await SupabaseService.client
          .from('case_handovers')
          .update({
            'doctor_score': points,
            'doctor_comment': comment,
            'evaluated_by': doctorId,
            'evaluated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', handoverId);
      return true;
    } catch (e) {
      if (kDebugMode) print('[HandoverService] evaluateHandover error: $e');
      return false;
    }
  }
}
