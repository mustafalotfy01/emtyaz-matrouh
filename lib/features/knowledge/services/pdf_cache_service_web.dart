import 'dart:async';
import 'dart:typed_data';

class PdfCacheService {
  PdfCacheService._();

  static final Map<String, Uint8List> _webMemoryCache = {};
  static final Map<String, DateTime> _webCacheTimestamps = {};

  /// Checks if the PDF is available in local cache and up to date
  static Future<bool> hasCachedFile(String articleId, {DateTime? updatedAt}) async {
    if (articleId.isEmpty) return false;

    if (!_webMemoryCache.containsKey(articleId)) return false;
    if (updatedAt != null && _webCacheTimestamps.containsKey(articleId)) {
      final cachedTime = _webCacheTimestamps[articleId]!;
      if (updatedAt.isAfter(cachedTime)) {
        _webMemoryCache.remove(articleId);
        _webCacheTimestamps.remove(articleId);
        return false;
      }
    }
    return true;
  }

  /// Gets cached bytes
  static Future<Uint8List?> getCachedBytes(String articleId) async {
    return _webMemoryCache[articleId];
  }

  /// Gets local file path (null on web)
  static Future<String?> getCachedFilePath(String articleId) async {
    return null;
  }

  /// Saves downloaded PDF bytes to memory cache
  static Future<void> saveCachedFile(
    String articleId,
    List<int> bytes, {
    DateTime? updatedAt,
  }) async {
    if (articleId.isEmpty || bytes.isEmpty) return;
    _webMemoryCache[articleId] = Uint8List.fromList(bytes);
    _webCacheTimestamps[articleId] = updatedAt ?? DateTime.now();
  }

  /// Deletes a specific cached file
  static Future<void> deleteCachedFile(String articleId) async {
    _webMemoryCache.remove(articleId);
    _webCacheTimestamps.remove(articleId);
  }

  /// Clears all cached PDFs
  static Future<void> clearAllCache() async {
    _webMemoryCache.clear();
    _webCacheTimestamps.clear();
  }

  /// Calculates total size of cached PDFs in bytes
  static Future<int> getCacheSizeBytes() async {
    int total = 0;
    for (final b in _webMemoryCache.values) {
      total += b.length;
    }
    return total;
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
