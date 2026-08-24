import 'package:flutter/foundation.dart';
import '../utils/timezone_helper.dart';

@immutable
class UserPresenceModel {
  final String userId;
  final bool isOnline;
  final DateTime lastSeenAt;
  final DateTime updatedAt;
  final bool? effectiveIsOnline;
  final DateTime? serverNow;

  const UserPresenceModel({
    required this.userId,
    required this.isOnline,
    required this.lastSeenAt,
    required this.updatedAt,
    this.effectiveIsOnline,
    this.serverNow,
  });

  /// Authoritative effective online status: uses server calculated value if available,
  /// otherwise calculates against calibrated server time (within 2-minute stale timeout).
  bool get isEffectivelyOnline {
    if (effectiveIsOnline != null) {
      return effectiveIsOnline!;
    }
    if (!isOnline) return false;
    final serverUtc = serverNow?.toUtc() ?? AppTimezoneHelper.serverNowUtc;
    final lastSeenUtc = lastSeenAt.toUtc();
    final difference = serverUtc.difference(lastSeenUtc);
    return difference.inSeconds <= 120 && difference.inSeconds >= -30;
  }

  factory UserPresenceModel.fromJson(Map<String, dynamic> json) {
    DateTime? serverTime;
    if (json['server_now'] != null) {
      serverTime = DateTime.tryParse(json['server_now'].toString());
      if (serverTime != null) {
        AppTimezoneHelper.setServerTime(serverTime);
      }
    }

    final parsedLastSeen = json['last_seen_at'] != null
        ? DateTime.tryParse(json['last_seen_at'].toString()) ?? DateTime.now().toUtc()
        : DateTime.now().toUtc();

    final parsedUpdated = json['updated_at'] != null
        ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now().toUtc()
        : DateTime.now().toUtc();

    return UserPresenceModel(
      userId: json['user_id'] as String? ?? json['id'] as String? ?? '',
      isOnline: json['is_online'] as bool? ?? false,
      lastSeenAt: parsedLastSeen,
      updatedAt: parsedUpdated,
      effectiveIsOnline: json['effective_is_online'] as bool? ?? json['effectiveIsOnline'] as bool?,
      serverNow: serverTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'is_online': isOnline,
      'last_seen_at': lastSeenAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (effectiveIsOnline != null) 'effective_is_online': effectiveIsOnline,
      if (serverNow != null) 'server_now': serverNow?.toIso8601String(),
    };
  }

  /// Human-friendly Arabic last seen representation using Africa/Cairo timezone
  String get formattedStatusArabic {
    return AppTimezoneHelper.formatLastSeenArabic(
      lastSeenAt: lastSeenAt,
      isEffectivelyOnline: isEffectivelyOnline,
      referenceServerNow: serverNow,
    );
  }
}
