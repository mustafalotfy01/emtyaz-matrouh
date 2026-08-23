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
  final String? sha256;
  final int? githubReleaseId;
  final String? githubTagName;
  final int? githubAssetId;
  final String? releaseUrl;
  final String? createdBy;
  final DateTime releaseDate;
  final DateTime? publishedAt;
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
    this.sha256,
    this.githubReleaseId,
    this.githubTagName,
    this.githubAssetId,
    this.releaseUrl,
    this.createdBy,
    required this.releaseDate,
    this.publishedAt,
    required this.createdAt,
  });

  factory AppVersionModel.fromJson(Map<String, dynamic> json) {
    final downloadUrl = json['apk_download_url'] as String? ??
        json['download_url'] as String? ??
        '';

    return AppVersionModel(
      id: json['id'] as String? ?? '',
      versionName: json['version_name'] as String? ?? '',
      versionCode: (json['version_code'] as num?)?.toInt() ?? 0,
      apkDownloadUrl: downloadUrl,
      releaseNotes: json['release_notes'] as String?,
      forceUpdate: json['force_update'] as bool? ?? false,
      minimumSupportedVersion: (json['minimum_supported_version'] as num?)?.toInt() ?? 1,
      isActive: json['is_active'] as bool? ?? true,
      platform: json['platform'] as String? ?? 'android',
      fileName: json['file_name'] as String?,
      fileSize: (json['file_size'] as num?)?.toInt(),
      checksum: json['checksum'] as String?,
      sha256: json['sha256'] as String? ?? json['checksum'] as String?,
      githubReleaseId: (json['github_release_id'] as num?)?.toInt(),
      githubTagName: json['github_tag_name'] as String?,
      githubAssetId: (json['github_asset_id'] as num?)?.toInt(),
      releaseUrl: json['release_url'] as String?,
      createdBy: json['created_by'] as String?,
      releaseDate: json['release_date'] != null
          ? DateTime.tryParse(json['release_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'].toString())
          : null,
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
      'download_url': apkDownloadUrl,
      'release_notes': releaseNotes,
      'force_update': forceUpdate,
      'minimum_supported_version': minimumSupportedVersion,
      'is_active': isActive,
      'platform': platform,
      if (fileName != null) 'file_name': fileName,
      if (fileSize != null) 'file_size': fileSize,
      if (checksum != null) 'checksum': checksum,
      if (sha256 != null) 'sha256': sha256,
      if (githubReleaseId != null) 'github_release_id': githubReleaseId,
      if (githubTagName != null) 'github_tag_name': githubTagName,
      if (githubAssetId != null) 'github_asset_id': githubAssetId,
      if (releaseUrl != null) 'release_url': releaseUrl,
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
