import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/android_installer_service.dart';
import '../../../core/services/apk_download_service.dart';
import '../../../core/services/app_update_service.dart';
import '../../../core/theme/app_design_tokens.dart';

class AppUpdateModal {
  /// Displays update dialog when an update is available (used for automatic startup checks)
  static void showUpdateDialog(BuildContext context, AppVersionInfo info) {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: !info.isMandatory,
      builder: (ctx) => PopScope(
        canPop: !info.isMandatory,
        child: _AppUpdateDialogContent(info: info),
      ),
    );
  }

  /// Triggered manually from Settings/Profile screen to check for updates
  static Future<void> showUpdateCheck(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppDesignTokens.surface(context),
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppDesignTokens.primary),
              const SizedBox(height: 14),
              Text(
                'جارٍ فحص التحديثات الرسمية...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppDesignTokens.textPrimary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final info = await AppUpdateService.checkForUpdates(isManualCheck: true);
    if (!context.mounted) return;
    Navigator.pop(context); // Close loading

    if (info.hasUpdate) {
      showUpdateDialog(context, info);
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppDesignTokens.surface(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusLg),
            side: BorderSide(color: AppDesignTokens.border(context)),
          ),
          title: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: AppDesignTokens.success, size: 24),
              const SizedBox(width: 10),
              Text(
                'التطبيق محدّث بالكامل',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppDesignTokens.textPrimary(context),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الإصدار الحالي: v${info.currentVersion} (Build #${info.currentVersionCode})',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppDesignTokens.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'أنت تستخدم أحدث نسخة رسمية مستقرة من تطبيق امتياز مطروح للتمريض.',
                style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context), height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق', style: TextStyle(color: AppDesignTokens.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }
}

class _AppUpdateDialogContent extends StatefulWidget {
  final AppVersionInfo info;

  const _AppUpdateDialogContent({required this.info});

  @override
  State<_AppUpdateDialogContent> createState() => _AppUpdateDialogContentState();
}

class _AppUpdateDialogContentState extends State<_AppUpdateDialogContent> {
  StreamSubscription<ApkDownloadState>? _sub;
  ApkDownloadState _downloadState = const ApkDownloadState();
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    _downloadState = ApkDownloadService.instance.currentState;
    if (_downloadState.status == ApkDownloadStatus.downloading ||
        _downloadState.status == ApkDownloadStatus.completed) {
      _hasStarted = true;
    }

