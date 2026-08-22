import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  /// Uploads APK file binary to Supabase Storage app-releases bucket
  Future<String> uploadApkBinary({
    required String versionName,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    final sanitizedVersion = versionName.trim().replaceAll(' ', '_');
    final sanitizedFileName = fileName.trim().replaceAll(' ', '_');
    final storagePath = 'android/$sanitizedVersion/$sanitizedFileName';

    try {
      await _client.storage.from('app-releases').uploadBinary(
        storagePath,
        fileBytes,
        fileOptions: const FileOptions(
          contentType: 'application/vnd.android.package-archive',
          upsert: true,
        ),
      );

      final publicUrl = _client.storage.from('app-releases').getPublicUrl(storagePath);
      return publicUrl;
    } catch (e) {
      if (kDebugMode) print('❌ Storage upload error: $e');
      rethrow;
    }
  }

  /// Publishes a new version (Admin ONLY)
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
  }) async {
    // 1. If this release is active, deactivate existing active releases
    if (isActive) {
      try {
        await _client
            .from('app_versions')
            .update({'is_active': false, 'updated_at': DateTime.now().toIso8601String()})
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
      'release_notes': releaseNotes?.trim(),
      'force_update': forceUpdate,
      'minimum_supported_version': minimumSupportedVersion,
      'is_active': isActive,
      'release_date': DateTime.now().toIso8601String(),
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
      // Deactivate other active releases
      await _client
          .from('app_versions')
          .update({'is_active': false, 'updated_at': DateTime.now().toIso8601String()})
          .eq('is_active', true);
    }

    await _client
        .from('app_versions')
        .update({'is_active': newStatus, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }

  /// Deletes a release (Admin ONLY)
  Future<void> deleteRelease(String id, {String? storagePath}) async {
    await _client.from('app_versions').delete().eq('id', id);

    if (storagePath != null && storagePath.isNotEmpty) {
      try {
        await _client.storage.from('app-releases').remove([storagePath]);
      } catch (e) {
        if (kDebugMode) print('⚠️ Storage cleanup warning: ');
      }
    }
  }
}
