import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_matrouh/core/services/android_installer_service.dart';
import 'package:nurse_matrouh/core/services/apk_download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApkDownloadService & Model Unit Tests', () {
    test('TEST 1: ApkDownloadState calculates progress and formats sizes accurately', () {
      const state = ApkDownloadState(
        status: ApkDownloadStatus.downloading,
        downloadedBytes: 43 * 1024 * 1024,
        totalBytes: 125 * 1024 * 1024,
        progress: 0.344,
        speedBytesPerSec: 2 * 1024 * 1024,
      );

      expect(state.formattedDownloaded, '43.0 MB');
      expect(state.formattedTotal, '125.0 MB');
      expect(state.percentage, 34);
      expect(state.status, ApkDownloadStatus.downloading);
      expect(state.supportsResume, isTrue);
    });

    test('TEST 2: ApkDownloadState zero and edge cases', () {
      const zeroState = ApkDownloadState(
        status: ApkDownloadStatus.idle,
        downloadedBytes: 0,
        totalBytes: 0,
        progress: 0.0,
      );

      expect(zeroState.formattedDownloaded, '0.0 MB');
      expect(zeroState.formattedTotal, '-- MB');
      expect(zeroState.percentage, 0);

      const completeState = ApkDownloadState(
        status: ApkDownloadStatus.completed,
        downloadedBytes: 150000000,
        totalBytes: 150000000,
        progress: 1.0,
      );

      expect(completeState.percentage, 100);
      expect(completeState.formattedDownloaded, '143.1 MB');
      expect(completeState.formattedTotal, '143.1 MB');
    });

    test('TEST 3: State copyWith preserves unchanged values', () {
      const initial = ApkDownloadState(
        status: ApkDownloadStatus.downloading,
        downloadedBytes: 500,
        totalBytes: 1000,
        progress: 0.5,
        filePath: '/data/user/0/app/test.apk',
      );

      final updated = initial.copyWith(
        status: ApkDownloadStatus.paused,
        speedBytesPerSec: 0,
      );

      expect(updated.status, ApkDownloadStatus.paused);
      expect(updated.downloadedBytes, 500);
      expect(updated.totalBytes, 1000);
      expect(updated.progress, 0.5);
      expect(updated.filePath, '/data/user/0/app/test.apk');
      expect(updated.speedBytesPerSec, 0);
    });
  });

  group('AndroidInstallerService & Validation Tests', () {
    const MethodChannel channel = MethodChannel('com.matrouh.nurse/app_installer');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'canRequestPackageInstalls':
            return true;
          case 'openInstallPermissionSettings':
            return true;
          case 'getDownloadDirectory':
            return '/storage/emulated/0/Android/data/com.matrouh.nurse.nurse_matrouh/files/Download';
          case 'verifyApk':
            final path = methodCall.arguments['filePath'] as String;
            if (path.contains('corrupted')) {
              return {
                'isValid': false,
                'error': 'Failed to parse APK archive metadata',
              };
            }
            if (path.contains('wrong_package')) {
              return {
                'isValid': false,
                'packageName': 'com.other.app',
                'expectedPackageName': 'com.matrouh.nurse.nurse_matrouh',
                'versionCode': 10,
                'versionName': '1.0.0',
                'error': 'Package name (com.other.app) does not match expected',
              };
            }
            return {
              'isValid': true,
              'packageName': 'com.matrouh.nurse.nurse_matrouh',
              'expectedPackageName': 'com.matrouh.nurse.nurse_matrouh',
              'versionCode': 3,
              'versionName': '1.2.0',
              'fileSizeBytes': 25000000,
              'error': null,
            };
          case 'installApk':
            final path = methodCall.arguments['filePath'] as String;
            if (path.contains('no_permission')) {
              return {
                'success': false,
                'permissionRequired': true,
                'error': 'Permission REQUEST_INSTALL_PACKAGES not granted',
              };
            }
            return {
              'success': true,
              'permissionRequired': false,
            };
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('TEST 4: ApkValidationResult correctly identifies matching APK', () {
      final validMap = {
        'isValid': true,
        'packageName': 'com.matrouh.nurse.nurse_matrouh',
        'expectedPackageName': 'com.matrouh.nurse.nurse_matrouh',
        'versionCode': 5,
        'versionName': '1.3.0',
        'fileSizeBytes': 125000000,
        'error': null,
      };

      final result = ApkValidationResult.fromMap(validMap);
      expect(result.isValid, isTrue);
      expect(result.packageName, 'com.matrouh.nurse.nurse_matrouh');
      expect(result.versionCode, 5);
      expect(result.versionName, '1.3.0');
      expect(result.fileSizeBytes, 125000000);
      expect(result.error, isNull);
    });

    test('TEST 5: ApkValidationResult flags mismatched package names as invalid', () {
      final invalidMap = {
        'isValid': false,
        'packageName': 'com.malicious.fake',
        'expectedPackageName': 'com.matrouh.nurse.nurse_matrouh',
        'versionCode': 99,
        'versionName': '9.9.9',
        'error': 'Package name does not match',
      };

      final result = ApkValidationResult.fromMap(invalidMap);
      expect(result.isValid, isFalse);
      expect(result.packageName, 'com.malicious.fake');
      expect(result.error, contains('does not match'));
    });
  });
}
