import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_config.dart';
import 'supabase_service.dart';

class BroadcastExecutionResult {
  final bool success;
  final int recipientCount;
  final int inAppCount;
  final int tokensFound;
  final int pushDeliveredCount;
  final int pushFailedCount;
  final String? errorMessage;

  BroadcastExecutionResult({
    required this.success,
    this.recipientCount = 0,
    this.inAppCount = 0,
    this.tokensFound = 0,
    this.pushDeliveredCount = 0,
    this.pushFailedCount = 0,
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

      final functionsUrl = '${AppConfig.supabaseUrl}/functions/v1/broadcast-notification';
      final maskedUrl = functionsUrl.length > 25
          ? '${functionsUrl.substring(0, 20)}...${functionsUrl.substring(functionsUrl.length - 12)}'
          : functionsUrl;

      debugPrint('──────────────────────────────────────────────────');
      debugPrint('[EDGE_CLIENT] INVOKE_START');
      debugPrint('[EDGE_CLIENT] FUNCTION_NAME = broadcast-notification');
      debugPrint('[EDGE_CLIENT] INVOKE_URL = $maskedUrl');

      // 1. Invoke Supabase Edge Function with caller's JWT token
      final res = await SupabaseService.client.functions.invoke(
        'broadcast-notification',
        body: payload,
      );

      if (res.status == 200) {
        final data = res.data is Map ? Map<String, dynamic>.from(res.data) : {};
        final recipientCount = (data['recipients'] as num?)?.toInt() ??
            (data['recipient_count'] as num?)?.toInt() ?? 0;
        final inAppCount = (data['inAppInserted'] as num?)?.toInt() ??
            (data['in_app_count'] as num?)?.toInt() ?? 0;
        final tokensFound = (data['tokensFound'] as num?)?.toInt() ??
            (data['tokens_found'] as num?)?.toInt() ?? 0;
        final pushDeliveredCount = (data['pushSent'] as num?)?.toInt() ??
            (data['push_delivered_count'] as num?)?.toInt() ?? 0;
        final pushFailedCount = (data['pushFailed'] as num?)?.toInt() ?? 0;

        debugPrint('[EDGE_CLIENT] INVOKE_SUCCESS');
        debugPrint('[EDGE_CLIENT] STATUS = ${res.status}');
        debugPrint('[EDGE_CLIENT] RESPONSE = recipients: $recipientCount, inApp: $inAppCount, push: $pushDeliveredCount, pushFailed: $pushFailedCount');

        return BroadcastExecutionResult(
          success: true,
          recipientCount: recipientCount,
          inAppCount: inAppCount,
          tokensFound: tokensFound,
          pushDeliveredCount: pushDeliveredCount,
          pushFailedCount: pushFailedCount,
        );
      } else {
        final errorMsg = res.data?['error']?.toString() ?? 'Server error status: ${res.status}';
        debugPrint('[EDGE_CLIENT] INVOKE_FAILED');
        debugPrint('[EDGE_CLIENT] ERROR_TYPE = HttpErrorStatus_${res.status}');
        debugPrint('[EDGE_CLIENT] ERROR = $errorMsg');

        return BroadcastExecutionResult(
          success: false,
          errorMessage: errorMsg,
        );
      }
    } on FunctionException catch (e, st) {
      debugPrint('[EDGE_CLIENT] INVOKE_FAILED');
      debugPrint('[EDGE_CLIENT] ERROR_TYPE = FunctionException (status: ${e.status})');
      debugPrint('[EDGE_CLIENT] ERROR = ${e.details ?? e.reasonPhrase ?? e}');
      debugPrint('[EDGE_CLIENT] STACK = $st');

      return BroadcastExecutionResult(
        success: false,
        errorMessage: e.details?.toString() ?? e.reasonPhrase ?? 'فشل استدعاء الخادم لإرسال الإشعار',
      );
    } catch (e, st) {
      debugPrint('[EDGE_CLIENT] INVOKE_FAILED');
      debugPrint('[EDGE_CLIENT] ERROR_TYPE = ${e.runtimeType}');
      debugPrint('[EDGE_CLIENT] ERROR = $e');
      debugPrint('[EDGE_CLIENT] STACK = $st');

      return BroadcastExecutionResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
}
