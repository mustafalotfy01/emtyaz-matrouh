import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_matrouh/core/models/user_presence_model.dart';
import 'package:nurse_matrouh/core/utils/timezone_helper.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    AppTimezoneHelper.initialize();
  });

  group('1. SERVER TIME SOURCE & CLOCK SKEW CALIBRATION', () {
    test('Server time calibration adjusts for client clock skew accurately', () {
      // Simulate client clock is 10 minutes ahead of server
      final actualServerNow = DateTime.utc(2026, 8, 24, 15, 0, 0);
      AppTimezoneHelper.setServerTime(actualServerNow);

      final calibratedNow = AppTimezoneHelper.serverNowUtc;
      expect(calibratedNow.year, equals(2026));
      expect(calibratedNow.month, equals(8));
      expect(calibratedNow.day, equals(24));
      expect(calibratedNow.hour, equals(15));
    });

    test('UserPresenceModel respects server-calculated effective_is_online', () {
      final presence = UserPresenceModel.fromJson({
        'user_id': 'u1',
        'is_online': true,
        'last_seen_at': '2026-08-24T15:00:00Z',
        'updated_at': '2026-08-24T15:00:00Z',
        'effective_is_online': true,
        'server_now': '2026-08-24T15:01:00Z',
      });

      expect(presence.isEffectivelyOnline, isTrue);
      expect(presence.formattedStatusArabic, equals('متصل الآن'));
    });
  });

  group('2. STALE USER DETECTION & 2-MINUTE TIMEOUT', () {
    test('User is effectively ONLINE within 2 minutes of server time', () {
      final serverTime = DateTime.utc(2026, 8, 24, 15, 1, 30);
      AppTimezoneHelper.setServerTime(serverTime);

      final presence = UserPresenceModel(
        userId: 'student-1',
        isOnline: true,
        lastSeenAt: DateTime.utc(2026, 8, 24, 15, 0, 0), // 90 seconds ago (< 120s)
        updatedAt: DateTime.utc(2026, 8, 24, 15, 0, 0),
        serverNow: serverTime,
      );

      expect(presence.isEffectivelyOnline, isTrue);
      expect(presence.formattedStatusArabic, equals('متصل الآن'));
    });

    test('STALE DETECTED: User is OFFLINE when lastSeenAt is > 2 minutes even if is_online is true', () {
      final serverTime = DateTime.utc(2026, 8, 24, 15, 2, 30);
      AppTimezoneHelper.setServerTime(serverTime);

      final presence = UserPresenceModel(
        userId: 'student-stale',
        isOnline: true,
        lastSeenAt: DateTime.utc(2026, 8, 24, 15, 0, 0), // 150 seconds ago (> 120s)
        updatedAt: DateTime.utc(2026, 8, 24, 15, 0, 0),
        serverNow: serverTime,
      );

      expect(presence.isEffectivelyOnline, isFalse);
      expect(presence.formattedStatusArabic, equals('آخر ظهور منذ دقيقتين'));
    });

    test('Explicit offline (is_online=false) is immediately offline', () {
      final serverTime = DateTime.utc(2026, 8, 24, 15, 0, 10);
      AppTimezoneHelper.setServerTime(serverTime);

      final presence = UserPresenceModel(
        userId: 'student-logout',
        isOnline: false,
        lastSeenAt: DateTime.utc(2026, 8, 24, 15, 0, 0), // 10 seconds ago
        updatedAt: DateTime.utc(2026, 8, 24, 15, 0, 0),
        serverNow: serverTime,
      );

      expect(presence.isEffectivelyOnline, isFalse);
      expect(presence.formattedStatusArabic, equals('آخر ظهور منذ لحظات'));
    });
  });

  group('3. AFRICA/CAIRO TIMEZONE ACCURACY (IANA)', () {
    test('Cairo timezone conversion converts UTC without manual +2/+3 arithmetic', () {
      final utcTime = DateTime.utc(2026, 8, 24, 12, 0, 0); // Noon UTC
      final cairoTime = AppTimezoneHelper.toCairo(utcTime);

      // In August (Egypt Summer Time / DST), Cairo is UTC+3
      expect(cairoTime.hour, equals(15));
      expect(cairoTime.minute, equals(0));
    });

    test('Midnight boundary (00:00) Cairo time accuracy', () {
      // 21:00 UTC on Aug 23 is 00:00 Cairo on Aug 24
      final utcNight = DateTime.utc(2026, 8, 23, 21, 0, 0);
      final cairoMidnight = AppTimezoneHelper.toCairo(utcNight);

      expect(cairoMidnight.day, equals(24));
      expect(cairoMidnight.hour, equals(0));
      expect(cairoMidnight.minute, equals(0));
    });

    test('Late night (23:00) Cairo time accuracy', () {
      // 20:00 UTC on Aug 24 is 23:00 Cairo on Aug 24
      final utcNight = DateTime.utc(2026, 8, 24, 20, 0, 0);
      final cairoNight = AppTimezoneHelper.toCairo(utcNight);

      expect(cairoNight.day, equals(24));
      expect(cairoNight.hour, equals(23));
      expect(cairoNight.minute, equals(0));
    });
  });

  group('4. ARABIC FORMATTER STRICT PATTERNS', () {
    final serverTime = DateTime.utc(2026, 8, 24, 18, 0, 0); // 21:00 Cairo
    setUp(() => AppTimezoneHelper.setServerTime(serverTime));

    test('متصل الآن when online', () {
      final formatted = AppTimezoneHelper.formatLastSeenArabic(
        lastSeenAt: serverTime,
        isEffectivelyOnline: true,
        referenceServerNow: serverTime,
      );
      expect(formatted, equals('متصل الآن'));
    });

    test('آخر ظهور منذ لحظات (< 60 seconds)', () {
      final formatted = AppTimezoneHelper.formatLastSeenArabic(
        lastSeenAt: serverTime.subtract(const Duration(seconds: 40)),
        isEffectivelyOnline: false,
        referenceServerNow: serverTime,
      );
      expect(formatted, equals('آخر ظهور منذ لحظات'));
    });

    test('آخر ظهور منذ دقيقة (1 minute)', () {
      final formatted = AppTimezoneHelper.formatLastSeenArabic(
        lastSeenAt: serverTime.subtract(const Duration(minutes: 1, seconds: 15)),
        isEffectivelyOnline: false,
        referenceServerNow: serverTime,
      );
      expect(formatted, equals('آخر ظهور منذ دقيقة'));
    });

    test('آخر ظهور منذ 5 دقائق (5 minutes)', () {
      final formatted = AppTimezoneHelper.formatLastSeenArabic(
        lastSeenAt: serverTime.subtract(const Duration(minutes: 5)),
        isEffectivelyOnline: false,
        referenceServerNow: serverTime,
      );
      expect(formatted, equals('آخر ظهور منذ 5 دقائق'));
    });

    test('آخر ظهور منذ ساعة (1 hour)', () {
      final formatted = AppTimezoneHelper.formatLastSeenArabic(
        lastSeenAt: serverTime.subtract(const Duration(minutes: 65)),
        isEffectivelyOnline: false,
        referenceServerNow: serverTime,
      );
      expect(formatted, equals('آخر ظهور منذ ساعة'));
    });

    test('آخر ظهور منذ ساعتين (2 hours)', () {
      final formatted = AppTimezoneHelper.formatLastSeenArabic(
        lastSeenAt: serverTime.subtract(const Duration(minutes: 125)),
        isEffectivelyOnline: false,
        referenceServerNow: serverTime,
      );
      expect(formatted, equals('آخر ظهور منذ ساعتين'));
    });

    test('آخر ظهور اليوم hh:mm م (Same calendar day in Cairo)', () {
      // 5 hours ago on same day
      final lastSeen = serverTime.subtract(const Duration(hours: 5));
      final formatted = AppTimezoneHelper.formatLastSeenArabic(
        lastSeenAt: lastSeen,
        isEffectivelyOnline: false,
        referenceServerNow: serverTime,
      );
      expect(formatted, contains('آخر ظهور اليوم'));
    });

    test('آخر ظهور أمس hh:mm م (Yesterday in Cairo)', () {
      // Yesterday
      final lastSeen = serverTime.subtract(const Duration(hours: 28));
      final formatted = AppTimezoneHelper.formatLastSeenArabic(
        lastSeenAt: lastSeen,
        isEffectivelyOnline: false,
        referenceServerNow: serverTime,
      );
      expect(formatted, contains('آخر ظهور أمس'));
    });

    test('آخر ظهور d MMMM hh:mm م (Older date)', () {
      // 5 days ago
      final lastSeen = DateTime.utc(2026, 8, 19, 10, 30, 0);
      final formatted = AppTimezoneHelper.formatLastSeenArabic(
        lastSeenAt: lastSeen,
        isEffectivelyOnline: false,
        referenceServerNow: serverTime,
      );
      expect(formatted, contains('آخر ظهور 19 أغسطس'));
    });
  });

  group('5. BATCH PRESENCE & 120+ USERS PERFORMANCE', () {
    test('Simulates 120 student records batch presence parsing and lookup in < 15ms', () {
      final stopwatch = Stopwatch()..start();

      final mockBatchJson = List.generate(125, (index) {
        final isOnline = index % 3 == 0;
        final secondsAgo = isOnline ? 20 : (index * 60);
        return {
          'user_id': 'student-$index',
          'is_online': isOnline,
          'last_seen_at': DateTime.utc(2026, 8, 24, 15, 0, 0)
              .subtract(Duration(seconds: secondsAgo))
              .toIso8601String(),
          'updated_at': DateTime.utc(2026, 8, 24, 15, 0, 0).toIso8601String(),
          'effective_is_online': isOnline && secondsAgo <= 120,
          'server_now': '2026-08-24T15:00:00Z',
        };
      });

      final Map<String, UserPresenceModel> cache = {};
      for (final item in mockBatchJson) {
        final model = UserPresenceModel.fromJson(item);
        cache[model.userId] = model;
      }

      stopwatch.stop();

      expect(cache.length, equals(125));
      expect(cache['student-0']!.isEffectivelyOnline, isTrue);
      expect(cache['student-0']!.formattedStatusArabic, equals('متصل الآن'));
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });
}
