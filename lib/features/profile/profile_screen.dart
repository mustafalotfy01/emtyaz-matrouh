import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/services/firebase_messaging_service.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/ios/app_card.dart';
import '../../core/widgets/ios/app_section_header.dart';
import '../../core/widgets/ios/language_segmented_control.dart';
import '../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final currentThemeMode = ref.watch(themeModeProvider);
    final currentLocale = ref.watch(localeProvider);
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Text(l10n.profileAndSettingsTitle),
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: AppLanguageSegmentedControl(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. User Header ─────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primaryTeal, width: 2),
                      ),
                      child: const Icon(Icons.person_rounded, size: 44, color: AppColors.primaryTeal),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      user?.fullName.isNotEmpty == true ? user!.fullName : 'أحمد محمود العبد',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.role.displayNameAr ?? l10n.roleStudent,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.primaryTeal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.muted(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${l10n.universityCodeLabel} ${user?.universityCode ?? "NUR-2026-081"}',
                        style: TextStyle(fontSize: 11, color: AppColors.subtext(context), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── 2. Appearance Section (Light / Dark / System) ──────────────
              AppSectionHeader(title: l10n.appearanceSection),
              const SizedBox(height: 6),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: Column(
                  children: [
                    _buildThemeRadioRow(
                      context,
                      title: l10n.themeSystem,
                      icon: Icons.brightness_auto_rounded,
                      isSelected: currentThemeMode == ThemeMode.system,
                      onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system),
                    ),
                    Divider(height: 1, color: AppColors.border(context)),
                    _buildThemeRadioRow(
                      context,
                      title: l10n.themeLight,
                      icon: Icons.light_mode_rounded,
                      isSelected: currentThemeMode == ThemeMode.light,
                      onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light),
                    ),
                    Divider(height: 1, color: AppColors.border(context)),
                    _buildThemeRadioRow(
                      context,
                      title: l10n.themeDark,
                      icon: Icons.dark_mode_rounded,
                      isSelected: currentThemeMode == ThemeMode.dark,
                      onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── 3. Language Section ────────────────────────────────────────
              AppSectionHeader(title: l10n.languageSection),
              const SizedBox(height: 6),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: Column(
                  children: [
                    _buildLanguageRow(
                      context,
                      title: 'العربية (Arabic)',
                      isSelected: currentLocale.languageCode == 'ar',
                      onTap: () => ref.read(localeProvider.notifier).setLocale(const Locale('ar', 'EG')),
                    ),
                    Divider(height: 1, color: AppColors.border(context)),
                    _buildLanguageRow(
                      context,
                      title: 'English',
                      isSelected: currentLocale.languageCode == 'en',
                      onTap: () => ref.read(localeProvider.notifier).setLocale(const Locale('en', 'US')),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── 4. Student Official Data ───────────────────────────────────
              AppSectionHeader(title: l10n.accountSection),
              const SizedBox(height: 6),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Column(
                  children: [
                    _buildInfoRow(context, Icons.email_outlined, l10n.emailLabel, user?.email ?? 'student1@nurse.edu.eg'),
                    Divider(height: 12, color: AppColors.border(context)),
                    _buildInfoRow(context, Icons.phone_outlined, l10n.phoneLabel, user?.phoneNumber ?? '01012345678'),
                    if (user?.gpa != null) ...[
                      Divider(height: 12, color: AppColors.border(context)),
                      _buildInfoRow(context, Icons.school_outlined, 'المعدل التراكمي (GPA)', user!.gpa!.toStringAsFixed(2)),
                    ],
                    if (user?.nationalId != null && user!.nationalId!.isNotEmpty) ...[
                      Divider(height: 12, color: AppColors.border(context)),
                      _buildInfoRow(context, Icons.credit_card_outlined, l10n.nationalIdLabel, user!.nationalId!),
                    ],
                    Divider(height: 12, color: AppColors.border(context)),
                    _buildInfoRow(context, Icons.home_outlined, l10n.residenceLabel, user?.isMatrouhResident == true ? l10n.residentMatrouh : l10n.residentExpatriate),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── 5. Push Notifications & PWA Settings ───────────────────────
              AppSectionHeader(title: l10n.isArabic ? 'الإشعارات والتنبيهات الفورية' : 'Push Notifications'),
              const SizedBox(height: 6),
              AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTeal.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.notifications_active_outlined, color: AppColors.primaryTeal, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.isArabic ? 'إشعارات الروستر والتدريب' : 'Shift & Roster Push Alerts',
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                              ),
                              Text(
                                PushNotificationService.instance.getPermissionStatus() == PushPermissionStatus.granted
                                    ? (l10n.isArabic ? '✓ الإشعارات مفعلة على هذا الجهاز' : '✓ Notifications enabled on this device')
                                    : (l10n.isArabic ? '⚠ الإشعارات غير مفعلة حالياً' : '⚠ Notifications currently disabled'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: PushNotificationService.instance.getPermissionStatus() == PushPermissionStatus.granted
                                      ? AppColors.success
                                      : AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    if (PushNotificationService.instance.isIosSafariNonStandalone()) ...[
                      // iPhone PWA Home Screen Guide Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.muted(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.phone_iphone, color: AppColors.primaryTeal, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  l10n.isArabic ? 'دليل تفعيل الإشعارات على iPhone / iPad:' : 'Enable Notifications on iPhone / iPad:',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.isArabic
                                  ? '1. اضغط زر المشاركة (Share) 📤\n2. اختر إضافة إلى الشاشة الرئيسية (Add to Home Screen) 📲\n3. افتح التطبيق من الشاشة الرئيسية\n4. اضغط تفعيل الإشعارات'
                                  : '1. Tap the Share button 📤\n2. Select "Add to Home Screen" 📲\n3. Open app from your Home Screen\n4. Tap Enable Notifications',
                              style: TextStyle(fontSize: 11.5, height: 1.5, color: AppColors.subtext(context)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PushNotificationService.instance.getPermissionStatus() == PushPermissionStatus.granted
                              ? AppColors.muted(context)
                              : AppColors.primaryTeal,
                          foregroundColor: PushNotificationService.instance.getPermissionStatus() == PushPermissionStatus.granted
                              ? AppColors.text(context)
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.notification_add, size: 16),
                        label: Text(
                          PushNotificationService.instance.getPermissionStatus() == PushPermissionStatus.granted
                              ? (l10n.isArabic ? 'إرسال إشعار تجريبي للجهاز 🔔' : 'Send Test Notification 🔔')
                              : (l10n.isArabic ? 'تفعيل الإشعارات وتوليد رمز FCM 🔔' : 'Enable FCM Notifications 🔔'),
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          if (PushNotificationService.instance.getPermissionStatus() != PushPermissionStatus.granted) {
                            await PushNotificationService.instance.requestPermission();
                            await FirebaseMessagingService.instance.requestPermission();
                            await FirebaseMessagingService.instance.retrieveToken();
                            if (mounted) setState(() {});
                          } else {
                            // Show test browser notification
                            await PushNotificationService.instance.showBrowserNotification(
                              title: 'امتياز مطروح (FCM)',
                              body: 'تم اختبار الإشعارات الفورية بنجاح على جهازك! 🎉',
                              route: '/notifications',
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.success,
                                  content: Text(l10n.isArabic ? 'تم إرسال إشعار تجريبي بنجاح ✅' : 'Test notification sent ✅'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Diagnostics Screen Link
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: BorderSide(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.build_circle_outlined, size: 16, color: AppColors.primaryTeal),
                        label: Text(
                          l10n.isArabic ? 'تشخيص إشعارات FCM والتسجيل 🛠️' : 'FCM Diagnostics & Token 🛠️',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.primaryTeal, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () {
                          context.push('/fcm-debug');
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── 6. Security & Biometrics ───────────────────────────────────
              AppSectionHeader(title: l10n.securitySection),
              const SizedBox(height: 6),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: SwitchListTile(
                  title: Text(
                    l10n.enableBiometrics,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                  ),
                  subtitle: Text(
                    l10n.enableBiometricsSub,
                    style: TextStyle(fontSize: 11, color: AppColors.subtext(context)),
                  ),
                  value: authState.isBiometricEnabled,
                  activeColor: AppColors.primaryTeal,
                  onChanged: (val) {
                    ref.read(authProvider.notifier).toggleBiometrics(val);
                  },
                ),
              ),

              const SizedBox(height: 20),

              // ── 6. About App ───────────────────────────────────────────────
              AppSectionHeader(title: l10n.aboutSection),
              const SizedBox(height: 6),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: Column(
                  children: [
                    _buildNavRow(context, Icons.info_outline_rounded, l10n.appVersionLabel, l10n.appVersionValue),
                    Divider(height: 8, color: AppColors.border(context)),
                    _buildNavRow(context, Icons.privacy_tip_outlined, l10n.privacyPolicy, null),
                    Divider(height: 8, color: AppColors.border(context)),
                    _buildNavRow(context, Icons.description_outlined, l10n.termsOfService, null),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── 7. Logout Button ───────────────────────────────────────────
              Center(
                child: TextButton.icon(
                  onPressed: () => _confirmLogout(context, ref, l10n),
                  icon: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 18),
                  label: Text(
                    l10n.logoutBtn,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeRadioRow(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? AppColors.primaryTeal : AppColors.subtext(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.primaryTeal : AppColors.text(context),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_rounded, color: AppColors.primaryTeal, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageRow(
    BuildContext context, {
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(Icons.language_rounded, size: 20, color: isSelected ? AppColors.primaryTeal : AppColors.subtext(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.primaryTeal : AppColors.text(context),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_rounded, color: AppColors.primaryTeal, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryTeal),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.subtext(context)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.text(context)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavRow(BuildContext context, IconData icon, String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.subtext(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 13, color: AppColors.text(context), fontWeight: FontWeight.w500),
            ),
          ),
          if (value != null)
            Text(value, style: TextStyle(fontSize: 11, color: AppColors.subtext(context)))
          else
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textMuted),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.logoutConfirmTitle),
        content: Text(l10n.logoutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: Text(l10n.logoutBtn),
          ),
        ],
      ),
    );
  }
}
