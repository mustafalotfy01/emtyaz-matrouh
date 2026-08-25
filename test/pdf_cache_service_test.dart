import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_matrouh/features/knowledge/services/pdf_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('pdf_cache_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory' ||
            methodCall.method == 'getTemporaryDirectory') {
          return tempDir.path;
        }
        return tempDir.path;
      },
    );
  });

  tearDownAll(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('PdfCacheService Tests', () {
    const testArticleId = 'test-article-pdf-001';
    final samplePdfBytes = utf8.encode('%PDF-1.4 Fake clinical guide content');

    test('1. Saves and retrieves PDF from cache', () async {
      await PdfCacheService.saveCachedFile(testArticleId, samplePdfBytes);

      final hasCache = await PdfCacheService.hasCachedFile(testArticleId);
      expect(hasCache, isTrue);

      final retrievedBytes = await PdfCacheService.getCachedBytes(testArticleId);
      expect(retrievedBytes, isNotNull);
      expect(retrievedBytes!.length, samplePdfBytes.length);
    });

    test('2. Invalidation when updated_at is newer than cache timestamp', () async {
      final initialTime = DateTime(2026, 8, 1);
      await PdfCacheService.saveCachedFile(
        testArticleId,
        samplePdfBytes,
        updatedAt: initialTime,
      );

      // Same or older date keeps cache
      final hasSameDate = await PdfCacheService.hasCachedFile(testArticleId, updatedAt: initialTime);
      expect(hasSameDate, isTrue);

      // Newer update date invalidates cache
      final newerDate = DateTime(2026, 8, 25);
      final hasNewer = await PdfCacheService.hasCachedFile(testArticleId, updatedAt: newerDate);
      expect(hasNewer, isFalse);
    });

    test('3. Deletes single file and clears all cache', () async {
      await PdfCacheService.saveCachedFile('doc-a', samplePdfBytes);
      await PdfCacheService.saveCachedFile('doc-b', samplePdfBytes);

      expect(await PdfCacheService.hasCachedFile('doc-a'), isTrue);
      expect(await PdfCacheService.hasCachedFile('doc-b'), isTrue);

      await PdfCacheService.deleteCachedFile('doc-a');
      expect(await PdfCacheService.hasCachedFile('doc-a'), isFalse);
      expect(await PdfCacheService.hasCachedFile('doc-b'), isTrue);

      await PdfCacheService.clearAllCache();
      expect(await PdfCacheService.hasCachedFile('doc-b'), isFalse);
    });

    test('4. Formatted cache size computation', () async {
      await PdfCacheService.clearAllCache();
      final sizeStr = await PdfCacheService.getFormattedCacheSize();
      expect(sizeStr, contains('0'));
    });
  });
}
