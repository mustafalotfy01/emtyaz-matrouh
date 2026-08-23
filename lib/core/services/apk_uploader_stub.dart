import 'dart:typed_data';

Future<String> uploadApkPlatform({
  required String uploadUrl,
  required String token,
  required String apiKey,
  required String contentType,
  required Uint8List fileBytes,
  required String publicUrl,
  void Function(double progress, int sentBytes, int totalBytes)? onProgress,
}) => throw UnsupportedError('Cannot upload APK without IO or Web');
