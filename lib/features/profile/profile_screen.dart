import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/media_picker_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/services/firebase_messaging_service.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/theme/app_design_tokens.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_input.dart';
import '../../core/widgets/app_section_header.dart';
import '../../core/widgets/ios/language_segmented_control.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/services/app_update_service.dart';
import 'widgets/app_update_dialog.dart';
import '../auth/models/user_profile.dart';
import '../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _installedVersion = '1.2.1';
  String _installedBuildNumber = '3';
  AppVersionInfo? _availableUpdate;

  @override
  void initState() {
    super.initState();
    _loadVersionAndCheckUpdates();
  }

  Future<void> _loadVersionAndCheckUpdates() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          if (pkg.version.isNotEmpty) _installedVersion = pkg.version;
          if (pkg.buildNumber.isNotEmpty) _installedBuildNumber = pkg.buildNumber;
        });
      }
    } catch (_) {}

    try {
      final info = await AppUpdateService.checkForUpdates();
      if (mounted) {
        setState(() {
          _availableUpdate = info;
        });
      }
    } catch (_) {}
  }

  void _openEditProfileDialog(BuildContext context, UserProfile user) {
    final nameController = TextEditingController(text: user.fullName);
    final phoneController = TextEditingController(text: user.phoneNumber);
    final emergencyController = TextEditingController(text: user.emergencyContact);
    final addressController = TextEditingController(text: user.residenceAddress);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: AppDesignTokens.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AppDesignTokens.border(context)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'تعديل البيانات الشخصية',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppDesignTokens.textPrimary(context),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Centered Avatar Preview with Camera / Gallery Action
              Center(
                child: Column(
                  children: [
                    AppAvatar(
                      name: user.fullName,
                      imageUrl: user.avatarUrl,
                      size: AppAvatarSize.large,
                      onEditTap: () {
                        Navigator.pop(ctx);
                        _openAvatarActionsModal(context, user);
                      },
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openAvatarActionsModal(context, user);
                      },
                      icon: const Icon(Icons.photo_camera_rounded, size: 16),
                      label: const Text('تغيير الصورة الشخصية (كاميرا / معرض)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppInput(
                label: 'الاسم الكامل',
                controller: nameController,
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
              ),
              const SizedBox(height: 12),
              AppInput(
                label: 'رقم الهاتف',
                controller: phoneController,
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(Icons.phone_outlined, size: 18),
              ),
              const SizedBox(height: 12),
              AppInput(
                label: 'رقم طوارئ للتواصل',
                controller: emergencyController,
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(Icons.contact_phone_outlined, size: 18),
              ),
              const SizedBox(height: 12),
              AppInput(
                label: 'عنوان السكن في مطروح',
                controller: addressController,
                prefixIcon: const Icon(Icons.home_outlined, size: 18),
              ),
              const SizedBox(height: 14),
              AppButton(
                text: 'تغيير كلمة المرور 🔑',
                icon: Icons.lock_reset_rounded,
                variant: AppButtonVariant.outline,
                width: double.infinity,
                onPressed: () {
                  Navigator.pop(ctx);
                  _openChangePasswordDialog(context);
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: 'إلغاء',
                      variant: AppButtonVariant.ghost,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      text: 'حفظ التعديلات',
                      variant: AppButtonVariant.primary,
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final ok = await ref.read(authProvider.notifier).updateProfile(
                          fullName: nameController.text,
                          phoneNumber: phoneController.text,
                          emergencyContact: emergencyController.text,
                          residenceAddress: addressController.text,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: ok ? AppDesignTokens.success : AppDesignTokens.danger,
                              content: Text(ok ? 'تم تحديث البيانات بنجاح ✅' : 'فشل تحديث البيانات ❌'),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage({bool fromCamera = false}) async {
    try {
      final picked = await MediaPickerService.instance.pickImage(fromCamera: fromCamera);

      if (picked != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('جارٍ رفع الصورة الشخصية وتحديث البروفايل...'),
              duration: Duration(seconds: 1),
            ),
          );
        }

        final uploadedUrl = await ref
            .read(authProvider.notifier)
            .uploadAvatarBytes(picked.bytes, picked.extension);

        if (mounted) {
          if (uploadedUrl != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppDesignTokens.success,
                content: Text('تم تحديث الصورة الشخصية بنجاح وستظهر في الليدربورد والبروفايل ✅'),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppDesignTokens.danger,
                content: Text('تعذر رفع الصورة، يرجى المحاولة لاحقاً ❌'),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppDesignTokens.danger,
            content: Text('خطأ أثناء اختيار الصورة: $e'),
          ),
        );
      }
    }
  }

  void _openAvatarActionsModal(BuildContext context, UserProfile user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppDesignTokens.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AppDesignTokens.border(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'الصورة الشخصية',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppDesignTokens.textPrimary(context),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppDesignTokens.primary),
              title: const Text('اختيار صورة من المعرض (Gallery) 🖼️', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(fromCamera: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppDesignTokens.primary),
              title: const Text('التقاط صورة بالكاميرا (Camera) 📷', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(fromCamera: true);
              },
            ),
            if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppDesignTokens.danger),
                title: const Text('حذف الصورة الحالية', style: TextStyle(color: AppDesignTokens.danger, fontWeight: FontWeight.w600, fontSize: 13.5)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(authProvider.notifier).deleteAvatar();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppDesignTokens.success,
                        content: Text('تم حذف الصورة الشخصية بنجاح ✅'),
                      ),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _openChangePasswordDialog(BuildContext context) {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;
    String? localError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: AppDesignTokens.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: AppDesignTokens.border(context)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppDesignTokens.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lock_reset_rounded, color: AppDesignTokens.primary, size: 20),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'تغيير كلمة المرور',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppDesignTokens.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (localError != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppDesignTokens.danger.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppDesignTokens.danger, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            localError!,
                            style: const TextStyle(color: AppDesignTokens.danger, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                AppInput(
                  label: 'كلمة المرور الحالية',
                  controller: currentPassController,
                  isPassword: true,
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                ),
                const SizedBox(height: 12),
                AppInput(
                  label: 'كلمة المرور الجديدة',
                  controller: newPassController,
                  isPassword: true,
                  prefixIcon: const Icon(Icons.lock_rounded, size: 18),
                ),
                const SizedBox(height: 12),
                AppInput(
                  label: 'تأكيد كلمة المرور الجديدة',
                  controller: confirmPassController,
                  isPassword: true,
                  prefixIcon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: 'إلغاء',
                        variant: AppButtonVariant.ghost,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppButton(
                        text: isSubmitting ? 'جارٍ الحفظ...' : 'تحديث كلمة المرور',
                        variant: AppButtonVariant.primary,
                        isLoading: isSubmitting,
                        onPressed: () async {
                          final cur = currentPassController.text.trim();
                          final newP = newPassController.text.trim();
                          final confirmP = confirmPassController.text.trim();

                          if (cur.isEmpty || newP.isEmpty || confirmP.isEmpty) {
                            setModalState(() => localError = 'يرجى ملء جميع الحقول المطلوبة');
                            return;
                          }

                          if (newP.length < 6) {
                            setModalState(() => localError = 'كلمة المرور الجديدة يجب أن تكون 6 خانات على الأقل');
                            return;
                          }

                          if (newP != confirmP) {
                            setModalState(() => localError = 'كلمة المرور الجديدة وتأكيدها غير متطابقين');
                            return;
                          }

                          if (newP == cur) {
                            setModalState(() => localError = 'كلمة المرور الجديدة يجب أن تكون مختلفة عن الحالية');
                            return;
                          }

                          setModalState(() {
                            isSubmitting = true;
                            localError = null;
                          });

                          final ok = await ref.read(authProvider.notifier).changePassword(
                            currentPassword: cur,
                            newPassword: newP,
                          );

                          if (ok) {
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: AppDesignTokens.success,
                                  content: Text('تم تغيير كلمة المرور بنجاح ✅'),
                                ),
                              );
                            }
                          } else {
                            final err = ref.read(authProvider).error ?? 'فشل تغيير كلمة المرور';
                            setModalState(() {
                              isSubmitting = false;
                              localError = err;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final currentThemeMode = ref.watch(themeModeProvider);
    final currentLocale = ref.watch(localeProvider);
    final l10n = context.l10n;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppDesignTokens.bg(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: Text(l10n.profileAndSettingsTitle),
        elevation: 0,
        backgroundColor: Colors.transparent,
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
              // ── 1. User Header & Avatar ────────────────────────────────────
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Center(
                      child: AppAvatar(
                        name: user.fullName,
                        imageUrl: user.avatarUrl,
                        size: AppAvatarSize.xlarge,
                        onEditTap: () => _openAvatarActionsModal(context, user),
                        isOnline: true,
                        showOnlineIndicator: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user.fullName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppDesignTokens.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppBadge(
                          label: user.role.displayNameAr,
                          variant: AppBadgeVariant.primary,
                          size: AppBadgeSize.medium,
                        ),
                        if (user.role == UserRole.student) ...[
                          const SizedBox(width: 8),
                          AppBadge(
                            label: user.studentGroupName ?? 'بدون جروب',
                            variant: user.studentGroupId != null ? AppBadgeVariant.primary : AppBadgeVariant.neutral,
                            size: AppBadgeSize.medium,
                          ),
                          if (user.classification != null) ...[
                            const SizedBox(width: 8),
                            AppBadge(
                              label: user.classification!.displayNameAr,
                              variant: AppBadgeVariant.info,
                              size: AppBadgeSize.medium,
                            ),
                          ],
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${l10n.universityCodeLabel} ${user.universityCode}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppDesignTokens.textSecondary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppButton(
                      text: 'تعديل الملف الشخصي',
                      icon: Icons.edit_outlined,
                      variant: AppButtonVariant.outline,
                      size: AppButtonSize.small,
                      onPressed: () => _openEditProfileDialog(context, user),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── 2. Clinical & Group Assignment Data (Read-Only for Student) ───
              if (user.role == UserRole.student) ...[
                AppSectionHeader(title: 'التوزيع السريري والجروب'),
                const SizedBox(height: 6),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                  child: Column(
                    children: [
                      _buildInfoRow(context, Icons.school_outlined, 'المعدل التراكمي (GPA)',
                          user.gpa != null ? user.gpa!.toStringAsFixed(2) : 'غير مسجل'),
                      Divider(height: 12, color: AppDesignTokens.borderSubtle(context)),
                      _buildInfoRow(context, Icons.group_work_outlined, 'الجروب التدريبي',
                          user.studentGroupName ?? 'بدون جروب'),
                      Divider(height: 12, color: AppDesignTokens.borderSubtle(context)),
                      _buildInfoRow(context, Icons.local_hospital_outlined, 'قسم الشهر الحالي',
                          user.departmentName ?? 'غير مخصص لهذا الشهر'),
                      Divider(height: 12, color: AppDesignTokens.borderSubtle(context)),
                      _buildInfoRow(context, Icons.medical_services_outlined, 'الطبيب المشرف',
                          user.supervisorDoctorName ?? 'غير مخصص'),
                      if (user.classification != null) ...[
                        Divider(height: 12, color: AppDesignTokens.borderSubtle(context)),
                        _buildInfoRow(context, Icons.stars_rounded, 'التصنيف الأكاديمي',
                            user.classification!.displayNameAr),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── 3. Previous Work Experience Card ───────────────────────────
                AppSectionHeader(title: 'الخبرة السابقة'),
                const SizedBox(height: 6),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                  child: Column(
                    children: [
                      _buildInfoRow(context, Icons.work_outline_rounded, 'اشتغلت قبل كده؟',
                          user.previousWorkExperience ? 'أيوه' : 'لا'),
                      if (user.previousWorkExperience) ...[
                        Divider(height: 12, color: AppDesignTokens.borderSubtle(context)),
                        _buildInfoRow(context, Icons.business_outlined, 'مكان العمل',
                            user.previousWorkplace != null && user.previousWorkplace!.isNotEmpty
                                ? user.previousWorkplace!
                                : 'غير محدد'),
                        Divider(height: 12, color: AppDesignTokens.borderSubtle(context)),
                        _buildInfoRow(context, Icons.domain_outlined, 'القسم',
                            user.previousWorkDepartment != null && user.previousWorkDepartment!.isNotEmpty
                                ? user.previousWorkDepartment!
                                : 'غير محدد'),
                        if (user.previousWorkExperienceDetails != null &&
                            user.previousWorkExperienceDetails!.isNotEmpty) ...[
                          Divider(height: 12, color: AppDesignTokens.borderSubtle(context)),
                          _buildInfoRow(context, Icons.description_outlined, 'الخبرة',
                              user.previousWorkExperienceDetails!),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── 4. Official Academic & Contact Data ────────────────────────
              AppSectionHeader(title: l10n.accountSection),
              const SizedBox(height: 6),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                child: Column(
                  children: [
                    _buildInfoRow(context, Icons.email_outlined, l10n.emailLabel, user.email),
                    Divider(height: 12, color: AppDesignTokens.borderSubtle(context)),
                    _buildInfoRow(context, Icons.phone_outlined, l10n.phoneLabel, user.phoneNumber),
                    if (user.nationalId != null && user.nationalId!.isNotEmpty) ...[
                      Divider(height: 12, color: AppDesignTokens.borderSubtle(context)),
                      _buildInfoRow(context, Icons.credit_card_outlined, l10n.nationalIdLabel, user.nationalId!),
                    ],
                    Divider(height: 12, color: AppDesignTokens.borderSubtle(context)),
                    _buildInfoRow(context, Icons.home_outlined, l10n.residenceLabel, user.isMatrouhResident ? l10n.residentMatrouh : l10n.residentExpatriate),
                    if (user.emergencyContact.isNotEmpty) ...[
                      Divider(height: 12, color: AppDesignTokens.borderSubtle(context)),
                      _buildInfoRow(context, Icons.contact_phone_outlined, 'جهة اتصال الطوارئ', user.emergencyContact),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── 3. Appearance Section ──────────────────────────────────────
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
                    Divider(height: 1, color: AppDesignTokens.borderSubtle(context)),
                    _buildThemeRadioRow(
                      context,
                      title: l10n.themeLight,
                      icon: Icons.light_mode_rounded,
                      isSelected: currentThemeMode == ThemeMode.light,
                      onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light),
                    ),
                    Divider(height: 1, color: AppDesignTokens.borderSubtle(context)),
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

              // ── 4. Language Section ────────────────────────────────────────
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
                    Divider(height: 1, color: AppDesignTokens.borderSubtle(context)),
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

              // ── 5. Push Notifications & FCM Diagnostics ────────────────────
              AppSectionHeader(title: l10n.isArabic ? 'الإشعارات والتنبيهات الفورية' : 'Push Notifications'),
              const SizedBox(height: 6),
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppDesignTokens.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.notifications_active_outlined, color: AppDesignTokens.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.isArabic ? 'إشعارات الروستر والتدريب' : 'Shift & Roster Push Alerts',
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppDesignTokens.textPrimary(context)),
                              ),
                              Text(
                                PushNotificationService.instance.getPermissionStatus() == PushPermissionStatus.granted
                                    ? (l10n.isArabic ? '✓ الإشعارات مفعلة على هذا الجهاز' : '✓ Notifications enabled on this device')
                                    : (l10n.isArabic ? '⚠ الإشعارات غير مفعلة حالياً' : '⚠ Notifications currently disabled'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: PushNotificationService.instance.getPermissionStatus() == PushPermissionStatus.granted
                                      ? AppDesignTokens.success
                                      : AppDesignTokens.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            text: PushNotificationService.instance.getPermissionStatus() == PushPermissionStatus.granted
                                ? (l10n.isArabic ? 'إرسال إشعار تجريبي 🔔' : 'Send Test Alert 🔔')
                                : (l10n.isArabic ? 'تفعيل الإشعارات 🔔' : 'Enable Alerts 🔔'),
                            variant: AppButtonVariant.primary,
                            size: AppButtonSize.small,
                            onPressed: () async {
                              if (PushNotificationService.instance.getPermissionStatus() != PushPermissionStatus.granted) {
                                await PushNotificationService.instance.requestPermission();
                                await FirebaseMessagingService.instance.requestPermission();
                                await FirebaseMessagingService.instance.retrieveToken();
                                if (mounted) setState(() {});
                              } else {
                                await PushNotificationService.instance.showBrowserNotification(
                                  title: 'MANU (FCM)',
                                  body: 'تم اختبار الإشعارات الفورية بنجاح على جهازك! 🎉',
                                  route: '/notifications',
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppDesignTokens.success,
                                      content: Text(l10n.isArabic ? 'تم إرسال إشعار تجريبي بنجاح ✅' : 'Test notification sent ✅'),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            text: l10n.isArabic ? 'تشخيص FCM 🛠️' : 'FCM Debug 🛠️',
                            variant: AppButtonVariant.outline,
                            size: AppButtonSize.small,
                            onPressed: () => context.push('/fcm-debug'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── 6. Security & Biometrics ───────────────────────────────────
              AppSectionHeader(title: l10n.securitySection),
              const SizedBox(height: 6),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppDesignTokens.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_reset_rounded, color: AppDesignTokens.primary, size: 20),
                      ),
                      title: const Text(
                        'تغيير كلمة المرور',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'تحديث كلمة مرور الحساب والرمز السري',
                        style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                      onTap: () => _openChangePasswordDialog(context),
                    ),
                    Divider(height: 1, color: AppDesignTokens.borderSubtle(context)),
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                      title: Text(
                        l10n.enableBiometrics,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppDesignTokens.textPrimary(context)),
                      ),
                      subtitle: Text(
                        l10n.enableBiometricsSub,
                        style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                      ),
                      value: authState.isBiometricEnabled,
                      activeColor: AppDesignTokens.primary,
                      onChanged: (val) {
                        ref.read(authProvider.notifier).toggleBiometrics(val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── 7. About App ───────────────────────────────────────────────
              AppSectionHeader(title: l10n.aboutSection),
              const SizedBox(height: 6),
              if (_availableUpdate != null && _availableUpdate!.hasUpdate) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
                    border: Border.all(color: AppDesignTokens.primary.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppDesignTokens.primary.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.rocket_launch_rounded, color: AppDesignTokens.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تحديث جديد متاح (v${_availableUpdate!.latestVersion}) 🚀',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppDesignTokens.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'اضغط للتحميل والتثبيت المباشر',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppDesignTokens.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppDesignTokens.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () => AppUpdateModal.showUpdateDialog(context, _availableUpdate!),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('تحديث الآن', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: Column(
                  children: [
                    _buildNavRow(
                      context,
                      Icons.system_update_rounded,
                      'التحقق من وجود تحديثات',
                      _availableUpdate != null && _availableUpdate!.hasUpdate
                          ? 'تحديث متاح 🚀'
                          : 'أحدث إصدار ✅',
                      onTap: () async {
                        await AppUpdateModal.showUpdateCheck(context);
                        _loadVersionAndCheckUpdates();
                      },
                    ),
                    Divider(height: 8, color: AppDesignTokens.borderSubtle(context)),
                    _buildNavRow(
                      context,
                      Icons.info_outline_rounded,
                      l10n.appVersionLabel,
                      'v$_installedVersion (#$_installedBuildNumber)',
                      onTap: () async {
                        await AppUpdateModal.showUpdateCheck(context);
                        _loadVersionAndCheckUpdates();
                      },
                    ),
                    Divider(height: 8, color: AppDesignTokens.borderSubtle(context)),
                    _buildNavRow(context, Icons.privacy_tip_outlined, l10n.privacyPolicy, null),
                    Divider(height: 8, color: AppDesignTokens.borderSubtle(context)),
                    _buildNavRow(context, Icons.description_outlined, l10n.termsOfService, null),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── 8. Logout Button ───────────────────────────────────────────
              Center(
                child: AppButton(
                  text: l10n.logoutBtn,
                  icon: Icons.logout_rounded,
                  variant: AppButtonVariant.danger,
                  size: AppButtonSize.medium,
                  width: double.infinity,
                  onPressed: () => _confirmLogout(context, ref, l10n),
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
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? AppDesignTokens.primary : AppDesignTokens.textSecondary(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppDesignTokens.primary : AppDesignTokens.textPrimary(context),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_rounded, color: AppDesignTokens.primary, size: 18),
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
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(Icons.language_rounded, size: 20, color: isSelected ? AppDesignTokens.primary : AppDesignTokens.textSecondary(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppDesignTokens.primary : AppDesignTokens.textPrimary(context),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_rounded, color: AppDesignTokens.primary, size: 18),
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
          Icon(icon, size: 18, color: AppDesignTokens.primary),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppDesignTokens.textPrimary(context)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavRow(BuildContext context, IconData icon, String title, String? value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap != null
          ? () {
              HapticFeedback.lightImpact();
              onTap();
            }
          : null,
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppDesignTokens.textSecondary(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 13, color: AppDesignTokens.textPrimary(context), fontWeight: FontWeight.w500),
              ),
            ),
            if (value != null)
              Text(value, style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)))
            else
              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppDesignTokens.textMuted(context)),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    AppDialog.showConfirmation(
      context,
      title: l10n.logoutConfirmTitle,
      message: l10n.logoutConfirmMessage,
      confirmText: l10n.logoutBtn,
      cancelText: l10n.cancel,
      isDestructive: true,
      icon: Icons.logout_rounded,
    ).then((confirmed) async {
      if (confirmed == true) {
        await ref.read(authProvider.notifier).logout();
        if (context.mounted) {
          context.go('/login');
        }
      }
    });
  }
}
