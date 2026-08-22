import 'package:flutter/material.dart';
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
        child: AlertDialog(
          backgroundColor: AppDesignTokens.surface(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusLg),
            side: BorderSide(
              color: info.isMandatory
                  ? AppDesignTokens.danger.withOpacity(0.3)
                  : AppDesignTokens.border(context),
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon and title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: info.isMandatory
                          ? AppDesignTokens.danger.withOpacity(0.12)
                          : AppDesignTokens.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                    ),
                    child: Icon(
                      info.isMandatory
                          ? Icons.warning_amber_rounded
                          : Icons.rocket_launch_rounded,
                      color: info.isMandatory
                          ? AppDesignTokens.danger
                          : AppDesignTokens.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.isMandatory ? 'تحديث إجباري مطلوب' : 'تحديث جديد متاح 🚀',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: info.isMandatory
                                ? AppDesignTokens.danger
                                : AppDesignTokens.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          info.isMandatory
                              ? 'يلزم التحديث للاستمرار في استخدام التطبيق'
                              : 'يتوفر إصدار جديد من منظومة امتياز مطروح',
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

              // Version Comparison Card
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
                  constraints: const BoxConstraints(maxHeight: 140),
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
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                if (!info.isMandatory) ...[
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
                      onPressed: () => Navigator.pop(ctx),
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
                  flex: info.isMandatory ? 1 : 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: info.isMandatory ? AppDesignTokens.danger : AppDesignTokens.primary,
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
                    onPressed: () {
                      if (!info.isMandatory) {
                        Navigator.pop(ctx);
                      }
                      AppUpdateService.launchApkDownload(context, info.downloadUrl);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
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
                style: TextStyle(
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
