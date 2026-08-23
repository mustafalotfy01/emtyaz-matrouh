import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

Future<String> uploadApkPlatform({
  required String uploadUrl,
  required String token,
  required String apiKey,
  required String contentType,
  required Uint8List fileBytes,
  required String publicUrl,
  void Function(double progress, int sentBytes, int totalBytes)? onProgress,
}) async {
  final totalBytes = fileBytes.length;
  final uri = Uri.parse(uploadUrl);
  final client = http.Client();
  final request = http.StreamedRequest('POST', uri);
  request.headers.addAll({
    'Authorization': 'Bearer $token',
    'apikey': apiKey,
    'Content-Type': contentType,
    'x-upsert': 'true',
  });
  request.contentLength = totalBytes;

  const chunkSize = 64 * 1024; // 64KB chunks
  int sentBytes = 0;

  Stream<List<int>> byteStream() async* {
    for (int i = 0; i < totalBytes; i += chunkSize) {
      final end = (i + chunkSize < totalBytes) ? i + chunkSize : totalBytes;
      final chunk = fileBytes.sublist(i, end);
      sentBytes += chunk.length;
      final ratio = (sentBytes / totalBytes).clamp(0.0, 0.99);
      onProgress?.call(ratio, sentBytes, totalBytes);
      yield chunk;
      await Future.delayed(const Duration(milliseconds: 2));
    }
  }

  request.sink.addStream(byteStream()).then((_) {
    request.sink.close();
  });

  final streamedResponse = await client.send(request).timeout(const Duration(minutes: 20));
  final response = await http.Response.fromStream(streamedResponse);
  client.close();

  if (response.statusCode >= 200 && response.statusCode < 300) {
    onProgress?.call(1.0, totalBytes, totalBytes);
    return publicUrl;
  } else {
    throw Exception('فشل الخادم في استقبال الملف (${response.statusCode}): ${response.body}');
  }
}
