import 'package:flutter/material.dart';
import '../../../core/models/user_app_version_model.dart';
import '../../../core/utils/timezone_helper.dart';

@immutable
class AdminStudentOverviewModel {
  final String studentId;
  final String fullName;
  final String universityCode;
  final String email;
  final String phoneNumber;
  final double? gpa;
  final String studentGroup;
  final String registrationStatus;
  final bool isApproved;
  final String avatarUrl;

  final bool isOnline;
  final bool effectiveIsOnline;
  final DateTime lastSeenAt;

  final String appPlatform;
  final String installedVersionName;
  final int installedVersionCode;
  final String deviceInfo;
  final DateTime? versionReportedAt;
  final String latestPlatformVersionName;
  final int latestPlatformVersionCode;
  final AppUpdateStatus updateStatus;
  final DateTime serverNow;

  const AdminStudentOverviewModel({
    required this.studentId,
    required this.fullName,
    required this.universityCode,
    required this.email,
    required this.phoneNumber,
    this.gpa,
    required this.studentGroup,
    required this.registrationStatus,
    required this.isApproved,
    required this.avatarUrl,
    required this.isOnline,
    required this.effectiveIsOnline,
    required this.lastSeenAt,
    required this.appPlatform,
    required this.installedVersionName,
    required this.installedVersionCode,
    required this.deviceInfo,
    this.versionReportedAt,
    required this.latestPlatformVersionName,
    required this.latestPlatformVersionCode,
    required this.updateStatus,
    required this.serverNow,
  });

  factory AdminStudentOverviewModel.fromJson(Map<String, dynamic> json) {
    return AdminStudentOverviewModel(
      studentId: json['student_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'طالب امتياز',
      universityCode: json['university_code']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      gpa: (json['gpa'] as num?)?.toDouble(),
      studentGroup: json['student_group']?.toString() ?? 'A',
      registrationStatus: json['registration_status']?.toString() ?? 'approved',
      isApproved: json['is_approved'] == true,
      avatarUrl: json['avatar_url']?.toString() ?? '',
      isOnline: json['is_online'] == true,
      effectiveIsOnline: json['effective_is_online'] == true,
      lastSeenAt: DateTime.tryParse(json['last_seen_at']?.toString() ?? '') ?? DateTime.now().toUtc(),
      appPlatform: json['app_platform']?.toString() ?? 'android',
      installedVersionName: json['installed_version_name']?.toString() ?? '',
      installedVersionCode: (json['installed_version_code'] as num?)?.toInt() ?? 0,
      deviceInfo: json['device_info']?.toString() ?? '',
      versionReportedAt: DateTime.tryParse(json['version_reported_at']?.toString() ?? ''),
      latestPlatformVersionName: json['latest_platform_version_name']?.toString() ?? '',
      latestPlatformVersionCode: (json['latest_platform_version_code'] as num?)?.toInt() ?? 0,
      updateStatus: AppUpdateStatus.fromString(json['update_status']?.toString()),
      serverNow: DateTime.tryParse(json['server_now']?.toString() ?? '') ?? DateTime.now().toUtc(),
    );
  }

  /// Evaluates whether the student is currently online against a calibrated server timestamp
  bool isEffectivelyOnlineAt(DateTime referenceServerNow) {
    if (!isOnline) return false;
    final diff = referenceServerNow.toUtc().difference(lastSeenAt.toUtc()).inSeconds;
    return diff <= 120; // 2 minutes stale timeout rule
  }

  /// Formats the Arabic presence status string
  String formattedPresenceArabic(DateTime referenceServerNow) {
    final currentlyOnline = isEffectivelyOnlineAt(referenceServerNow);
    return AppTimezoneHelper.formatLastSeenArabic(
      lastSeenAt: lastSeenAt,
      isEffectivelyOnline: currentlyOnline,
      referenceServerNow: referenceServerNow,
    );
  }

  /// Formatted Platform and Version text (e.g. "Android • 1.3.0 (#4)")
  String get formattedPlatformAndVersion {
    final plat = appPlatform.toLowerCase() == 'android'
        ? 'Android'
        : (appPlatform.toLowerCase() == 'ios' ? 'iOS' : 'Web / PWA');

    if (installedVersionCode > 0) {
      final vName = installedVersionName.isNotEmpty ? installedVersionName : '1.0';
      return '$plat • $vName (#$installedVersionCode)';
    } else if (installedVersionName.isNotEmpty) {
      return '$plat • $installedVersionName';
    }
    return '$plat • غير معروف';
  }

  AdminStudentOverviewModel copyWithPresence({
    bool? isOnline,
    bool? effectiveIsOnline,
    DateTime? lastSeenAt,
  }) {
    return AdminStudentOverviewModel(
      studentId: studentId,
      fullName: fullName,
      universityCode: universityCode,
      email: email,
      phoneNumber: phoneNumber,
      gpa: gpa,
      studentGroup: studentGroup,
      registrationStatus: registrationStatus,
      isApproved: isApproved,
      avatarUrl: avatarUrl,
      isOnline: isOnline ?? this.isOnline,
      effectiveIsOnline: effectiveIsOnline ?? this.effectiveIsOnline,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      appPlatform: appPlatform,
      installedVersionName: installedVersionName,
      installedVersionCode: installedVersionCode,
      deviceInfo: deviceInfo,
      versionReportedAt: versionReportedAt,
      latestPlatformVersionName: latestPlatformVersionName,
      latestPlatformVersionCode: latestPlatformVersionCode,
      updateStatus: updateStatus,
      serverNow: serverNow,
    );
  }

  AdminStudentOverviewModel copyWithAppVersion({
    String? platform,
    String? versionName,
    int? versionCode,
    String? deviceInfo,
    DateTime? lastReportedAt,
    AppUpdateStatus? updateStatus,
  }) {
    return AdminStudentOverviewModel(
      studentId: studentId,
      fullName: fullName,
      universityCode: universityCode,
      email: email,
      phoneNumber: phoneNumber,
      gpa: gpa,
      studentGroup: studentGroup,
      registrationStatus: registrationStatus,
      isApproved: isApproved,
      avatarUrl: avatarUrl,
      isOnline: isOnline,
      effectiveIsOnline: effectiveIsOnline,
      lastSeenAt: lastSeenAt,
      appPlatform: platform ?? appPlatform,
      installedVersionName: versionName ?? installedVersionName,
      installedVersionCode: versionCode ?? installedVersionCode,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      versionReportedAt: lastReportedAt ?? versionReportedAt,
      latestPlatformVersionName: latestPlatformVersionName,
      latestPlatformVersionCode: latestPlatformVersionCode,
      updateStatus: updateStatus ?? this.updateStatus,
      serverNow: serverNow,
    );
  }
}
