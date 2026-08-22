import 'package:flutter/foundation.dart';

@immutable
class AppVersionModel {
  final String id;
  final String versionName;
  final int versionCode;
  final String apkDownloadUrl;
  final String? releaseNotes;
  final bool forceUpdate;
  final int minimumSupportedVersion;
  final bool isActive;
  final String platform;
  final String? fileName;
  final int? fileSize;
  final String? checksum;
  final String? createdBy;
  final DateTime releaseDate;
  final DateTime createdAt;

  const AppVersionModel({
    required this.id,
    required this.versionName,
    required this.versionCode,
    required this.apkDownloadUrl,
    this.releaseNotes,
    this.forceUpdate = false,
    this.minimumSupportedVersion = 1,
    this.isActive = true,
    this.platform = 'android',
    this.fileName,
    this.fileSize,
    this.checksum,
    this.createdBy,
    required this.releaseDate,
    required this.createdAt,
  });

  factory AppVersionModel.fromJson(Map<String, dynamic> json) {
    return AppVersionModel(
      id: json['id'] as String? ?? '',
      versionName: json['version_name'] as String? ?? '',
      versionCode: (json['version_code'] as num?)?.toInt() ?? 0,
      apkDownloadUrl: json['apk_download_url'] as String? ?? '',
      releaseNotes: json['release_notes'] as String?,
      forceUpdate: json['force_update'] as bool? ?? false,
      minimumSupportedVersion: (json['minimum_supported_version'] as num?)?.toInt() ?? 1,
      isActive: json['is_active'] as bool? ?? true,
      platform: json['platform'] as String? ?? 'android',
      fileName: json['file_name'] as String?,
      fileSize: (json['file_size'] as num?)?.toInt(),
      checksum: json['checksum'] as String?,
      createdBy: json['created_by'] as String?,
      releaseDate: json['release_date'] != null
          ? DateTime.tryParse(json['release_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version_name': versionName,
      'version_code': versionCode,
      'apk_download_url': apkDownloadUrl,
      'release_notes': releaseNotes,
      'force_update': forceUpdate,
      'minimum_supported_version': minimumSupportedVersion,
      'is_active': isActive,
      'platform': platform,
      if (fileName != null) 'file_name': fileName,
      if (fileSize != null) 'file_size': fileSize,
      if (checksum != null) 'checksum': checksum,
      if (createdBy != null) 'created_by': createdBy,
    };
  }

  String get formattedFileSize {
    if (fileSize == null || fileSize! <= 0) return '';
    final mb = fileSize! / (1024 * 1024);
    if (mb >= 1) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final kb = fileSize! / 1024;
    return '${kb.toStringAsFixed(0)} KB';
  }
}
