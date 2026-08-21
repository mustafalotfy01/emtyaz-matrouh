import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_matrouh/core/services/fcm_sender_service.dart';
import 'package:nurse_matrouh/core/services/firebase_messaging_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirebaseMessagingService Initialization & State Isolation Tests', () {
    test('FirebaseMessagingService initial state is not initialized', () {
      final fcm = FirebaseMessagingService.instance;
      expect(fcm.currentToken, isNull);
      expect(fcm.maskedToken, contains('غير متوفر'));
    });

    test('retrieveToken fails gracefully without unhandled crashes when not initialized', () async {
      final fcm = FirebaseMessagingService.instance;
      // In native test environment without Firebase Core, retrieveToken returns null with clear error
      final token = await fcm.retrieveToken();
      expect(token, isNull);
      expect(fcm.lastError, isNotNull);
    });

    test('FcmSenderService rejects broadcasts when user is not logged in', () async {
      final sender = FcmSenderService.instance;
      final result = await sender.broadcastServerNotification(
        audienceType: 'ALL_STUDENTS',
        title: 'تنبيه تجريبي',
        body: 'نص التنبيه',
      );
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('تسجيل الدخول'));
    });
  });
}
