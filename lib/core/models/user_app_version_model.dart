import 'package:flutter/foundation.dart';

enum AppUpdateStatus {
  upToDate,
  outdated,
  forceUpdateRequired,
  unknown;

  static AppUpdateStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'up_to_date':
        return AppUpdateStatus.upToDate;
      case 'outdated':
        return AppUpdateStatus.outdated;
      case 'force_update_required':
        return AppUpdateStatus.forceUpdateRequired;
      default:
        return AppUpdateStatus.unknown;
    }
  }

  String get displayNameAr {
    switch (this) {
      case AppUpdateStatus.upToDate:
        return 'محدث';
      case AppUpdateStatus.outdated:
        return 'يحتاج تحديث';
      case AppUpdateStatus.forceUpdateRequired:
        return 'تحديث إجباري';
      case AppUpdateStatus.unknown:
        return 'غير معروف';
    }
  }
}

@immutable
class UserAppVersionModel {
  final String userId;
  final String platform;
  final String versionName;
  final int versionCode;
  final String? deviceInfo;
  final DateTime lastReportedAt;
  final String? latestVersionName;
  final int? latestVersionCode;
  final AppUpdateStatus updateStatus;

  const UserAppVersionModel({
    required this.userId,
    required this.platform,
    required this.versionName,
    required this.versionCode,
    this.deviceInfo,
    required this.lastReportedAt,
    this.latestVersionName,
    this.latestVersionCode,
    this.updateStatus = AppUpdateStatus.unknown,
  });

  factory UserAppVersionModel.fromJson(Map<String, dynamic> json) {
    return UserAppVersionModel(
      userId: json['user_id']?.toString() ?? '',
      platform: json['platform']?.toString() ?? 'android',
      versionName: json['version_name']?.toString() ?? '1.0.0',
      versionCode: (json['version_code'] as num?)?.toInt() ?? 1,
      deviceInfo: json['device_info']?.toString(),
      lastReportedAt: DateTime.tryParse(json['last_reported_at']?.toString() ?? '') ?? DateTime.now().toUtc(),
      latestVersionName: json['latest_version_name']?.toString(),
      latestVersionCode: (json['latest_version_code'] as num?)?.toInt(),
      updateStatus: AppUpdateStatus.fromString(json['update_status']?.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'platform': platform,
      'version_name': versionName,
      'version_code': versionCode,
      'device_info': deviceInfo,
      'last_reported_at': lastReportedAt.toIso8601String(),
      'latest_version_name': latestVersionName,
      'latest_version_code': latestVersionCode,
      'update_status': updateStatus.name,
    };
  }
}
