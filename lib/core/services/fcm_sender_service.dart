import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class BroadcastExecutionResult {
  final bool success;
  final int recipientCount;
  final int inAppCount;
  final int tokensFound;
  final int pushDeliveredCount;
  final String? errorMessage;

  BroadcastExecutionResult({
    required this.success,
    this.recipientCount = 0,
    this.inAppCount = 0,
    this.tokensFound = 0,
    this.pushDeliveredCount = 0,
    this.errorMessage,
  });
}

class FcmSenderService {
  FcmSenderService._();
  static final FcmSenderService instance = FcmSenderService._();

  /// Securely invokes the server-side broadcast-notification Edge Function
  /// Authentication: Handled automatically by Supabase client using current User JWT
  /// Secrets: Service Role and FCM credentials remain 100% on the server
  Future<BroadcastExecutionResult> broadcastServerNotification({
    required String audienceType,
    String? audienceValue,
    List<String>? specificStudentIds,
    required String title,
    required String body,
    String notificationType = 'GENERAL',
    String targetRoute = '/',
    Map<String, dynamic>? metadata,
  }) async {
    if (!SupabaseService.isInitialized || !SupabaseService.isLoggedIn) {
      return BroadcastExecutionResult(
        success: false,
        errorMessage: 'يجب تسجيل الدخول بحساب معتمد لإرسال الإشعارات',
      );
    }

    try {
      final payload = {
        'audience_type': audienceType,
        if (audienceValue != null) 'audience_value': audienceValue,
        if (specificStudentIds != null && specificStudentIds.isNotEmpty)
          'specific_student_ids': specificStudentIds,
        'title': title.trim(),
        'body': body.trim(),
        'notification_type': notificationType,
        'target_route': targetRoute,
        if (metadata != null) 'metadata': metadata,
      };

      if (kDebugMode) {
        print('──────────────────────────────────────────────────');
        print('[SECURE LEADER BROADCAST] Calling Edge Function: broadcast-notification');
        print('[SECURE LEADER BROADCAST] Audience: $audienceType');
        print('[SECURE LEADER BROADCAST] Title: ${title.trim()}');
      }

      // 1. Invoke Supabase Edge Function with caller's JWT token
      final res = await SupabaseService.client.functions.invoke(
        'broadcast-notification',
        body: payload,
      );

      if (res.status == 200) {
        final data = res.data is Map ? Map<String, dynamic>.from(res.data) : {};
        final recipientCount = (data['recipient_count'] as num?)?.toInt() ?? 0;
        final inAppCount = (data['in_app_count'] as num?)?.toInt() ?? 0;
        final tokensFound = (data['tokens_found'] as num?)?.toInt() ?? 0;
        final pushDeliveredCount = (data['push_delivered_count'] as num?)?.toInt() ?? 0;

        if (kDebugMode) {
          print('[SECURE LEADER BROADCAST] Status: 200 OK');
          print('[SECURE LEADER BROADCAST] Recipients: $recipientCount | In-App: $inAppCount | Push: $pushDeliveredCount');
        }

        return BroadcastExecutionResult(
          success: true,
          recipientCount: recipientCount,
          inAppCount: inAppCount,
          tokensFound: tokensFound,
          pushDeliveredCount: pushDeliveredCount,
        );
      } else {
        final errorMsg = res.data?['error']?.toString() ?? 'Server error status: ${res.status}';
        if (kDebugMode) {
          print('[SECURE LEADER BROADCAST] Edge Function Error: $errorMsg');
        }

        return BroadcastExecutionResult(
          success: false,
          errorMessage: errorMsg,
        );
      }
    } on FunctionException catch (e) {
      if (kDebugMode) {
        print('[SECURE LEADER BROADCAST] Function Exception: ${e.details} (status: ${e.status})');
      }
      return BroadcastExecutionResult(
        success: false,
        errorMessage: e.details?.toString() ?? 'فشل الاتصال بالخادم لإرسال الإشعار',
      );
    } catch (e) {
      if (kDebugMode) {
        print('[SECURE LEADER BROADCAST] Unexpected Exception: $e');
      }
      return BroadcastExecutionResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
}
