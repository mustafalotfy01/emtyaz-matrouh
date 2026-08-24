import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class AppTimezoneHelper {
  AppTimezoneHelper._();

  static bool _isInitialized = false;
  static Duration _serverTimeOffset = Duration.zero;

  /// Initializes timezone database for IANA timezones (Africa/Cairo)
  static void initialize() {
    if (_isInitialized) return;
    try {
      tz.initializeTimeZones();
      _isInitialized = true;
    } catch (_) {
      // Fallback in test / mock environment
      _isInitialized = true;
    }
  }

  /// Cairo timezone location instance
  static tz.Location get cairoLocation {
    initialize();
    try {
      return tz.getLocation('Africa/Cairo');
    } catch (_) {
      // Graceful fallback to UTC if timezone db not fully available in test
      return tz.getLocation('UTC');
    }
  }

  /// Sets the authoritative server time from PostgreSQL and computes local clock skew
  static void setServerTime(DateTime serverNow) {
    final serverUtc = serverNow.toUtc();
    final deviceUtc = DateTime.now().toUtc();
    _serverTimeOffset = serverUtc.difference(deviceUtc);
  }

  /// Returns authoritative server current time in UTC
  static DateTime get serverNowUtc {
    return DateTime.now().toUtc().add(_serverTimeOffset);
  }

  /// Returns authoritative server current time converted to Africa/Cairo
  static tz.TZDateTime get serverNowCairo {
    return toCairo(serverNowUtc);
  }

  /// Converts any DateTime to Africa/Cairo timezone without manual offset arithmetic
  static tz.TZDateTime toCairo(DateTime dateTime) {
    initialize();
    final utc = dateTime.isUtc ? dateTime : dateTime.toUtc();
    return tz.TZDateTime.from(utc, cairoLocation);
  }

  /// Formats last seen presence timestamp into human-readable Arabic text
  /// calibrated against authoritative server time and Africa/Cairo calendar days.
  static String formatLastSeenArabic({
    required DateTime lastSeenAt,
    required bool isEffectivelyOnline,
    DateTime? referenceServerNow,
  }) {
    if (isEffectivelyOnline) {
      return 'متصل الآن';
    }

    final serverNow = referenceServerNow?.toUtc() ?? serverNowUtc;
    final lastSeenUtc = lastSeenAt.toUtc();

    // Difference relative to server time
    final diff = serverNow.difference(lastSeenUtc);

    // If less than 60 seconds
    if (diff.inSeconds < 60) {
      return 'آخر ظهور منذ لحظات';
    }

    // Minutes formatting
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      if (m == 1) return 'آخر ظهور منذ دقيقة';
      if (m == 2) return 'آخر ظهور منذ دقيقتين';
      if (m >= 3 && m <= 10) return 'آخر ظهور منذ $m دقائق';
      return 'آخر ظهور منذ $m دقيقة';
    }

    // Hours relative check (< 2 hours)
    if (diff.inHours == 1) {
      return 'آخر ظهور منذ ساعة';
    }
    if (diff.inHours == 2 && diff.inMinutes < 150) {
      return 'آخر ظهور منذ ساعتين';
    }

    // Convert both timestamps to Africa/Cairo for precise calendar day matching
    final cairoLastSeen = toCairo(lastSeenAt);
    final cairoNow = toCairo(serverNow);

    final timeFormatter = DateFormat('hh:mm a', 'ar');
    final timeStr = timeFormatter.format(cairoLastSeen);

    // Same day in Cairo
    final isToday = cairoLastSeen.year == cairoNow.year &&
        cairoLastSeen.month == cairoNow.month &&
        cairoLastSeen.day == cairoNow.day;

    if (isToday) {
      return 'آخر ظهور اليوم $timeStr';
    }

    // Yesterday in Cairo
    final cairoYesterday = cairoNow.subtract(const Duration(days: 1));
    final isYesterday = cairoLastSeen.year == cairoYesterday.year &&
        cairoLastSeen.month == cairoYesterday.month &&
        cairoLastSeen.day == cairoYesterday.day;

    if (isYesterday) {
      return 'آخر ظهور أمس $timeStr';
    }

    // Older dates: format as e.g. "23 أغسطس 08:30 م"
    final fullDateFormatter = DateFormat('d MMMM hh:mm a', 'ar');
    return 'آخر ظهور ${fullDateFormatter.format(cairoLastSeen)}';
  }
}
