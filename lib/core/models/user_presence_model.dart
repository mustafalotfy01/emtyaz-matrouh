import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

@immutable
class UserPresenceModel {
  final String userId;
  final bool isOnline;
  final DateTime lastSeenAt;
  final DateTime updatedAt;

  const UserPresenceModel({
    required this.userId,
    required this.isOnline,
    required this.lastSeenAt,
    required this.updatedAt,
  });

  /// Calculates effective online status: true only if isOnline is true AND lastSeenAt is within 2 minutes
  bool get isEffectivelyOnline {
    if (!isOnline) return false;
    final nowUtc = DateTime.now().toUtc();
    final lastSeenUtc = lastSeenAt.toUtc();
    final difference = nowUtc.difference(lastSeenUtc);
    return difference.inSeconds <= 120 && difference.inSeconds >= -30;
  }

  factory UserPresenceModel.fromJson(Map<String, dynamic> json) {
    return UserPresenceModel(
      userId: json['user_id'] as String? ?? json['id'] as String? ?? '',
      isOnline: json['is_online'] as bool? ?? false,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.tryParse(json['last_seen_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'is_online': isOnline,
      'last_seen_at': lastSeenAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Human-friendly Arabic last seen representation
  String get formattedStatusArabic {
    if (isEffectivelyOnline) {
      return 'متصل الآن';
    }

    final localLastSeen = lastSeenAt.toLocal();
    final nowLocal = DateTime.now();
    final difference = nowLocal.difference(localLastSeen);

    if (difference.inSeconds < 60) {
      return 'آخر ظهور منذ لحظات';
    }

    if (difference.inMinutes < 60) {
      return 'آخر ظهور منذ ${difference.inMinutes} دقيقة';
    }

    final timeFormatter = DateFormat('hh:mm a', 'ar');
    final timeStr = timeFormatter.format(localLastSeen);

    final isToday = localLastSeen.year == nowLocal.year &&
        localLastSeen.month == nowLocal.month &&
        localLastSeen.day == nowLocal.day;

    if (isToday) {
      return 'آخر ظهور اليوم $timeStr';
    }

    final yesterday = nowLocal.subtract(const Duration(days: 1));
    final isYesterday = localLastSeen.year == yesterday.year &&
        localLastSeen.month == yesterday.month &&
        localLastSeen.day == yesterday.day;

    if (isYesterday) {
      return 'آخر ظهور أمس $timeStr';
    }

    final fullDateFormatter = DateFormat('d MMMM hh:mm a', 'ar');
    return 'آخر ظهور ${fullDateFormatter.format(localLastSeen)}';
  }
}
