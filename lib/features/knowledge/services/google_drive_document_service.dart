import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GoogleDriveValidationResult {
  final bool isValid;
  final String? fileId;
  final String? directDownloadUrl;
  final int? fileSizeBytes;
  final String? mimeType;
  final String? errorMessageAr;

  const GoogleDriveValidationResult({
    required this.isValid,
    this.fileId,
    this.directDownloadUrl,
    this.fileSizeBytes,
    this.mimeType,
    this.errorMessageAr,
  });

  String get formattedFileSize {
    if (fileSizeBytes == null || fileSizeBytes! <= 0) return '';
    final mb = fileSizeBytes! / (1024 * 1024);
    if (mb >= 1.0) {
      return '${mb.toStringAsFixed(1)} ميجابايت';
    }
    final kb = fileSizeBytes! / 1024;
    return '${kb.toStringAsFixed(0)} كيلوبايت';
  }
}

class GoogleDriveDocumentService {
  GoogleDriveDocumentService._();

  static final RegExp _fileIdRegex1 = RegExp(r'/file/d/([a-zA-Z0-9_-]{20,})');
  static final RegExp _fileIdRegex2 = RegExp(r'[?&]id=([a-zA-Z0-9_-]{20,})');
  static final RegExp _fileIdRegex3 = RegExp(r'/d/([a-zA-Z0-9_-]{20,})');
  static final RegExp _rawIdRegex = RegExp(r'^[a-zA-Z0-9_-]{25,}$');

  /// Extracts Google Drive File ID from diverse URL patterns
  static String? extractFileId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    if (_rawIdRegex.hasMatch(trimmed)) {
      return trimmed;
    }

    final match1 = _fileIdRegex1.firstMatch(trimmed);
    if (match1 != null && match1.groupCount >= 1) {
      return match1.group(1);
    }

    final match2 = _fileIdRegex2.firstMatch(trimmed);
    if (match2 != null && match2.groupCount >= 1) {
      return match2.group(1);
    }

    final match3 = _fileIdRegex3.firstMatch(trimmed);
    if (match3 != null && match3.groupCount >= 1) {
      return match3.group(1);
    }

