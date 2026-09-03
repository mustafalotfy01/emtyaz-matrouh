import 'package:flutter/material.dart';
import '../../../core/models/user_app_version_model.dart';
import '../../../core/utils/timezone_helper.dart';
import '../../auth/models/user_profile.dart';

@immutable
class AdminStudentOverviewModel {
  final String studentId;
  final String fullName;
  final String universityCode;
  final String email;
  final String phoneNumber;
  final double? gpa;
  final String studentGroup;
  final String? studentGroupId;
  final StudentClassification? classification;
  final String? departmentName;
  final String? supervisorDoctorName;
  final bool previousWorkExperience;
  final String? previousWorkplace;
  final String? previousWorkDepartment;
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
    this.studentGroupId,
    this.classification,
    this.departmentName,
    this.supervisorDoctorName,
    this.previousWorkExperience = false,
    this.previousWorkplace,
    this.previousWorkDepartment,
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
    final rawClass = json['student_classification'] ?? json['classification'];
    final parsedClass = StudentClassification.fromString(rawClass?.toString());

    return AdminStudentOverviewModel(
      studentId: json['student_id']?.toString() ?? json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'طالب امتياز',
      universityCode: json['university_code']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      gpa: (json['gpa'] as num?)?.toDouble(),
      studentGroupId: json['student_group_id']?.toString(),
      studentGroup: () {
        final raw = json['group_name']?.toString() ?? json['student_group_name']?.toString();
        if (raw != null && raw.trim().isNotEmpty && raw != 'A' && raw != 'B' && raw != 'group_a' && raw != 'group_b' && raw != 'Group A' && raw != 'Group B' && raw != 'المجموعة A' && raw != 'المجموعة B') {
          return raw.trim();
        }
        final leg = json['student_group']?.toString();
        if (leg != null && leg.trim().isNotEmpty && leg != 'A' && leg != 'B' && leg != 'group_a' && leg != 'group_b' && leg != 'Group A' && leg != 'Group B' && leg != 'المجموعة A' && leg != 'المجموعة B') {
          return leg.trim();
        }
        return 'بدون جروب';
      }(),
      classification: parsedClass,
      departmentName: json['department_name']?.toString(),
      supervisorDoctorName: json['supervisor_doctor_name']?.toString(),
      previousWorkExperience: json['previous_work_experience'] == true,
      previousWorkplace: json['previous_workplace']?.toString(),
      previousWorkDepartment: json['previous_work_department']?.toString(),
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

  AdminStudentOverviewModel copyWith({
    String? studentId,
    String? fullName,
    String? universityCode,
    String? email,
    String? phoneNumber,
    double? gpa,
    String? studentGroup,
    String? studentGroupId,
    StudentClassification? classification,
    String? departmentName,
    String? supervisorDoctorName,
    bool? previousWorkExperience,
    String? previousWorkplace,
    String? previousWorkDepartment,
    String? registrationStatus,
    bool? isApproved,
    String? avatarUrl,
    bool? isOnline,
    bool? effectiveIsOnline,
    DateTime? lastSeenAt,
    String? appPlatform,
    String? installedVersionName,
    int? installedVersionCode,
    String? deviceInfo,
    DateTime? versionReportedAt,
    String? latestPlatformVersionName,
    int? latestPlatformVersionCode,
    AppUpdateStatus? updateStatus,
    DateTime? serverNow,
  }) {
    return AdminStudentOverviewModel(
      studentId: studentId ?? this.studentId,
      fullName: fullName ?? this.fullName,
      universityCode: universityCode ?? this.universityCode,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      gpa: gpa ?? this.gpa,
      studentGroup: studentGroup ?? this.studentGroup,
      studentGroupId: studentGroupId ?? this.studentGroupId,
      classification: classification ?? this.classification,
      departmentName: departmentName ?? this.departmentName,
      supervisorDoctorName: supervisorDoctorName ?? this.supervisorDoctorName,
      previousWorkExperience: previousWorkExperience ?? this.previousWorkExperience,
      previousWorkplace: previousWorkplace ?? this.previousWorkplace,
      previousWorkDepartment: previousWorkDepartment ?? this.previousWorkDepartment,
      registrationStatus: registrationStatus ?? this.registrationStatus,
      isApproved: isApproved ?? this.isApproved,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isOnline: isOnline ?? this.isOnline,
      effectiveIsOnline: effectiveIsOnline ?? this.effectiveIsOnline,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      appPlatform: appPlatform ?? this.appPlatform,
      installedVersionName: installedVersionName ?? this.installedVersionName,
      installedVersionCode: installedVersionCode ?? this.installedVersionCode,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      versionReportedAt: versionReportedAt ?? this.versionReportedAt,
      latestPlatformVersionName: latestPlatformVersionName ?? this.latestPlatformVersionName,
      latestPlatformVersionCode: latestPlatformVersionCode ?? this.latestPlatformVersionCode,
      updateStatus: updateStatus ?? this.updateStatus,
      serverNow: serverNow ?? this.serverNow,
    );
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
      studentGroupId: studentGroupId,
      classification: classification,
      departmentName: departmentName,
      supervisorDoctorName: supervisorDoctorName,
      previousWorkExperience: previousWorkExperience,
      previousWorkplace: previousWorkplace,
      previousWorkDepartment: previousWorkDepartment,
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
      studentGroupId: studentGroupId,
      classification: classification,
      departmentName: departmentName,
      supervisorDoctorName: supervisorDoctorName,
      previousWorkExperience: previousWorkExperience,
      previousWorkplace: previousWorkplace,
      previousWorkDepartment: previousWorkDepartment,
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
