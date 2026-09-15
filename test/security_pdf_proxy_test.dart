import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nurse_matrouh/features/knowledge/services/google_drive_document_service.dart';

void main() {
  group('Security Audit Item 9: PDF Proxy & Credential Isolation Tests', () {
    const validId = '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms';

    test('1. Strict Google Drive File ID validation rejects malformed and malicious inputs', () {
      final invalidInputs = [
        '',
        '   ',
        'short',
        'http://malicious.site/evil.pdf',
        '12345/../../etc/passwd',
        '1BxiMVs0XR<script>alert(1)</script>',
        '1BxiMVs0XR; DROP TABLE users;--',
        '1BxiMVs0XR" or 1=1--',
        '1BxiMVs0XR&other_param=value',
        '1BxiMVs0XR?token=secret123',
        '1BxiMVs0XR\\..\\windows\\system32',
      ];

      for (final input in invalidInputs) {
        expect(
          GoogleDriveDocumentService.isValidFileId(input),
          isFalse,
          reason: 'Expected "$input" to be recognized as an INVALID Google Drive File ID',
        );
      }
    });

    test('2. Valid Google Drive File IDs are properly validated', () {
      final validInputs = [
        '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms',
        '1-abc_XYZ1234567890abcdef',
        'abcdefghijklmnopqrstuvwxyz01234',
      ];

      for (final input in validInputs) {
        expect(
          GoogleDriveDocumentService.isValidFileId(input),
          isTrue,
          reason: 'Expected "$input" to be recognized as a VALID Google Drive File ID',
        );
      }
    });

    test('3. extractFileId parses legitimate Google Drive URLs and raw IDs safely', () {
      final testCases = {
        'https://drive.google.com/file/d/$validId/view': validId,
        'https://drive.google.com/file/d/$validId/view?usp=sharing': validId,
        'https://drive.google.com/file/d/$validId/preview': validId,
        'https://drive.google.com/open?id=$validId': validId,
        'https://drive.google.com/uc?id=$validId&export=download': validId,
        'https://docs.google.com/document/d/$validId/edit': validId,
        validId: validId,
      };

      testCases.forEach((input, expectedId) {
        expect(GoogleDriveDocumentService.extractFileId(input), expectedId);
      });
    });

    test('4. extractFileId rejects non-Google domains and malicious URL constructs', () {
      final maliciousUrls = [
        'https://attacker-proxy.com/file/d/$validId/view',
        'https://corsproxy.io/?url=https://drive.google.com/file/d/$validId',
        'https://api.allorigins.win/raw?url=$validId',
        'javascript:alert(1)',
        'data:text/html,<script>alert(1)</script>',
      ];

      for (final url in maliciousUrls) {
        expect(
          GoogleDriveDocumentService.extractFileId(url),
          isNull,
          reason: 'Malicious/proxy URL "$url" should not extract as a valid drive file ID',
        );
      }
    });

    test('5. getDirectDownloadUrl sanitizes and builds official Google usercontent download URL', () {
      final url = GoogleDriveDocumentService.getDirectDownloadUrl(validId);
      expect(url.startsWith('https://drive.usercontent.google.com/download?id='), isTrue);
      expect(url.contains(validId), isTrue);
      expect(url.contains('corsproxy'), isFalse);
      expect(url.contains('allorigins'), isFalse);
    });

    test('6. getFallbackDownloadUrl uses official docs.google.com endpoint without proxies', () {
      final url = GoogleDriveDocumentService.getFallbackDownloadUrl(validId);
      expect(url.startsWith('https://docs.google.com/uc?export=download&id='), isTrue);
      expect(url.contains(validId), isTrue);
      expect(url.contains('corsproxy'), isFalse);
    });

    test('7. getDriveViewUrl constructs direct share link without third-party middle-boxes', () {
      final url = GoogleDriveDocumentService.getDriveViewUrl(validId);
      expect(url, 'https://drive.google.com/file/d/$validId/view?usp=sharing');
    });

    test('8. downloadPdfBytes immediately rejects invalid file IDs with ArgumentError', () async {
      final invalidIds = [
        '',
        '../../secret.txt',
        'https://evil.com/fake.pdf',
        'short',
      ];

      for (final badId in invalidIds) {
        expect(
          () => GoogleDriveDocumentService.downloadPdfBytes(badId),
          throwsA(isA<ArgumentError>()),
          reason: 'downloadPdfBytes should throw ArgumentError for invalid ID: "$badId"',
        );
      }
    });

    test('9. downloadPdfBytes candidate endpoints contain NO third-party CORS proxies', () async {
      final requestedUrls = <String>[];
      final mockClient = MockClient((request) async {
        requestedUrls.add(request.url.toString());
        return http.Response('Not Found', 404);
      });

      try {
        await GoogleDriveDocumentService.downloadPdfBytes(validId, client: mockClient);
      } catch (_) {
        // Expected to fail since all return 404
      }

      expect(requestedUrls, isNotEmpty);
      for (final url in requestedUrls) {
        expect(url.contains('corsproxy.io'), isFalse, reason: 'Must NOT use corsproxy.io');
        expect(url.contains('allorigins.win'), isFalse, reason: 'Must NOT use allorigins.win');
        expect(
          url.startsWith('https://drive.usercontent.google.com') ||
              url.startsWith('https://docs.google.com') ||
              url.startsWith('https://drive.google.com') ||
              url.startsWith('/api/proxy-pdf'),
          isTrue,
          reason: 'Candidate URL "$url" must only be a trusted Google endpoint or local proxy',
        );
      }
    });

    test('10. verifyAndProbe validates legitimate PDF content without leaking credentials', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers.containsKey('Authorization'), isFalse);
        expect(request.headers.containsKey('apikey'), isFalse);

        final samplePdf = utf8.encode('%PDF-1.4\nClinical Nursing Protocol\n%%EOF');
        return http.Response.bytes(
          samplePdf,
          200,
          headers: {
            'content-type': 'application/pdf',
            'content-length': '${samplePdf.length}',
          },
        );
      });

      final result = await GoogleDriveDocumentService.verifyAndProbe(validId, client: mockClient);
      expect(result.isValid, isTrue);
      expect(result.fileId, validId);
      expect(result.fileSizeBytes, greaterThan(0));
    });

    test('11. verifyAndProbe identifies private Google Drive files requiring authentication', () async {
      final mockClient = MockClient((request) async {
        final authRedirectHtml = utf8.encode('<html><body>accounts.google.com ServiceLogin طلب إذن الوصول</body></html>');
        return http.Response.bytes(
          authRedirectHtml,
          200,
          headers: {'content-type': 'text/html'},
        );
      });

      final result = await GoogleDriveDocumentService.verifyAndProbe(validId, client: mockClient);
      expect(result.isValid, isFalse);
      expect(result.errorMessageAr, contains('طلب إذن الوصول'));
    });
  });
}
