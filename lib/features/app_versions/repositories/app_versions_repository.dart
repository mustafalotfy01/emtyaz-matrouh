import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/models/app_version_model.dart';
import '../../../core/services/supabase_service.dart';

class AppVersionsRepository {
  final SupabaseClient _client;

  AppVersionsRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  /// Fetches list of all app versions
  Future<List<AppVersionModel>> getAllVersions() async {
    try {
      final res = await _client
          .from('app_versions')
          .select('*')
          .order('version_code', ascending: false);
      return (res as List).map((row) => AppVersionModel.fromJson(row)).toList();
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching versions: $e');
      rethrow;
    }
  }

  /// Fetches the current active release for given platform
  Future<AppVersionModel?> getActiveRelease({String platform = 'android'}) async {
    try {
      final res = await _client
          .from('app_versions')
          .select('*')
          .eq('platform', platform)
          .eq('is_active', true)
          .order('version_code', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res == null) return null;
      return AppVersionModel.fromJson(res);
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching active release: $e');
      return null;
    }
  }

  /// Publishes an APK release to GitHub Releases via Supabase Edge Function
  /// No GitHub secrets or PAT are handled on client-side.
  Future<AppVersionModel> publishViaGitHubRelease({
    required String versionName,
    required int versionCode,
    String? releaseNotes,
    bool forceUpdate = false,
    int minimumSupportedVersion = 1,
    bool isActive = true,
    String? fileName,
    int? fileSize,
    Uint8List? apkBytes,
    String? directDownloadUrl,
    void Function(double progress, int sentBytes, int totalBytes)? onProgress,
  }) async {
    final token = _client.auth.currentSession?.accessToken ?? '';
    if (token.isEmpty) {
      throw Exception('جلسة المشرف غير صالحة. يرجى تسجيل الدخول مجدداً.');
    }

    final totalBytes = apkBytes?.length ?? fileSize ?? 0;
    onProgress?.call(0.05, (totalBytes * 0.05).toInt(), totalBytes);

    final edgeFunctionUrl = Uri.parse('${AppConfig.supabaseUrl}/functions/v1/create-github-release');

    final request = http.MultipartRequest('POST', edgeFunctionUrl);
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'apikey': AppConfig.supabaseAnonKey,
    });

    request.fields['version_name'] = versionName.trim();
    request.fields['version_code'] = versionCode.toString();
    request.fields['release_notes'] = releaseNotes?.trim() ?? '';
    request.fields['force_update'] = forceUpdate.toString();
    request.fields['minimum_supported_version'] = minimumSupportedVersion.toString();
    request.fields['is_active'] = isActive.toString();
    if (directDownloadUrl != null && directDownloadUrl.trim().isNotEmpty) {
      request.fields['direct_download_url'] = directDownloadUrl.trim();
    }

    if (apkBytes != null && apkBytes.isNotEmpty) {
      final safeName = (fileName != null && fileName.trim().isNotEmpty)
          ? fileName.trim().replaceAll(' ', '_')
          : 'app-release.apk';

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          apkBytes,
          filename: safeName,
        ),
      );
    }

    onProgress?.call(0.2, (totalBytes * 0.2).toInt(), totalBytes);

    final client = http.Client();
    final streamedResponse = await client.send(request).timeout(const Duration(minutes: 20));
    final response = await http.Response.fromStream(streamedResponse);
    client.close();

    onProgress?.call(1.0, totalBytes, totalBytes);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      if (json['data'] != null) {
        return AppVersionModel.fromJson(Map<String, dynamic>.from(json['data']));
      }
      return AppVersionModel(
        id: '',
        versionName: versionName,
        versionCode: versionCode,
        apkDownloadUrl: json['download_url'] ?? '',
        releaseNotes: releaseNotes,
        forceUpdate: forceUpdate,
        minimumSupportedVersion: minimumSupportedVersion,
        isActive: isActive,
        releaseDate: DateTime.now(),
        createdAt: DateTime.now(),
      );
    } else {
      dynamic errorData;
      try {
        errorData = jsonDecode(response.body);
      } catch (_) {}
      final errorMsg = errorData?['error'] ?? 'خطأ في معالجة الطلب (${response.statusCode}): ${response.body}';
      throw Exception(errorMsg);
    }
  }

  /// Publishes a release record directly using Supabase Database RLS (Super Admin Only)
  Future<AppVersionModel> publishRelease({
    required String versionName,
    required int versionCode,
    required String apkDownloadUrl,
    String? releaseNotes,
    bool forceUpdate = false,
    int minimumSupportedVersion = 1,
    bool isActive = true,
    String platform = 'android',
    String? fileName,
    int? fileSize,
    String? checksum,
    String? sha256,
    int? githubReleaseId,
    String? githubTagName,
    int? githubAssetId,
    String? releaseUrl,
  }) async {
    // 1. If this release is active, deactivate existing active releases for the platform
    if (isActive) {
      try {
        await _client
            .from('app_versions')
            .update({'is_active': false, 'updated_at': DateTime.now().toIso8601String()})
            .eq('platform', platform)
            .eq('is_active', true);
      } catch (e) {
        if (kDebugMode) print('⚠️ Note on deactivating older releases: $e');
      }
    }

    // 2. Insert new release record
    final payload = <String, dynamic>{
      'version_name': versionName.trim(),
      'version_code': versionCode,
      'apk_download_url': apkDownloadUrl.trim(),
      'download_url': apkDownloadUrl.trim(),
      'release_notes': releaseNotes?.trim(),
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
      if (_client.auth.currentUser != null) 'created_by': _client.auth.currentUser!.id,
      'release_date': DateTime.now().toIso8601String(),
      'published_at': DateTime.now().toIso8601String(),
    };

    final res = await _client
        .from('app_versions')
        .insert(payload)
        .select()
        .single();

    return AppVersionModel.fromJson(Map<String, dynamic>.from(res));
  }

  /// Toggles active status of an existing release (Admin ONLY)
  Future<void> toggleActiveStatus(String id, bool newStatus, {String platform = 'android'}) async {
    if (newStatus) {
      await _client
          .from('app_versions')
          .update({'is_active': false, 'updated_at': DateTime.now().toIso8601String()})
          .eq('platform', platform)
          .eq('is_active', true);
    }

    await _client
        .from('app_versions')
        .update({'is_active': newStatus, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }

  /// Deletes a release (Admin ONLY)
  Future<void> deleteRelease(String id) async {
    await _client.from('app_versions').delete().eq('id', id);
  }
}
