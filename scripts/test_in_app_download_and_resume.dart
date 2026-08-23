import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

void main() async {
  print('===============================================================');
  print('🚀 IN-APP APK DOWNLOAD & RESUME (HTTP RANGE) INTEGRATION TEST 🚀');
  print('===============================================================\n');

  final apkFile = File('build/app/outputs/flutter-apk/app-release.apk');
  if (!apkFile.existsSync()) {
    print('❌ Real release APK not found at build/app/outputs/flutter-apk/app-release.apk');
    exit(1);
  }

  final int originalSize = apkFile.lengthSync();
  final originalDigest = sha256.convert(apkFile.readAsBytesSync());
  print('📦 Local Test APK Size: ${(originalSize / (1024 * 1024)).toStringAsFixed(2)} MB ($originalSize bytes)');
  print('🔑 Original SHA256: $originalDigest\n');

  // Start a local HTTP server that supports HTTP Range requests (mirroring Supabase Storage / CDN)
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8899);
  print('🌐 Started Local HTTP Range Server on http://127.0.0.1:8899');

  server.listen((HttpRequest request) async {
    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    
    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      // Range: bytes=START-
      final parts = rangeHeader.substring(6).split('-');
      final start = int.tryParse(parts[0]) ?? 0;
      final end = (parts.length > 1 && parts[1].isNotEmpty) ? (int.tryParse(parts[1]) ?? originalSize - 1) : (originalSize - 1);
      final length = (end - start) + 1;

      request.response.statusCode = HttpStatus.partialContent;
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      request.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$originalSize');
      request.response.headers.set(HttpHeaders.contentLengthHeader, length.toString());
      request.response.headers.contentType = ContentType('application', 'vnd.android.package-archive');

      final stream = apkFile.openRead(start, end + 1);
      await request.response.addStream(stream);
      await request.response.close();
    } else {
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      request.response.headers.set(HttpHeaders.contentLengthHeader, originalSize.toString());
      request.response.headers.contentType = ContentType('application', 'vnd.android.package-archive');

      final stream = apkFile.openRead();
      await request.response.addStream(stream);
      await request.response.close();
    }
  });

  final downloadDest = File('scratch/simulated_download_update.apk');
  if (downloadDest.existsSync()) downloadDest.deleteSync();
  downloadDest.createSync(recursive: true);

  print('--- Phase 1: Initial Download (Simulating Network Cut at 35%) ---');
  final client1 = HttpClient();
  final req1 = await client1.getUrl(Uri.parse('http://127.0.0.1:8899/update.apk'));
  final res1 = await req1.close();

  final sink1 = downloadDest.openWrite(mode: FileMode.write);
  int received1 = 0;
  final targetInterruptBytes = (originalSize * 0.35).toInt();

  await for (final chunk in res1) {
    sink1.add(chunk);
    received1 += chunk.length;
    final mb = (received1 / (1024 * 1024)).toStringAsFixed(1);
    final totalMb = (originalSize / (1024 * 1024)).toStringAsFixed(1);
    final percent = (received1 / originalSize * 100).toStringAsFixed(0);
    print('  [Downloader] Progress: $mb / $totalMb MB ($percent%)');

    if (received1 >= targetInterruptBytes) {
      print('⚡ [Simulated Failure] Network connection forcibly severed at $mb MB ($percent%)!');
      req1.abort();
      break;
    }
  }

  await sink1.flush();
  await sink1.close();
  client1.close(force: true);

  final partialSize = downloadDest.lengthSync();
  print('💾 Saved Partial File On Disk: ${(partialSize / (1024 * 1024)).toStringAsFixed(2)} MB ($partialSize bytes)\n');

  print('--- Phase 2: Resume Download from Byte $partialSize with HTTP Range Header ---');
  final client2 = HttpClient();
  final req2 = await client2.getUrl(Uri.parse('http://127.0.0.1:8899/update.apk'));
  req2.headers.set(HttpHeaders.rangeHeader, 'bytes=$partialSize-');
  final res2 = await req2.close();

  print('📡 Server Response Status: ${res2.statusCode} (${res2.statusCode == 206 ? '206 Partial Content -> RESUME ACCEPTED' : '200 OK -> FULL RESTART'})');
  print('📡 Server Content-Range: ${res2.headers.value(HttpHeaders.contentRangeHeader)}');

  final sink2 = downloadDest.openWrite(mode: FileMode.append);
  int received2 = partialSize;

  await for (final chunk in res2) {
    sink2.add(chunk);
    received2 += chunk.length;
    if (received2 % (10 * 1024 * 1024) <= chunk.length || received2 == originalSize) {
      final mb = (received2 / (1024 * 1024)).toStringAsFixed(1);
      final totalMb = (originalSize / (1024 * 1024)).toStringAsFixed(1);
      final percent = (received2 / originalSize * 100).toStringAsFixed(0);
      print('  [Downloader Resumed] Progress: $mb / $totalMb MB ($percent%)');
    }
  }

  await sink2.flush();
  await sink2.close();
  client2.close(force: true);
  await server.close();

  final downloadedSize = downloadDest.lengthSync();
  final downloadedDigest = sha256.convert(downloadDest.readAsBytesSync());

  print('\n--- Phase 3: Integrity Verification ---');
  print('📦 Downloaded File Size: ${(downloadedSize / (1024 * 1024)).toStringAsFixed(2)} MB ($downloadedSize bytes)');
  print('🔑 Downloaded SHA256:  $downloadedDigest');
  print('🔑 Original SHA256:    $originalDigest');

  final bool sizeMatch = downloadedSize == originalSize;
  final bool hashMatch = downloadedDigest == originalDigest;

  print('\nSize Match: $sizeMatch');
  print('SHA256 Match: $hashMatch');

  if (sizeMatch && hashMatch) {
    print('\n===============================================================');
    print('🎉 IN-APP DOWNLOAD & RESUME TEST: 100% PASS SUCCESSFUL! 🎉');
    print('===============================================================');
    exit(0);
  } else {
    print('\n❌ Verification failed!');
    exit(1);
  }
}
