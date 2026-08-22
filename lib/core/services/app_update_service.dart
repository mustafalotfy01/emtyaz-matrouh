import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_version_model.dart';
import 'supabase_service.dart';

@immutable
class AppVersionInfo {
  final String currentVersion;
  final int currentVersionCode;
  final String latestVersion;
  final int latestVersionCode;
  final String releaseNotes;
  final String? downloadUrl;
  final bool isMandatory;
  final bool hasUpdate;
  final DateTime? releaseDate;
  final int? fileSize;

  const AppVersionInfo({
    required this.currentVersion,
    required this.currentVersionCode,
    required this.latestVersion,
    required this.latestVersionCode,
    required this.releaseNotes,
    this.downloadUrl,
    this.isMandatory = false,
    required this.hasUpdate,
    this.releaseDate,
    this.fileSize,
  });

  String get formattedFileSize {
    if (fileSize == null || fileSize! <= 0) return '';
    final mb = fileSize! / (1024 * 1024);
    if (mb >= 1) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final kb = fileSize! / 1024;
    return '${kb.toStringAsFixed(0)} KB';
  }
}

class AppUpdateService {
  AppUpdateService._();

  /// Checks if current runtime platform is Android OS (Excludes Web, iOS, macOS, Windows, Linux).
  static bool get isAndroidPlatform {
    if (kIsWeb) return false;
    try {
      return defaultTargetPlatform == TargetPlatform.android;
    } catch (_) {
      return false;
    }
  }

  /// Checks for available production updates from Supabase app_versions table.
  /// Strictly checks Android platform and compares versionCode.
  static Future<AppVersionInfo> checkForUpdates({bool isManualCheck = false}) async {
    // 1. Web and non-Android platforms NEVER show APK updates
    if (!isAndroidPlatform) {
      return const AppVersionInfo(
        currentVersion: '1.0.0',
        currentVersionCode: 1,
        latestVersion: '1.0.0',
        latestVersionCode: 1,
        releaseNotes: '',
        isMandatory: false,
        hasUpdate: false,
      );
    }

    // 2. Read installed package info
    String installedVersion = '1.0.0';
    int installedCode = 1;

    try {
      final pkg = await PackageInfo.fromPlatform();
      installedVersion = pkg.version.isNotEmpty ? pkg.version : '1.0.0';
      installedCode = int.tryParse(pkg.buildNumber) ?? 1;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ AppUpdateService: PackageInfo lookup fallback: ');
      }
    }

    // 3. Query remote active Android version from Supabase
    try {
      final response = await SupabaseService.client
          .from('app_versions')
          .select('*')
          .eq('is_active', true)
          .order('version_code', ascending: false)
          .limit(1);

      final List data = response as List? ?? [];
      if (data.isEmpty) {
        return AppVersionInfo(
          currentVersion: installedVersion,
          currentVersionCode: installedCode,
          latestVersion: installedVersion,
          latestVersionCode: installedCode,
          releaseNotes: 'أنت تستخدم أحدث إصدار مستقر من منظومة تمريض مطروح.',
          hasUpdate: false,
          isMandatory: false,
        );
      }

      final latest = AppVersionModel.fromJson(Map<String, dynamic>.from(data.first));
      final hasUpdate = latest.versionCode > installedCode;
      final isMandatory = latest.forceUpdate || (installedCode < latest.minimumSupportedVersion);

      return AppVersionInfo(
        currentVersion: installedVersion,
        currentVersionCode: installedCode,
        latestVersion: latest.versionName,
        latestVersionCode: latest.versionCode,
        releaseNotes: latest.releaseNotes ?? '• تحسينات شاملة في الأداء وتجربة المستخدم.',
        downloadUrl: latest.apkDownloadUrl,
        isMandatory: isMandatory,
        hasUpdate: hasUpdate,
        releaseDate: latest.releaseDate,
        fileSize: latest.fileSize,
      );
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ AppUpdateService: Version check network error (graceful ignore): ');
      }
      // Never block app startup on network / server failure
      return AppVersionInfo(
        currentVersion: installedVersion,
        currentVersionCode: installedCode,
        latestVersion: installedVersion,
        latestVersionCode: installedCode,
        releaseNotes: '',
        hasUpdate: false,
        isMandatory: false,
      );
    }
  }

  /// Launches APK download URL via Android OS external downloader/browser
  static Future<bool> launchApkDownload(BuildContext context, String? url) async {
    if (url == null || url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ رابط تحميل الإصدار غير متوفر حالياً'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return false;
    }

    final uri = Uri.tryParse(url.trim());
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ رابط تحميل ملف APK غير صالح'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return false;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚀 جارٍ فتح رابط تحميل التحديث الرسمي...'),
          backgroundColor: Color(0xFF0A7B83),
          duration: Duration(seconds: 3),
        ),
      );

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ تعذر فتح رابط التحميل، يرجى المحاولة مرة أخرى'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return launched;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ حدث خطأ أثناء فتح رابط التحديث: '),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return false;
    }
  }
}
