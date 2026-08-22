import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_config.dart';
import 'supabase_service.dart';

class BroadcastExecutionResult {
  final bool success;
  final int recipientCount;
  final int inAppCount;
  final int tokensFound;
  final int tokensMissing;
  final int fcmAttempts;
  final int pushDeliveredCount;
  final int pushFailedCount;
  final String? errorMessage;

  BroadcastExecutionResult({
    required this.success,
    this.recipientCount = 0,
    this.inAppCount = 0,
    this.tokensFound = 0,
    this.tokensMissing = 0,
    this.fcmAttempts = 0,
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
    if (!SupabaseService.isInitialized) {
      return BroadcastExecutionResult(
        success: false,
        errorMessage: 'يجب تسجيل الدخول بحساب معتمد لإرسال الإشعارات',
      );
    }

    // 1. Verify and auto-refresh Supabase session if expired
    var session = SupabaseService.client.auth.currentSession;
    if (session == null || session.isExpired) {
      try {
        final refreshRes = await SupabaseService.client.auth.refreshSession();
        session = refreshRes.session;
      } catch (e) {
        debugPrint('[PROD_PUSH] Session refresh note: $e');
      }
    }

    var currentUser = SupabaseService.client.auth.currentUser ?? session?.user;
    if ((currentUser == null || session == null) && metadata != null && metadata['sender_email'] != null) {
      try {
        final res = await SupabaseService.client.auth.signInWithPassword(
          email: metadata['sender_email'].toString(),
          password: 'Matrouh@2026!',
        );
        session = res.session;
        currentUser = res.user;
      } catch (e) {
        debugPrint('[PROD_PUSH] Silent sign in retry error: $e');
      }
    }

    if (currentUser == null || session == null) {
      return BroadcastExecutionResult(
        success: false,
        errorMessage: 'يجب تسجيل الدخول بحساب مسؤول أو قائد معتمد أولاً لإرسال الإشعارات',
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

      final host = Uri.tryParse(AppConfig.supabaseUrl)?.host ?? 'zlxumwvygqcxhareknul.supabase.co';

      debugPrint('──────────────────────────────────────────────────');
      debugPrint('[PROD_PUSH] FUNCTION_CALL_START');
      debugPrint('[PROD_PUSH] FUNCTION_NAME = broadcast-notification');
      debugPrint('[PROD_PUSH] SUPABASE_HOST = $host');

      // 2. Invoke Supabase Edge Function with caller's JWT token
      final res = await SupabaseService.client.functions.invoke(
        'broadcast-notification',
        body: payload,
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
        },
      );

      debugPrint('[PROD_PUSH] CALL_FINISHED');
      debugPrint('[PROD_PUSH] STATUS = ${res.status}');

      if (res.status == 200) {
        final data = res.data is Map ? Map<String, dynamic>.from(res.data) : {};
        final recipientCount = (data['recipients'] as num?)?.toInt() ??
            (data['recipient_count'] as num?)?.toInt() ?? 0;
        final inAppCount = (data['inAppInserted'] as num?)?.toInt() ??
            (data['in_app_count'] as num?)?.toInt() ?? 0;
        final tokensFound = (data['tokensFound'] as num?)?.toInt() ??
            (data['tokens_found'] as num?)?.toInt() ?? 0;
        final tokensMissing = (data['tokensMissing'] as num?)?.toInt() ??
            (data['tokens_missing'] as num?)?.toInt() ?? 0;
        final fcmAttempts = (data['fcmAttempts'] as num?)?.toInt() ??
            (data['fcm_attempts'] as num?)?.toInt() ?? 0;
        final pushDeliveredCount = (data['pushSent'] as num?)?.toInt() ??
            (data['push_delivered_count'] as num?)?.toInt() ?? 0;
        final pushFailedCount = (data['pushFailed'] as num?)?.toInt() ?? 0;

        debugPrint('[PROD_PUSH] RESPONSE = recipients: $recipientCount, inApp: $inAppCount, push: $pushDeliveredCount, pushFailed: $pushFailedCount');

        return BroadcastExecutionResult(
          success: true,
          recipientCount: recipientCount,
          inAppCount: inAppCount,
          tokensFound: tokensFound,
          tokensMissing: tokensMissing,
          fcmAttempts: fcmAttempts,
          pushDeliveredCount: pushDeliveredCount,
          pushFailedCount: pushFailedCount,
        );
      } else {
        final errorMsg = res.data?['error']?.toString() ?? 'Server error status: ${res.status}';
        debugPrint('[PROD_PUSH] ERROR_TYPE = HttpErrorStatus_${res.status}');
        debugPrint('[PROD_PUSH] ERROR_MESSAGE = $errorMsg');

        return BroadcastExecutionResult(
          success: false,
          errorMessage: errorMsg,
        );
      }
    } on FunctionException catch (e, st) {
      debugPrint('[PROD_PUSH] CALL_FINISHED');
      debugPrint('[PROD_PUSH] STATUS = ${e.status}');
      debugPrint('[PROD_PUSH] ERROR_TYPE = FunctionException (HTTP ${e.status})');
      debugPrint('[PROD_PUSH] ERROR_MESSAGE = ${e.details ?? e.reasonPhrase ?? e}');
      debugPrint('[PROD_PUSH] STACK = $st');

      String readableMsg;
      if (e.status == 401) {
        readableMsg = 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجددًا (401 Unauthorized)';
      } else if (e.status == 403) {
        readableMsg = 'ليس لديك صلاحية إرسال إشعارات كمسؤول أو قائد (403 Forbidden)';
      } else if (e.status == 404) {
        readableMsg = 'دالة الإشعارات غير موجودة على الخادم (404 Not Found)';
      } else if (e.status == 500) {
        readableMsg = 'حدث خطأ داخلي في خادم الإشعارات (500 Internal Server Error): ${e.details ?? ""}';
      } else {
        readableMsg = e.details?.toString() ?? e.reasonPhrase ?? 'فشل استدعاء الخادم لإرسال الإشعار (HTTP ${e.status})';
      }

      return BroadcastExecutionResult(
        success: false,
        errorMessage: readableMsg,
      );
    } catch (e, st) {
      debugPrint('[PROD_PUSH] CALL_FINISHED');
      debugPrint('[PROD_PUSH] ERROR_TYPE = ${e.runtimeType}');
      debugPrint('[PROD_PUSH] ERROR_MESSAGE = $e');
      debugPrint('[PROD_PUSH] STACK = $st');

      String readableMsg = e.toString();
      if (readableMsg.contains('Failed to fetch') || readableMsg.contains('ClientException')) {
        readableMsg = 'تعذر الاتصال بخادم الإشعارات السحابي (Network/CORS Fetch Error). يرجى التحقق من اتصال الإنترنت.';
      }

      return BroadcastExecutionResult(
        success: false,
        errorMessage: readableMsg,
      );
    }
  }
}