    _sub = ApkDownloadService.instance.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _downloadState = state;
          if (state.status != ApkDownloadStatus.idle) {
            _hasStarted = true;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _startOrResumeDownload() {
    setState(() => _hasStarted = true);
    AppUpdateService.startInAppDownload(widget.info);
  }

  void _cancelDownload() {
    ApkDownloadService.instance.cancelDownload(deletePartialFile: false);
    setState(() => _hasStarted = false);
  }

  void _installNow() {
    ApkDownloadService.instance.installApk();
  }

  void _openSettings() {
    AndroidInstallerService.openInstallPermissionSettings();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final isMandatory = info.isMandatory;
    final status = _downloadState.status;

    return AlertDialog(
      backgroundColor: AppDesignTokens.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusLg),
        side: BorderSide(
          color: isMandatory
              ? AppDesignTokens.danger.withOpacity(0.3)
              : AppDesignTokens.border(context),
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Icon & Title ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isMandatory
                      ? AppDesignTokens.danger.withOpacity(0.12)
                      : (status == ApkDownloadStatus.completed
                          ? AppDesignTokens.success.withOpacity(0.12)
                          : AppDesignTokens.primary.withOpacity(0.12)),
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                ),
                child: Icon(
                  isMandatory
                      ? Icons.warning_amber_rounded
                      : (status == ApkDownloadStatus.completed
                          ? Icons.check_circle_outline_rounded
                          : (status == ApkDownloadStatus.downloading
                              ? Icons.downloading_rounded
                              : Icons.rocket_launch_rounded)),
                  color: isMandatory
                      ? AppDesignTokens.danger
                      : (status == ApkDownloadStatus.completed
                          ? AppDesignTokens.success
                          : AppDesignTokens.primary),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getHeaderTitle(status, isMandatory),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isMandatory && status != ApkDownloadStatus.completed
                            ? AppDesignTokens.danger
                            : AppDesignTokens.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getHeaderSubtitle(status, isMandatory),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppDesignTokens.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Version Comparison Card ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppDesignTokens.bg(context),
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
              border: Border.all(color: AppDesignTokens.border(context)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الإصدار المثبت',
                      style: TextStyle(fontSize: 10.5, color: AppDesignTokens.textSecondary(context)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'v${info.currentVersion} (#${info.currentVersionCode})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppDesignTokens.textPrimary(context),
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.arrow_forward_rounded, size: 20, color: AppDesignTokens.primary),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'الإصدار الجديد',
                      style: TextStyle(fontSize: 10.5, color: AppDesignTokens.textSecondary(context)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'v${info.latestVersion} (#${info.latestVersionCode})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppDesignTokens.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Release Notes or Progress Bar ──
          if (!_hasStarted || status == ApkDownloadStatus.idle) ...[
            if (info.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'أهم التحديثات في هذا الإصدار:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppDesignTokens.textPrimary(context),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppDesignTokens.bg(context),
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    info.releaseNotes,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppDesignTokens.textSecondary(context),
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ],
            if (info.fileSize != null && info.fileSize! > 0) ...[
              const SizedBox(height: 8),
              Text(
                'حجم التحديث: ${info.formattedFileSize}',
                style: TextStyle(fontSize: 11, color: AppDesignTokens.textMuted(context)),
              ),
            ],
          ] else ...[
            // ── Download Progress UI ──
            const SizedBox(height: 16),
            if (status == ApkDownloadStatus.checking) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(color: AppDesignTokens.primary),
                ),
              ),
            ] else if (status == ApkDownloadStatus.downloading ||
                status == ApkDownloadStatus.paused ||
                status == ApkDownloadStatus.completed ||
                status == ApkDownloadStatus.installing) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_downloadState.formattedDownloaded} / ${_downloadState.formattedTotal}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppDesignTokens.textPrimary(context),
                    ),
                  ),
                  Text(
                    '${_downloadState.percentage}%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppDesignTokens.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _downloadState.progress > 0 ? _downloadState.progress : null,
                  minHeight: 10,
                  backgroundColor: AppDesignTokens.primary.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    status == ApkDownloadStatus.completed
                        ? AppDesignTokens.success
                        : AppDesignTokens.primary,
                  ),
                ),
              ),
            ],

            if (status == ApkDownloadStatus.error) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppDesignTokens.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                  border: Border.all(color: AppDesignTokens.danger.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppDesignTokens.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _downloadState.errorMessage ?? 'حدث خطأ أثناء تحميل التحديث.',
                        style: const TextStyle(fontSize: 11, color: AppDesignTokens.danger),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (status == ApkDownloadStatus.permissionRequired) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                  border: Border.all(color: Colors.orange.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security_rounded, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'يحتاج الهاتف إلى السماح بتثبيت التطبيقات من هذا المصدر.',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: _buildActions(context, status, isMandatory),
    );
  }

  String _getHeaderTitle(ApkDownloadStatus status, bool isMandatory) {
    if (status == ApkDownloadStatus.downloading) return 'جاري تحميل التحديث...';
    if (status == ApkDownloadStatus.completed) return 'تم اكتمال التحميل 🎉';
    if (status == ApkDownloadStatus.installing) return 'جاري بدء التثبيت...';
    if (status == ApkDownloadStatus.permissionRequired) return 'إذن التثبيت مطلوب ⚙️';
    if (status == ApkDownloadStatus.error) return 'انقطع التحميل';
    if (isMandatory) return 'تحديث إجباري مطلوب';
    return 'تحديث جديد متاح 🚀';
  }

  String _getHeaderSubtitle(ApkDownloadStatus status, bool isMandatory) {
    if (status == ApkDownloadStatus.downloading) return 'يتم حفظ حزمة APK داخل التطبيق';
    if (status == ApkDownloadStatus.completed) return 'اضغط أدناه لتثبيت التحديث مباشرة';
    if (status == ApkDownloadStatus.installing) return 'جارٍ فتح مثبت حزم Android';
    if (status == ApkDownloadStatus.permissionRequired) return 'اضغط على زر فتح الإعدادات لتفعيل التثبيت';
    if (status == ApkDownloadStatus.error) return 'اضغط على إعادة المحاولة لاستكمال التحميل';
    if (isMandatory) return 'يلزم التحديث للاستمرار في استخدام التطبيق';
    return 'يتوفر إصدار جديد من منظومة امتياز مطروح';
  }

  List<Widget> _buildActions(BuildContext context, ApkDownloadStatus status, bool isMandatory) {
    if (!_hasStarted || status == ApkDownloadStatus.idle) {
      return [
        Row(
          children: [
            if (!isMandatory) ...[
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppDesignTokens.border(context)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'لاحقاً',
                    style: TextStyle(
                      color: AppDesignTokens.textSecondary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: isMandatory ? 1 : 2,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isMandatory ? AppDesignTokens.danger : AppDesignTokens.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.file_download_rounded, color: Colors.white, size: 18),
                label: const Text(
                  'تحديث الآن',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                onPressed: _startOrResumeDownload,
              ),
            ),
          ],
        ),
      ];
    }

    if (status == ApkDownloadStatus.downloading || status == ApkDownloadStatus.checking) {
      return [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppDesignTokens.danger),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _cancelDownload,
                child: const Text(
                  'إلغاء التحميل',
                  style: TextStyle(color: AppDesignTokens.danger, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ];
    }

    if (status == ApkDownloadStatus.error || status == ApkDownloadStatus.paused) {
      return [
        Row(
          children: [
            if (!isMandatory) ...[
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إغلاق'),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignTokens.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                label: const Text(
                  'إعادة المحاولة / استكمال',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onPressed: _startOrResumeDownload,
              ),
            ),
          ],
        ),
      ];
    }

    if (status == ApkDownloadStatus.permissionRequired) {
      return [
        Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('الإعدادات', style: TextStyle(fontSize: 12)),
                onPressed: _openSettings,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignTokens.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.system_update_rounded, color: Colors.white, size: 18),
                label: const Text('تثبيت الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: _installNow,
              ),
            ),
          ],
        ),
      ];
    }

    if (status == ApkDownloadStatus.completed || status == ApkDownloadStatus.installing) {
      return [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignTokens.success,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                icon: const Icon(Icons.system_update_rounded, color: Colors.white, size: 20),
                label: const Text(
                  'تثبيت التحديث الآن 🚀',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: _installNow,
              ),
            ),
          ],
        ),
      ];
    }

    return [];
  }
}
