import 'dart:async';
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

  /// Uploads APK file binary to Supabase Storage app-releases bucket with progress tracking
  /// Supports large APK files (50MB, 100MB, 200MB+)
  Future<String> uploadApkBinary({
    required int versionCode,
    required String versionName,
    required String fileName,
    required Uint8List fileBytes,
    void Function(double progress, int sentBytes, int totalBytes)? onProgress,
  }) async {
    final totalBytes = fileBytes.length;
    final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);

    final sanitizedFileName = fileName.trim().replaceAll(' ', '_').isNotEmpty
        ? fileName.trim().replaceAll(' ', '_')
        : 'app-release.apk';
    final storagePath = 'android/$versionCode/$sanitizedFileName';

    // Initial progress report
    onProgress?.call(0.02, (totalBytes * 0.02).toInt(), totalBytes);

    int attempts = 0;
    const maxAttempts = 3;
    dynamic lastError;

    while (attempts < maxAttempts) {
      attempts++;
      try {
        final token = _client.auth.currentSession?.accessToken ?? AppConfig.supabaseAnonKey;
        final uploadUrl = Uri.parse('${AppConfig.supabaseUrl}/storage/v1/object/app-releases/$storagePath');

        final client = http.Client();
        final request = http.StreamedRequest('POST', uploadUrl);
        request.headers.addAll({
          'Authorization': 'Bearer $token',
          'apikey': AppConfig.supabaseAnonKey,
          'Content-Type': 'application/vnd.android.package-archive',
          'x-upsert': 'true',
        });
        request.contentLength = totalBytes;

        const chunkSize = 256 * 1024; // 256KB chunks
        int sentBytes = 0;

        Stream<List<int>> byteStream() async* {
          for (int i = 0; i < totalBytes; i += chunkSize) {
            final end = (i + chunkSize < totalBytes) ? i + chunkSize : totalBytes;
            final chunk = fileBytes.sublist(i, end);
            sentBytes += chunk.length;
            final ratio = (sentBytes / totalBytes).clamp(0.0, 0.98);
            onProgress?.call(ratio, sentBytes, totalBytes);
            yield chunk;
            // Yield briefly to prevent UI blocking during large buffer slices
            await Future.delayed(const Duration(milliseconds: 5));
          }
        }

        request.sink.addStream(byteStream()).then((_) {
          request.sink.close();
        });

        // 15-minute timeout for large files on slower network connections
        final streamedResponse = await client.send(request).timeout(const Duration(minutes: 15));
        final response = await http.Response.fromStream(streamedResponse);
        client.close();

        if (response.statusCode >= 200 && response.statusCode < 300) {
          onProgress?.call(1.0, totalBytes, totalBytes);
          final publicUrl = _client.storage.from('app-releases').getPublicUrl(storagePath);
          return publicUrl;
        } else {
          throw Exception('فشل الخادم في استقبال الملف (${response.statusCode}): ${response.body}');
        }
      } catch (e) {
        lastError = e;
        if (kDebugMode) print('⚠️ Upload attempt $attempts failed: $e');
        if (attempts < maxAttempts) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }

    // Fallback to default Supabase SDK uploadBinary
    try {
      if (kDebugMode) print('Falling back to standard uploadBinary...');
      onProgress?.call(0.5, (totalBytes * 0.5).toInt(), totalBytes);
      await _client.storage.from('app-releases').uploadBinary(
        storagePath,
        fileBytes,
        fileOptions: const FileOptions(
          contentType: 'application/vnd.android.package-archive',
          upsert: true,
        ),
      );

      onProgress?.call(1.0, totalBytes, totalBytes);
      final publicUrl = _client.storage.from('app-releases').getPublicUrl(storagePath);
      return publicUrl;
    } catch (e) {
      if (kDebugMode) print('❌ Storage upload fallback error: $e');
      throw lastError ?? Exception('فشل في رفع ملف APK ($totalMb MB): $e');
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
      'release_notes': releaseNotes?.trim(),
      'force_update': forceUpdate,
      'minimum_supported_version': minimumSupportedVersion,
      'is_active': isActive,
      'platform': platform,
      if (fileName != null) 'file_name': fileName,
      if (fileSize != null) 'file_size': fileSize,
      if (checksum != null) 'checksum': checksum,
      if (_client.auth.currentUser != null) 'created_by': _client.auth.currentUser!.id,
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
      // Deactivate other active releases on this platform
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
  Future<void> deleteRelease(String id, {String? storagePath}) async {
    await _client.from('app_versions').delete().eq('id', id);

    if (storagePath != null && storagePath.isNotEmpty) {
      try {
        await _client.storage.from('app-releases').remove([storagePath]);
      } catch (e) {
        if (kDebugMode) print('⚠️ Storage cleanup warning: $e');
      }
    }
  }
}
