import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nurse_matrouh/features/knowledge/services/google_drive_document_service.dart';

void main() {
  group('GoogleDriveDocumentService Tests', () {
    test('1. Extracts File ID from diverse Google Drive URL formats', () {
      const standardUrl = 'https://drive.google.com/file/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/view?usp=sharing';
      expect(
        GoogleDriveDocumentService.extractFileId(standardUrl),
        '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms',
      );

      const openUrl = 'https://drive.google.com/open?id=1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms';
      expect(
        GoogleDriveDocumentService.extractFileId(openUrl),
        '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms',
      );

      const ucUrl = 'https://drive.google.com/uc?id=1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms&export=download';
      expect(
        GoogleDriveDocumentService.extractFileId(ucUrl),
        '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms',
      );

      const docUrl = 'https://docs.google.com/document/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/edit';
      expect(
        GoogleDriveDocumentService.extractFileId(docUrl),
        '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms',
      );

      const rawId = '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms';
      expect(
        GoogleDriveDocumentService.extractFileId(rawId),
        '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms',
      );

      const invalidUrl = 'https://example.com/not-a-drive-link';
      expect(GoogleDriveDocumentService.extractFileId(invalidUrl), isNull);
    });

    test('2. Builds proper direct download URL', () {
      const fileId = '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms';
      final directUrl = GoogleDriveDocumentService.getDirectDownloadUrl(fileId);
      expect(directUrl, contains('drive.usercontent.google.com/download?id=$fileId'));
      expect(directUrl, contains('export=download'));
      expect(directUrl, contains('confirm=t'));
    });

    test('3. verifyAndProbe validates genuine PDF file and extracts size', () async {
      // Mock genuine PDF response with %PDF- header
      final mockClient = MockClient((request) async {
        final pdfBytes = utf8.encode('%PDF-1.7\nSample clinical reference content...');
        return http.Response.bytes(
          pdfBytes,
          200,
          headers: {
            'content-type': 'application/pdf',
            'content-length': '${pdfBytes.length}',
          },
        );
      });

      final result = await GoogleDriveDocumentService.verifyAndProbe(
        'https://drive.google.com/file/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/view',
        client: mockClient,
      );

      expect(result.isValid, isTrue);
      expect(result.fileId, '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms');
      expect(result.fileSizeBytes, greaterThan(0));
      expect(result.formattedFileSize, contains('كيلوبايت'));
    });

    test('4. verifyAndProbe flags access denied / login redirect as invalid', () async {
      final mockClient = MockClient((request) async {
        final htmlResponse = utf8.encode('<html><head><title>Google Drive - Access Denied</title></head><body>ServiceLogin accounts.google.com</body></html>');
        return http.Response.bytes(
          htmlResponse,
          200,
          headers: {
            'content-type': 'text/html',
          },
        );
      });

      final result = await GoogleDriveDocumentService.verifyAndProbe(
        'https://drive.google.com/file/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/view',
        client: mockClient,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessageAr, contains('طلب إذن الوصول'));
    });

    test('5. downloadPdfBytes streams chunks and validates PDF magic bytes', () async {
      final mockClient = MockClient((request) async {
        final pdfBytes = utf8.encode('%PDF-1.4 Clinical Nursing Guide Book Content');
        return http.Response.bytes(
          pdfBytes,
          200,
          headers: {'content-type': 'application/pdf', 'content-length': '${pdfBytes.length}'},
        );
      });

      int reportedReceived = 0;
      int reportedTotal = 0;

      final bytes = await GoogleDriveDocumentService.downloadPdfBytes(
        '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms',
        client: mockClient,
        onProgress: (received, total) {
          reportedReceived = received;
          reportedTotal = total;
        },
      );

      expect(bytes, isNotEmpty);
      expect(reportedReceived, bytes.length);
      expect(reportedTotal, bytes.length);
      expect(utf8.decode(bytes), contains('%PDF-1.4'));
    });
  });
}
