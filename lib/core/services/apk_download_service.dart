import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'android_installer_service.dart';

enum ApkDownloadStatus {
  idle,
  checking,
  downloading,
  paused,
  error,
  completed,
  permissionRequired,
  installing,
}

@immutable
class ApkDownloadState {
  final ApkDownloadStatus status;
  final int downloadedBytes;
  final int totalBytes;
  final double progress;
  final int speedBytesPerSec;
  final String? filePath;
  final String? errorMessage;
  final bool supportsResume;

  const ApkDownloadState({
    this.status = ApkDownloadStatus.idle,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.progress = 0.0,
    this.speedBytesPerSec = 0,
    this.filePath,
    this.errorMessage,
    this.supportsResume = true,
  });

  ApkDownloadState copyWith({
    ApkDownloadStatus? status,
    int? downloadedBytes,
    int? totalBytes,
    double? progress,
    int? speedBytesPerSec,
    String? filePath,
    String? errorMessage,
    bool? supportsResume,
  }) {
    return ApkDownloadState(
      status: status ?? this.status,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      progress: progress ?? this.progress,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      filePath: filePath ?? this.filePath,
      errorMessage: errorMessage ?? this.errorMessage,
      supportsResume: supportsResume ?? this.supportsResume,
    );
  }

  String get formattedDownloaded {
    final mb = downloadedBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  String get formattedTotal {
    if (totalBytes <= 0) return '-- MB';
    final mb = totalBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  int get percentage => (progress * 100).clamp(0, 100).toInt();
}

class ApkDownloadService {
  ApkDownloadService._();
  static final ApkDownloadService instance = ApkDownloadService._();

  final _stateController = StreamController<ApkDownloadState>.broadcast();
  Stream<ApkDownloadState> get stateStream => _stateController.stream;

  ApkDownloadState _currentState = const ApkDownloadState();
  ApkDownloadState get currentState => _currentState;

  HttpClientRequest? _activeRequest;
  StreamSubscription<List<int>>? _streamSubscription;
  IOSink? _fileSink;
  bool _isCanceled = false;
  int? _expectedVersionCode;

  void _emit(ApkDownloadState state) {
    _currentState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  /// Resolves the destination file path for the given version code
  Future<File?> _getTargetFile(int versionCode, String? suggestedFileName) async {
    final dirPath = await AndroidInstallerService.getDownloadDirectory();
    if (dirPath == null) return null;

    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final safeName = (suggestedFileName != null && suggestedFileName.trim().isNotEmpty)
        ? suggestedFileName.trim().replaceAll(' ', '_')
        : 'nurse_matrouh_update_v$versionCode.apk';

    return File('${dir.path}/$safeName');
  }

  /// Starts or resumes downloading an APK file from [downloadUrl]
  Future<void> startDownload({
    required String downloadUrl,
    required int versionCode,
    int? expectedTotalBytes,
    String? fileName,
    String? expectedSha256,
  }) async {
    _expectedVersionCode = versionCode;
    if (kIsWeb) {
      _emit(_currentState.copyWith(
        status: ApkDownloadStatus.error,
        errorMessage: 'تحميل ملفات APK غير مدعوم على متصفح الويب.',
      ));
      return;
    }

    _isCanceled = false;
    _emit(_currentState.copyWith(
      status: ApkDownloadStatus.checking,
      errorMessage: null,
    ));

    try {
      final targetFile = await _getTargetFile(versionCode, fileName);
      if (targetFile == null) {
        throw Exception('تعذر الوصول إلى مجلد التخزين الداخلي للتطبيق.');
      }

      int existingBytes = 0;
      if (targetFile.existsSync()) {
        existingBytes = targetFile.lengthSync();
        // If file already equals expected size, verify or reset
        if (expectedTotalBytes != null && expectedTotalBytes > 0 && existingBytes == expectedTotalBytes) {
          final validation = await AndroidInstallerService.verifyApk(targetFile.path);
          if (validation.isValid) {
            _emit(_currentState.copyWith(
              status: ApkDownloadStatus.completed,
              downloadedBytes: existingBytes,
              totalBytes: existingBytes,
              progress: 1.0,
              filePath: targetFile.path,
              errorMessage: null,
            ));
            return;
          } else {
            try {
              targetFile.deleteSync();
            } catch (_) {}
            existingBytes = 0;
          }
        }
      }

      final uri = Uri.parse(downloadUrl.trim());
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 25);

      _activeRequest = await client.getUrl(uri);

      // Support HTTP Range request for Resuming
      bool isResuming = false;
      if (existingBytes > 0) {
        _activeRequest!.headers.set(HttpHeaders.rangeHeader, 'bytes=$existingBytes-');
        isResuming = true;
      }

      var response = await _activeRequest!.close();

      if (_isCanceled) {
        client.close(force: true);
        return;
      }

      var statusCode = response.statusCode;

      // If server rejected the Range request (HTTP 416) or failed resume, delete local file and start fresh from byte 0
      if (statusCode == HttpStatus.requestedRangeNotSatisfiable ||
          (statusCode != HttpStatus.ok && statusCode != HttpStatus.partialContent && isResuming)) {
        if (targetFile.existsSync()) {
          try {
            targetFile.deleteSync();
          } catch (_) {}
        }
        existingBytes = 0;
        isResuming = false;

        _activeRequest = await client.getUrl(uri);
        response = await _activeRequest!.close();
        statusCode = response.statusCode;
      }

      int totalBytes = expectedTotalBytes ?? 0;
      int startByte = 0;
      FileMode openMode = FileMode.write;

      if (statusCode == HttpStatus.partialContent) {
        // 206 Partial Content: Server accepts resume
        startByte = existingBytes;
        openMode = FileMode.append;

        final contentRange = response.headers.value(HttpHeaders.contentRangeHeader);
        if (contentRange != null && contentRange.contains('/')) {
          final totalStr = contentRange.split('/').last;
          totalBytes = int.tryParse(totalStr) ?? (startByte + response.contentLength);
        } else {
          totalBytes = startByte + (response.contentLength > 0 ? response.contentLength : 0);
        }
      } else if (statusCode == HttpStatus.ok) {
        // 200 OK: Full file download from beginning
        startByte = 0;
        openMode = FileMode.write;
        if (response.contentLength > 0) {
          totalBytes = response.contentLength;
        }
      } else {
        throw Exception('فشل الاتصال بالخادم (HTTP $statusCode).');
      }

      int receivedBytes = startByte;
      _fileSink = targetFile.openWrite(mode: openMode);

      final double initialProgress = totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

      _emit(_currentState.copyWith(
        status: ApkDownloadStatus.downloading,
        downloadedBytes: receivedBytes,
        totalBytes: totalBytes,
        progress: initialProgress,
        filePath: targetFile.path,
        errorMessage: null,
      ));

      int lastEmitTime = DateTime.now().millisecondsSinceEpoch;
      int bytesSinceLastEmit = 0;

      final completer = Completer<void>();

      _streamSubscription = response.listen(
        (chunk) {
          if (_isCanceled) {
            _streamSubscription?.cancel();
            return;
          }

          _fileSink?.add(chunk);
          receivedBytes += chunk.length;
          bytesSinceLastEmit += chunk.length;

          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastEmitTime >= 200 || receivedBytes == totalBytes) {
            final elapsedSec = (now - lastEmitTime) / 1000.0;
            final speed = elapsedSec > 0 ? (bytesSinceLastEmit / elapsedSec).toInt() : 0;
            final progress = totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

            _emit(_currentState.copyWith(
              downloadedBytes: receivedBytes,
              totalBytes: totalBytes,
              progress: progress,
              speedBytesPerSec: speed,
            ));

            lastEmitTime = now;
            bytesSinceLastEmit = 0;
          }
        },
        onError: (e) {
          if (!_isCanceled) {
            _emit(_currentState.copyWith(
              status: ApkDownloadStatus.error,
              errorMessage: 'انقطع الاتصال أثناء التحميل: $e',
            ));
            if (!completer.isCompleted) completer.completeError(e);
          }
        },
        onDone: () async {
          await _fileSink?.flush();
          await _fileSink?.close();
          _fileSink = null;
          client.close();

          if (!_isCanceled) {
            _emit(_currentState.copyWith(
              status: ApkDownloadStatus.completed,
              downloadedBytes: totalBytes > 0 ? totalBytes : receivedBytes,
              totalBytes: totalBytes > 0 ? totalBytes : receivedBytes,
              progress: 1.0,
              speedBytesPerSec: 0,
              filePath: targetFile.path,
            ));
            if (!completer.isCompleted) completer.complete();
          }
        },
        cancelOnError: true,
      );

      await completer.future;
    } catch (e) {
      await _fileSink?.flush();
      await _fileSink?.close();
      _fileSink = null;

      if (!_isCanceled) {
        String userFriendlyError = 'فشل في تحميل التحديث.';
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('socketexception') || errStr.contains('connection') || errStr.contains('timeout')) {
          userFriendlyError = 'انقطع الاتصال بالإنترنت. يمكنك استئناف التحميل عند عودة الاتصال.';
        } else {
          userFriendlyError = 'حدث خطأ: $e';
        }

        _emit(_currentState.copyWith(
          status: ApkDownloadStatus.error,
          errorMessage: userFriendlyError,
        ));
      }
    }
  }

