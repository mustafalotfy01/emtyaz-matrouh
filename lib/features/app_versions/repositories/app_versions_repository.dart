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
    final totalBytes = fileBytes.length;
    final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);

    // Supabase standard upload limit is 50MB
    if (totalBytes > 49 * 1024 * 1024) {
      throw Exception(
        'حجم ملف الـ APK ($totalMb MB) يتجاوز الحد الأقصى للرفع المباشر عبر السيرفر (50 MB).\n'
        'يرجى استخدام خانة "رابط التحميل المباشر" لوضع رابط تحميل من (Google Drive أو GitHub Releases أو MediaFire).',
      );
    }

    final sanitizedVersion = versionName.trim().replaceAll(' ', '_');
    final sanitizedFileName = fileName.trim().replaceAll(' ', '_');
    final storagePath = 'android/$sanitizedVersion/$sanitizedFileName';

    // Initial progress report
    onProgress?.call(0.05, (totalBytes * 0.05).toInt(), totalBytes);

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

        const chunkSize = 128 * 1024; // 128KB chunks
        int sentBytes = 0;

        Stream<List<int>> byteStream() async* {
          for (int i = 0; i < totalBytes; i += chunkSize) {
            final end = (i + chunkSize < totalBytes) ? i + chunkSize : totalBytes;
            final chunk = fileBytes.sublist(i, end);
            sentBytes += chunk.length;
            final ratio = (sentBytes / totalBytes).clamp(0.0, 0.98);
            onProgress?.call(ratio, sentBytes, totalBytes);
            yield chunk;
            // Slight yield to allow network transmission buffer
            await Future.delayed(const Duration(milliseconds: 10));
          }
        }

        request.sink.addStream(byteStream()).then((_) {
          request.sink.close();
        });

        final streamedResponse = await client.send(request).timeout(const Duration(minutes: 5));
        final response = await http.Response.fromStream(streamedResponse);
        client.close();

        if (response.statusCode >= 200 && response.statusCode < 300) {
          onProgress?.call(1.0, totalBytes, totalBytes);
          final publicUrl = _client.storage.from('app-releases').getPublicUrl(storagePath);
          return publicUrl;
        } else if (response.statusCode == 413 || response.body.contains('Payload too large') || response.body.contains('EntityTooLarge')) {
          throw Exception(
            'حجم الملف ($totalMb MB) يتجاوز الحد المسموح به في السيرفر (413 Payload Too Large).\n'
            'يرجى وضع رابط التحميل المباشر للـ APK في خانة الرابط.',
          );
        } else {
          throw Exception('فشل الخادم في استقبال الملف (${response.statusCode}): ${response.body}');
        }
      } catch (e) {
        lastError = e;
        if (kDebugMode) print('⚠️ Upload attempt $attempts failed: $e');
        if (e.toString().contains('413') || e.toString().contains('Payload too large')) {
          rethrow;
        }
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
      if (e.toString().contains('Payload too large') || e.toString().contains('413')) {
        throw Exception(
          'حجم الملف ($totalMb MB) أكبر من 50 MB (الحد الأقصى للرفع المباشر).\n'
          'يرجى إدخال رابط التحميل المباشر للـ APK في الخانة المخصصة.',
        );
      }
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