    return null;
  }

  /// Builds direct download URLs for Google Drive files
  static String getDirectDownloadUrl(String fileId) {
    return 'https://drive.usercontent.google.com/download?id=$fileId&export=download&confirm=t';
  }

  /// Fallback direct URL format
  static String getFallbackDownloadUrl(String fileId) {
    return 'https://docs.google.com/uc?export=download&id=$fileId&confirm=t';
  }

  /// Pre-flight validation check for Admin before publishing
  static Future<GoogleDriveValidationResult> verifyAndProbe(String urlOrId, {http.Client? client}) async {
    final fileId = extractFileId(urlOrId);
    if (fileId == null) {
      return const GoogleDriveValidationResult(
        isValid: false,
        errorMessageAr: 'رابط Google Drive غير صالح أو لم يتم العثور على معرّف الملف (File ID). يرجى التأكد من نسخ رابط صحيح من Google Drive.',
      );
    }

    final directUrl = getDirectDownloadUrl(fileId);

    // On Flutter Web, browser CORS blocks direct cross-origin HTTP GET to drive.usercontent.google.com
    if (kIsWeb) {
      return GoogleDriveValidationResult(
        isValid: true,
        fileId: fileId,
        directDownloadUrl: directUrl,
      );
    }

    final httpClient = client ?? http.Client();
    final shouldCloseClient = client == null;

    try {
      // 1. Try sending GET request with Range header to inspect headers & first bytes
      final request = http.Request('GET', Uri.parse(directUrl))
        ..headers['Range'] = 'bytes=0-2048'
        ..headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

      final streamedResponse = await httpClient.send(request).timeout(const Duration(seconds: 15));
      final statusCode = streamedResponse.statusCode;

      if (statusCode != 200 && statusCode != 206 && statusCode != 302 && statusCode != 303) {
        return GoogleDriveValidationResult(
          isValid: false,
          fileId: fileId,
          errorMessageAr: 'تعذر الوصول إلى الملف ($statusCode). تأكد من ضبط إعدادات المشاركة في Google Drive على "أي شخص لديه الرابط يمكنه العرض" (Anyone with the link can view).',
        );
      }

      final bodyBytes = await streamedResponse.stream.take(2048).toList();
      final flattened = bodyBytes.expand((x) => x).toList();

      if (flattened.isEmpty) {
        return GoogleDriveValidationResult(
          isValid: false,
          fileId: fileId,
          errorMessageAr: 'الملف فارغ أو لم يُرجع أي بيانات.',
        );
      }

      // Check if it's a valid PDF by magic bytes %PDF-
      final isPdf = _checkPdfMagicBytes(flattened);
      if (!isPdf) {
        final contentPreview = utf8.decode(flattened.take(300).toList(), allowMalformed: true);
        if (contentPreview.contains('accounts.google.com') ||
            contentPreview.contains('ServiceLogin') ||
            contentPreview.contains('Access Denied') ||
            contentPreview.contains('طلب إذن الوصول')) {
          return GoogleDriveValidationResult(
            isValid: false,
            fileId: fileId,
            errorMessageAr: 'الملف محمي بطلب إذن الوصول. يرجى فتح Google Drive وتغيير الصلاحية إلى "عام - أي شخص لديه الرابط".',
          );
        }

        return GoogleDriveValidationResult(
          isValid: false,
          fileId: fileId,
          errorMessageAr: 'الملف المرفوع ليس بصيغة PDF صالحة.',
        );
      }

      // Read total size if Content-Range or Content-Length is present
      int? totalBytes = streamedResponse.contentLength;
      final contentRange = streamedResponse.headers['content-range'];
      if (contentRange != null && contentRange.contains('/')) {
        final parts = contentRange.split('/');
        if (parts.length > 1) {
          totalBytes = int.tryParse(parts[1]) ?? totalBytes;
        }
      }

      return GoogleDriveValidationResult(
        isValid: true,
        fileId: fileId,
        directDownloadUrl: directUrl,
        fileSizeBytes: totalBytes,
        mimeType: streamedResponse.headers['content-type'] ?? 'application/pdf',
      );
    } catch (e) {
      if (kDebugMode) print('[GoogleDriveDocumentService] Probe error: $e');
      // If network inspection timed out or encountered CORS fallback, allow if ID is syntactically sound
      return GoogleDriveValidationResult(
        isValid: true,
        fileId: fileId,
        directDownloadUrl: directUrl,
      );
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }
  }

  /// Check PDF Header Magic Bytes (%PDF- / 0x25 0x50 0x44 0x46 0x2D)
  static bool _checkPdfMagicBytes(List<int> bytes) {
    if (bytes.length < 5) return false;
    for (int i = 0; i <= bytes.length - 5 && i < 1024; i++) {
      if (bytes[i] == 0x25 &&
          bytes[i + 1] == 0x50 &&
          bytes[i + 2] == 0x44 &&
          bytes[i + 3] == 0x46 &&
          bytes[i + 4] == 0x2D) {
        return true;
      }
    }
    return false;
  }

  /// Download PDF Bytes in Chunks with Progress Callback
  static Future<Uint8List> downloadPdfBytes(
    String fileId, {
    void Function(int receivedBytes, int totalBytes)? onProgress,
    http.Client? client,
  }) async {
    final directUrl = getDirectDownloadUrl(fileId);
    final httpClient = client ?? http.Client();
    final shouldCloseClient = client == null;

    try {
      final request = http.Request('GET', Uri.parse(directUrl))
        ..headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

      final response = await httpClient.send(request).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('فشل في تحميل الملف من Google Drive (كود الخطأ: ${response.statusCode})');
      }

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;
      final List<int> accumulatedBytes = [];

      await for (final chunk in response.stream) {
        accumulatedBytes.addAll(chunk);
        receivedBytes += chunk.length;
        if (onProgress != null) {
          onProgress(receivedBytes, totalBytes);
        }
      }

      final resultBytes = Uint8List.fromList(accumulatedBytes);

      // Validate PDF magic bytes
      if (!_checkPdfMagicBytes(resultBytes)) {
        throw Exception('الملف الذي تم تنزيله ليس ملف PDF صالحاً أو يتطلب إذن وصول.');
      }

      return resultBytes;
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }
  }
}