  /// Cancels any active download and deletes the partially downloaded file if specified
  Future<void> cancelDownload({bool deletePartialFile = false}) async {
    _isCanceled = true;
    await _streamSubscription?.cancel();
    _streamSubscription = null;

    try {
      _activeRequest?.abort();
    } catch (_) {}
    _activeRequest = null;

    await _fileSink?.flush();
    await _fileSink?.close();
    _fileSink = null;

    if (deletePartialFile && _currentState.filePath != null) {
      try {
        final f = File(_currentState.filePath!);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }

    _emit(_currentState.copyWith(
      status: ApkDownloadStatus.idle,
      downloadedBytes: deletePartialFile ? 0 : _currentState.downloadedBytes,
      progress: deletePartialFile ? 0.0 : _currentState.progress,
      speedBytesPerSec: 0,
      errorMessage: null,
    ));
  }

  /// Pauses the download (keeps file on disk for resumption)
  Future<void> pauseDownload() async {
    _isCanceled = true;
    await _streamSubscription?.cancel();
    _streamSubscription = null;

    try {
      _activeRequest?.abort();
    } catch (_) {}
    _activeRequest = null;

    await _fileSink?.flush();
    await _fileSink?.close();
    _fileSink = null;

    _emit(_currentState.copyWith(
      status: ApkDownloadStatus.paused,
      speedBytesPerSec: 0,
    ));
  }

  /// Installs the completed APK with safety checks
  Future<bool> installApk() async {
    final path = _currentState.filePath;
    if (path == null || !File(path).existsSync()) {
      _emit(_currentState.copyWith(
        status: ApkDownloadStatus.error,
        errorMessage: 'ملف APK غير موجود. يرجى إعادة التحميل.',
      ));
      return false;
    }

    _emit(_currentState.copyWith(status: ApkDownloadStatus.installing));

    // 1. Verify APK
    final validation = await AndroidInstallerService.verifyApk(path);
    if (!validation.isValid) {
      _emit(_currentState.copyWith(
        status: ApkDownloadStatus.error,
        errorMessage: validation.error ?? 'ملف التحديث غير صالح أو لا يتطابق مع هذا التطبيق.',
      ));
      return false;
    }

    if (_expectedVersionCode != null && validation.versionCode != null) {
      if (validation.versionCode! < _expectedVersionCode!) {
        _emit(_currentState.copyWith(
          status: ApkDownloadStatus.error,
          errorMessage: 'إصدار حزمة التحديث (#${validation.versionCode}) أقل من الإصدار المطلوب (#$_expectedVersionCode).',
        ));
        return false;
      }
    }

    // 2. Launch native installer
    final installResult = await AndroidInstallerService.installApk(path);
    if (installResult['permissionRequired'] == true) {
      _emit(_currentState.copyWith(
        status: ApkDownloadStatus.permissionRequired,
        errorMessage: 'يلزم السماح بتثبيت التطبيقات من هذا المصدر في إعدادات الهاتف.',
      ));
      return false;
    }

    if (installResult['success'] == true) {
      _emit(_currentState.copyWith(status: ApkDownloadStatus.completed));
      return true;
    } else {
      _emit(_currentState.copyWith(
        status: ApkDownloadStatus.error,
        errorMessage: installResult['error'] ?? 'تعذر فتح مثبت الحزم.',
      ));
      return false;
    }
  }

  /// Resets state back to idle
  void reset() {
    _emit(const ApkDownloadState());
  }
}
