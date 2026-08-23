import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@immutable
class ApkValidationResult {
  final bool isValid;
  final String? packageName;
  final String? expectedPackageName;
  final int? versionCode;
  final String? versionName;
  final int? fileSizeBytes;
  final String? error;

  const ApkValidationResult({
    required this.isValid,
    this.packageName,
    this.expectedPackageName,
    this.versionCode,
    this.versionName,
    this.fileSizeBytes,
    this.error,
  });

  factory ApkValidationResult.fromMap(Map<dynamic, dynamic> map) {
    return ApkValidationResult(
      isValid: map['isValid'] == true,
      packageName: map['packageName'] as String?,
      expectedPackageName: map['expectedPackageName'] as String?,
      versionCode: (map['versionCode'] as num?)?.toInt(),
      versionName: map['versionName'] as String?,
      fileSizeBytes: (map['fileSizeBytes'] as num?)?.toInt(),
      error: map['error'] as String?,
    );
  }
}

class AndroidInstallerService {
  AndroidInstallerService._();

  static const MethodChannel _channel = MethodChannel('com.matrouh.nurse/app_installer');

  /// Checks if the app is currently running on native Android OS
  static bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Checks if unknown apps install permission is granted (Android 8.0+)
  static Future<bool> canRequestPackageInstalls() async {
    if (!isAndroid) return false;
    try {
      final bool? result = await _channel.invokeMethod<bool>('canRequestPackageInstalls');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) print('⚠️ AndroidInstallerService: canRequestPackageInstalls failed: $e');
      return true; // Fallback to allowing attempt
    }
  }

  /// Opens the system Settings page for "Install unknown apps" for this package
  static Future<bool> openInstallPermissionSettings() async {
    if (!isAndroid) return false;
    try {
      final bool? result = await _channel.invokeMethod<bool>('openInstallPermissionSettings');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) print('⚠️ AndroidInstallerService: openInstallPermissionSettings failed: $e');
      return false;
    }
  }

  /// Retrieves the absolute path to app-specific downloads directory
  static Future<String?> getDownloadDirectory() async {
    if (!isAndroid) return null;
    try {
      final String? path = await _channel.invokeMethod<String>('getDownloadDirectory');
      return path;
    } catch (e) {
      if (kDebugMode) print('⚠️ AndroidInstallerService: getDownloadDirectory failed: $e');
      return null;
    }
  }

  /// Verifies that the APK is valid, readable, and matches this application's package name
  static Future<ApkValidationResult> verifyApk(String filePath) async {
    if (!isAndroid) {
      return const ApkValidationResult(
        isValid: false,
        error: 'APK verification is only supported on Android devices.',
      );
    }

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('verifyApk', {
        'filePath': filePath,
      });

      if (result == null) {
        return const ApkValidationResult(
          isValid: false,
          error: 'Native APK verification returned null response.',
        );
      }

      return ApkValidationResult.fromMap(result);
    } catch (e) {
      return ApkValidationResult(
        isValid: false,
        error: 'Error validating APK: $e',
      );
    }
  }

  /// Launches the native Android Package Installer for the specified APK file using FileProvider
  static Future<Map<String, dynamic>> installApk(String filePath) async {
    if (!isAndroid) {
      return {
        'success': false,
        'permissionRequired': false,
        'error': 'Installation is only supported on Android devices.',
      };
    }

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('installApk', {
        'filePath': filePath,
      });

      return {
        'success': result?['success'] == true,
        'permissionRequired': result?['permissionRequired'] == true,
        'error': result?['error'] as String?,
      };
    } catch (e) {
      return {
        'success': false,
        'permissionRequired': false,
        'error': 'Exception launching installer: $e',
      };
    }
  }
}
