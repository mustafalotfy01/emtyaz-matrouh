import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<String> uploadApkPlatform({
  required String uploadUrl,
  required String token,
  required String apiKey,
  required String contentType,
  required Uint8List fileBytes,
  required String publicUrl,
  void Function(double progress, int sentBytes, int totalBytes)? onProgress,
}) async {
  final completer = Completer<String>();
  final totalBytes = fileBytes.length;

  final xhr = web.XMLHttpRequest();
  xhr.open('POST', uploadUrl);
  xhr.setRequestHeader('Authorization', 'Bearer $token');
  xhr.setRequestHeader('apikey', apiKey);
  xhr.setRequestHeader('Content-Type', contentType);
  xhr.setRequestHeader('x-upsert', 'true');

  xhr.upload.onprogress = (web.ProgressEvent event) {
    if (event.lengthComputable && event.total > 0) {
      final ratio = (event.loaded / event.total).clamp(0.0, 1.0);
      onProgress?.call(ratio, event.loaded, event.total);
    }
  }.toJS;

  xhr.onload = (web.Event event) {
    if (xhr.status >= 200 && xhr.status < 300) {
      onProgress?.call(1.0, totalBytes, totalBytes);
      if (!completer.isCompleted) completer.complete(publicUrl);
    } else {
      final errorMsg = xhr.responseText.isNotEmpty
          ? xhr.responseText
          : 'HTTP ${xhr.status}';
      if (!completer.isCompleted) {
        completer.completeError(
          Exception('فشل الخادم في استقبال الملف ($errorMsg)'),
        );
      }
    }
  }.toJS;

  xhr.onerror = (web.Event event) {
    if (!completer.isCompleted) {
      completer.completeError(
        Exception('خطأ في الاتصال بالشبكة أثناء رفع الملف (Status: ${xhr.status})'),
      );
    }
  }.toJS;

  xhr.ontimeout = (web.Event event) {
    if (!completer.isCompleted) {
      completer.completeError(Exception('انتهت مهلة رفع الملف'));
    }
  }.toJS;

  // Set timeout to 20 minutes (1,200,000 ms)
  xhr.timeout = 1200000;

  // Convert Uint8List to JS typed array for sending via XHR
  xhr.send(fileBytes.toJS);

  return completer.future;
}
