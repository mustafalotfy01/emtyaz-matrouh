import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_matrouh/core/models/user_presence_model.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  group('UserPresenceModel & Stale Detection Tests', () {
    test('User is effectively online when is_online=true and lastSeen within 2 minutes', () {
      final presence = UserPresenceModel(
        userId: 'test-user-1',
        isOnline: true,
        lastSeenAt: DateTime.now().subtract(const Duration(seconds: 30)),
        updatedAt: DateTime.now(),
      );

      expect(presence.isEffectivelyOnline, isTrue);
      expect(presence.formattedStatusArabic, equals('متصل الآن'));
    });

    test('STALE PRESENCE: User is NOT online if is_online=true but lastSeen > 2 minutes ago', () {
      final presence = UserPresenceModel(
        userId: 'test-user-2',
        isOnline: true,
        lastSeenAt: DateTime.now().subtract(const Duration(minutes: 3)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 3)),
      );

      expect(presence.isEffectivelyOnline, isFalse);
      expect(presence.formattedStatusArabic, contains('آخر ظهور منذ 3 دقيقة'));
    });

    test('User is offline when is_online=false even if lastSeen is recent', () {
      final presence = UserPresenceModel(
        userId: 'test-user-3',
        isOnline: false,
        lastSeenAt: DateTime.now().subtract(const Duration(seconds: 15)),
        updatedAt: DateTime.now().subtract(const Duration(seconds: 15)),
      );

      expect(presence.isEffectivelyOnline, isFalse);
      expect(presence.formattedStatusArabic, equals('آخر ظهور منذ لحظات'));
    });

    test('Arabic formatting formats today time correctly', () {
      final now = DateTime.now();
      final lastSeen = DateTime(now.year, now.month, now.day, 14, 30);
      final presence = UserPresenceModel(
        userId: 'test-user-4',
        isOnline: false,
        lastSeenAt: lastSeen,
        updatedAt: lastSeen,
      );

      if (now.difference(lastSeen).inMinutes >= 60) {
        expect(presence.formattedStatusArabic, contains('آخر ظهور اليوم'));
      }
    });

    test('Arabic formatting formats yesterday correctly', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final presence = UserPresenceModel(
        userId: 'test-user-5',
        isOnline: false,
        lastSeenAt: yesterday,
        updatedAt: yesterday,
      );

      expect(presence.formattedStatusArabic, contains('آخر ظهور أمس'));
    });
  });
}
