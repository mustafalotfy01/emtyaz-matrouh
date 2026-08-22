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
  Future<String> uploadApkBinary({
    required String versionName,
    required String fileName,
    required Uint8List fileBytes,
    void Function(double progress, int sentBytes, int totalBytes)? onProgress,
  }) async {
    final sanitizedVersion = versionName.trim().replaceAll(' ', '_');
    final sanitizedFileName = fileName.trim().replaceAll(' ', '_');
    final storagePath = 'android/$sanitizedVersion/$sanitizedFileName';
    final totalBytes = fileBytes.length;

    // Initial progress report
    onProgress?.call(0.01, 0, totalBytes);

    int attempts = 0;
    const maxAttempts = 2;
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

        final streamController = StreamController<List<int>>();
        request.sink.addStream(streamController.stream).then((_) {
          request.sink.close();
        });

        // Write bytes in 64KB chunks to track progress smoothly
        const chunkSize = 64 * 1024;
        int sentBytes = 0;
        Future.microtask(() async {
          try {
            for (int i = 0; i < totalBytes; i += chunkSize) {
              final end = (i + chunkSize < totalBytes) ? i + chunkSize : totalBytes;
              final chunk = fileBytes.sublist(i, end);
              streamController.add(chunk);
              sentBytes += chunk.length;
              final ratio = (sentBytes / totalBytes).clamp(0.0, 1.0);
              onProgress?.call(ratio, sentBytes, totalBytes);
              await Future.delayed(const Duration(milliseconds: 2));
            }
            await streamController.close();
          } catch (e) {
            streamController.addError(e);
          }
        });

        final streamedResponse = await client.send(request).timeout(const Duration(minutes: 8));
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
        if (kDebugMode) print('⚠️ Streamed upload attempt $attempts failed: $e');
        if (attempts < maxAttempts) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }

    // Fallback to default Supabase SDK uploadBinary if streamed request encountered an issue
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
      throw lastError ?? Exception('فشل في رفع ملف APK: $e');
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
