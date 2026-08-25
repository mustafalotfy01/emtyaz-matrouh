import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class PdfCacheService {
  PdfCacheService._();

  static Future<Directory?> _getCacheDirectory() async {
    try {
      final baseDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${baseDir.path}/clinical_pdf_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      return cacheDir;
    } catch (e) {
      if (kDebugMode) print('[PdfCacheService IO] Error getting cache directory: $e');
      return null;
    }
  }

  /// Checks if the PDF is available in local cache and up to date
  static Future<bool> hasCachedFile(String articleId, {DateTime? updatedAt}) async {
    if (articleId.isEmpty) return false;

    try {
      final cacheDir = await _getCacheDirectory();
      if (cacheDir == null) return false;

      final file = File('${cacheDir.path}/$articleId.pdf');
      final metaFile = File('${cacheDir.path}/$articleId.meta');

      if (!await file.exists() || await file.length() < 10) {
        return false;
      }

      if (updatedAt != null && await metaFile.exists()) {
        final metaContent = await metaFile.readAsString();
        final metaJson = jsonDecode(metaContent) as Map<String, dynamic>;
        final cachedTimeStr = metaJson['updated_at'] as String?;
        if (cachedTimeStr != null) {
          final cachedTime = DateTime.tryParse(cachedTimeStr);
          if (cachedTime != null && updatedAt.isAfter(cachedTime)) {
            // Outdated cache
            await deleteCachedFile(articleId);
            return false;
          }
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('[PdfCacheService IO] hasCachedFile error: $e');
      return false;
    }
  }

  /// Gets cached bytes
  static Future<Uint8List?> getCachedBytes(String articleId) async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (cacheDir == null) return null;

      final file = File('${cacheDir.path}/$articleId.pdf');
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('[PdfCacheService IO] getCachedBytes error: $e');
      return null;
    }
  }

  /// Gets local file path for IO platforms
  static Future<String?> getCachedFilePath(String articleId) async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (cacheDir == null) return null;

      final file = File('${cacheDir.path}/$articleId.pdf');
      if (await file.exists() && await file.length() > 0) {
        return file.path;
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('[PdfCacheService IO] getCachedFilePath error: $e');
      return null;
    }
  }

  /// Saves downloaded PDF bytes to local cache
  static Future<void> saveCachedFile(
    String articleId,
    List<int> bytes, {
    DateTime? updatedAt,
  }) async {
    if (articleId.isEmpty || bytes.isEmpty) return;

    final now = updatedAt ?? DateTime.now();

    try {
      final cacheDir = await _getCacheDirectory();
      if (cacheDir == null) return;

      final file = File('${cacheDir.path}/$articleId.pdf');
      await file.writeAsBytes(bytes, flush: true);

      final metaFile = File('${cacheDir.path}/$articleId.meta');
      final metaData = {
        'article_id': articleId,
        'updated_at': now.toIso8601String(),
        'cached_at': DateTime.now().toIso8601String(),
        'size_bytes': bytes.length,
      };
      await metaFile.writeAsString(jsonEncode(metaData));
    } catch (e) {
      if (kDebugMode) print('[PdfCacheService IO] saveCachedFile error: $e');
    }
  }

  /// Deletes a specific cached file
  static Future<void> deleteCachedFile(String articleId) async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (cacheDir == null) return;

      final file = File('${cacheDir.path}/$articleId.pdf');
      if (await file.exists()) await file.delete();

      final metaFile = File('${cacheDir.path}/$articleId.meta');
      if (await metaFile.exists()) await metaFile.delete();
    } catch (e) {
      if (kDebugMode) print('[PdfCacheService IO] deleteCachedFile error: $e');
    }
  }

  /// Clears all cached PDFs
  static Future<void> clearAllCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (cacheDir != null && await cacheDir.exists()) {
        final entities = cacheDir.listSync();
        for (final entity in entities) {
          await entity.delete(recursive: true);
        }
      }
    } catch (e) {
      if (kDebugMode) print('[PdfCacheService IO] clearAllCache error: $e');
    }
  }

  /// Calculates total size of cached PDFs in bytes
  static Future<int> getCacheSizeBytes() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (cacheDir == null || !await cacheDir.exists()) return 0;

      int total = 0;
      final entities = cacheDir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (e) {
      return 0;
    }
  }

  /// Formatted cache size
  static Future<String> getFormattedCacheSize() async {
    final bytes = await getCacheSizeBytes();
    if (bytes <= 0) return '0 ميجابايت';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1.0) {
      return '${mb.toStringAsFixed(1)} ميجابايت';
    }
    final kb = bytes / 1024;
    return '${kb.toStringAsFixed(0)} كيلوبايت';
  }
}
