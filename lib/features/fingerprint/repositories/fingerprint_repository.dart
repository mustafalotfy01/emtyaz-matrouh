import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/fcm_sender_service.dart';
import '../../../core/services/supabase_service.dart';
import '../models/fingerprint_request.dart';

class FingerprintRepository {
  final SupabaseClient _client;

  FingerprintRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  /// Fetch confirmation requests
  Future<List<FingerprintRequest>> fetchRequests({String? status}) async {
    try {
      var query = _client.from('confirmation_requests').select('''
            *,
            sender:sender_id(id, full_name),
            target_student:target_student_id(id, full_name, university_code)
          ''');

      if (status != null) {
        query = query.eq('status', status);
      }

      final res = await query.order('sent_at', ascending: false);

      return (res as List)
          .map((json) => FingerprintRequest.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Send immediate fingerprint verification request
  Future<FingerprintRequest> sendImmediateRequest({
    required String audienceType,
    String? targetStudentId,
    String? title,
    String? notes,
  }) async {
    try {
      final senderId = _client.auth.currentUser?.id;
      final now = DateTime.now().toIso8601String();
      final requestTitle = title ?? 'طلب بصمة تأكيد التواجد الفوري';

      final res = await _client
          .from('confirmation_requests')
          .insert({
            'sender_id': senderId,
            'audience_type': audienceType,
            'target_student_id': targetStudentId,
            'title': requestTitle,
            'notes': notes,
            'status': 'pending',
            'sent_at': now,
            'created_at': now,
            'updated_at': now,
          })
          .select('''
            *,
            sender:sender_id(id, full_name),
            target_student:target_student_id(id, full_name, university_code)
          ''')
          .single();

      // Trigger Push / FCM notification
      try {
        await FcmSenderService.instance.broadcastServerNotification(
          audienceType: audienceType,
          title: '⚠️ $requestTitle',
          body: notes ?? 'يرجى فتح التطبيق وتأكيد البصمة الحيوية فوراً لإثبات التواجد بالقسم.',
          notificationType: 'FINGERPRINT',
          targetRoute: '/attendance',
          metadata: {'type': 'fingerprint_request', 'request_id': res['id'].toString()},
        );
      } catch (_) {}

      return FingerprintRequest.fromJson(res);
    } catch (e) {
      throw Exception('فشل في إرسال طلب البصمة: $e');
    }
  }

  /// Student confirms fingerprint
  Future<void> confirmFingerprint({
    required String requestId,
    double? latitude,
    double? longitude,
    Map<String, dynamic>? deviceMetadata,
  }) async {
    try {
      await _client.from('confirmation_requests').update({
        'status': 'confirmed',
        'confirmed_at': DateTime.now().toIso8601String(),
        'confirmed_latitude': latitude,
        'confirmed_longitude': longitude,
        'device_metadata': deviceMetadata ?? {'confirmed_via': 'mobile_biometric'},
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);
    } catch (e) {
      throw Exception('فشل في تأكيد البصمة: $e');
    }
  }
}
