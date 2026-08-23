import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/app_version_model.dart';
import '../../../core/services/app_update_service.dart';
import '../../profile/widgets/app_update_dialog.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_input.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/app_versions_provider.dart';

class AppVersionsScreen extends ConsumerStatefulWidget {
  const AppVersionsScreen({super.key});

  @override
  ConsumerState<AppVersionsScreen> createState() => _AppVersionsScreenState();
}

class _AppVersionsScreenState extends ConsumerState<AppVersionsScreen> {
  AppVersionInfo? _installedInfo;
  bool _isLoadingInstalled = true;

  @override
  void initState() {
    super.initState();
    _loadInstalledInfo();
  }

  Future<void> _loadInstalledInfo() async {
    final info = await AppUpdateService.checkForUpdates(isManualCheck: true);
    if (mounted) {
      setState(() {
        _installedInfo = info;
        _isLoadingInstalled = false;
      });
    }
  }

  void _openPublishDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _PublishReleaseBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.role == UserRole.superAdmin;
    final isLeader = user?.role == UserRole.leader;

    // Leader has Read-Only access. Student/Doctor cannot access this management screen.
    if (!isAdmin && !isLeader) {
      return Scaffold(
        backgroundColor: AppDesignTokens.bg(context),
        appBar: AppBar(title: const Text('إصدارات التطبيق')),
        body: Center(
          child: AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 48, color: AppDesignTokens.danger),
                const SizedBox(height: 12),
                Text(
                  'غير مصرح لك بالوصول',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppDesignTokens.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'هذه الصفحة مخصصة لإدارة ومتابعة إصدارات التطبيق فقط.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final state = ref.watch(appVersionsProvider);

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: Text(isAdmin ? 'إدارة إصدارات التطبيق (Android Releases)' : 'متابعة إصدارات التطبيق'),
        backgroundColor: AppDesignTokens.surface(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث البيانات',
            onPressed: () {
              ref.read(appVersionsProvider.notifier).loadVersions();
              _loadInstalledInfo();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _openPublishDialog(context),
              backgroundColor: AppDesignTokens.primary,
              icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
              label: const Text(
                'نشر إصدار جديد',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppDesignTokens.primary))
          : RefreshIndicator(
              onRefresh: () async {
                await ref.read(appVersionsProvider.notifier).loadVersions();
                await _loadInstalledInfo();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Current Client & Active Release Header Card
                    _buildInstalledHeader(context, isAdmin, isLeader),

                    const SizedBox(height: 16),

                    if (state.errorMessage != null) ...[
                      AppCard(
                        variant: AppCardVariant.outlined,
                        borderColor: AppDesignTokens.danger.withOpacity(0.4),
                        backgroundColor: AppDesignTokens.danger.withOpacity(0.06),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppDesignTokens.danger, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                state.errorMessage!,
                                style: const TextStyle(fontSize: 12, color: AppDesignTokens.danger),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // 2. Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppSectionHeader(
                          title: 'سجل الإصدارات المنشورة',
                          subtitle: 'جميع حزم APK الرسمية الخاصة بنظام Android',
                        ),
                        if (isLeader)
                          AppBadge(
                            label: 'للعرض فقط (Leader View)',
                            variant: AppBadgeVariant.info,
                            size: AppBadgeSize.small,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 3. Releases List
                    if (state.versions.isEmpty)
                      AppCard(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 42, color: AppDesignTokens.textMuted(context)),
                              const SizedBox(height: 10),
                              Text(
                                'لا توجد إصدارات مسجلة حتى الآن',
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppDesignTokens.textSecondary(context)),
                              ),
                              if (isAdmin) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'اضغط على زر نشر إصدار جديد لرفع أول ملف APK للنظام.',
                                  style: TextStyle(fontSize: 11.5, color: AppDesignTokens.textMuted(context)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.versions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final version = state.versions[index];
                          return _buildReleaseCard(context, version, isAdmin);
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInstalledHeader(BuildContext context, bool isAdmin, bool isLeader) {
    return AppCard(
      variant: AppCardVariant.accentTeal,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppDesignTokens.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                ),
                child: const Icon(Icons.android_rounded, color: AppDesignTokens.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حالة منصة Android وقناة التحديثات',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AppDesignTokens.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isLoadingInstalled
                          ? 'جارٍ فحص الإصدار المثبت...'
                          : 'الإصدار المثبت محلياً: v${_installedInfo?.currentVersion ?? '1.0.0'} (Build ${_installedInfo?.currentVersionCode ?? 1})',
                      style: TextStyle(fontSize: 11.5, color: AppDesignTokens.textSecondary(context)),
                    ),
                  ],
                ),
              ),
              if (isAdmin)
                AppBadge(
                  label: 'تحكم كامل (Admin)',
                  variant: AppBadgeVariant.success,
                  size: AppBadgeSize.small,
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppDesignTokens.success),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'يتم فحص الإصدارات النشطة ومقارنتها برقم Build تلقائياً لجميع الطلاب والمشرفين.',
                  style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReleaseCard(BuildContext context, AppVersionModel version, bool isAdmin) {
    final dateFormat = DateFormat('yyyy/MM/dd - hh:mm a', 'ar');
    final formattedDate = dateFormat.format(version.releaseDate.toLocal());

    return AppCard(
      padding: const EdgeInsets.all(14),
      variant: version.isActive ? AppCardVariant.standard : AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: version.isActive
                      ? AppDesignTokens.primary.withOpacity(0.12)
                      : AppDesignTokens.surfaceMutedLight,
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                ),
                child: Icon(
                  Icons.system_update_rounded,
                  color: version.isActive ? AppDesignTokens.primary : AppDesignTokens.slateMedium,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'v${version.versionName}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppDesignTokens.textPrimary(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppDesignTokens.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppDesignTokens.primary.withOpacity(0.2)),
                          ),
                          child: Text(
                            'Build #${version.versionCode}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppDesignTokens.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'تاريخ النشر: $formattedDate',
                      style: TextStyle(fontSize: 10.5, color: AppDesignTokens.textSecondary(context)),
                    ),
                  ],
                ),
              ),
              // Badges
              Wrap(
                spacing: 4,
                direction: Axis.vertical,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  AppBadge(
                    label: version.isActive ? 'الإصدار النشط (Active)' : 'مؤرشف (Inactive)',
                    variant: version.isActive ? AppBadgeVariant.success : AppBadgeVariant.neutral,
                    size: AppBadgeSize.small,
                  ),
                  if (version.forceUpdate)
                    const AppBadge(
                      label: 'تحديث إجباري (Force)',
                      variant: AppBadgeVariant.danger,
                      size: AppBadgeSize.small,
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Release Notes
          if (version.releaseNotes != null && version.releaseNotes!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppDesignTokens.bg(context),
                borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                border: Border.all(color: AppDesignTokens.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ملاحظات الإصدار والتغييرات:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppDesignTokens.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    version.releaseNotes!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppDesignTokens.textSecondary(context),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Metadata row (Min supported, File size)
          Row(
            children: [
              Icon(Icons.security_rounded, size: 14, color: AppDesignTokens.textMuted(context)),
              const SizedBox(width: 4),
              Text(
                'الحد الأدنى المدعوم: Build #${version.minimumSupportedVersion}',
                style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
              ),
              if (version.fileSize != null && version.fileSize! > 0) ...[
                const SizedBox(width: 12),
                Icon(Icons.attachment_rounded, size: 14, color: AppDesignTokens.textMuted(context)),
                const SizedBox(width: 4),
                Text(
                  version.formattedFileSize,
                  style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Test Download Link
              TextButton.icon(
                onPressed: () {
                  final info = AppVersionInfo(
                    currentVersion: _installedInfo?.currentVersion ?? '1.0.0',
                    currentVersionCode: _installedInfo?.currentVersionCode ?? 1,
                    latestVersion: version.versionName,
                    latestVersionCode: version.versionCode,
                    releaseNotes: version.releaseNotes ?? '',
                    downloadUrl: version.apkDownloadUrl,
                    fileSize: version.fileSize,
                    fileName: version.fileName,
                    isMandatory: version.forceUpdate,
                    hasUpdate: true,
                  );
                  AppUpdateModal.showUpdateDialog(context, info);
                },
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: const Text('تحميل / اختبار APK', style: TextStyle(fontSize: 11.5)),
                style: TextButton.styleFrom(
                  foregroundColor: AppDesignTokens.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),

              // Admin controls (Toggle Active, Delete)
              if (isAdmin)
                Row(
                  children: [
                    Text(
                      version.isActive ? 'تعطيل' : 'تفعيل',
                      style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                    ),
                    Transform.scale(
                      scale: 0.75,
                      child: Switch(
                        value: version.isActive,
                        activeColor: AppDesignTokens.primary,
                        onChanged: (val) {
                          ref.read(appVersionsProvider.notifier).toggleActiveStatus(version.id, version.isActive);
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppDesignTokens.danger, size: 18),
                      tooltip: 'حذف الإصدار',
                      onPressed: () {
                        _confirmDelete(context, version);
                      },
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppVersionModel version) {
    AppDialog.showConfirmation(
      context,
      title: 'حذف الإصدار v${version.versionName}',
      message: 'هل أنت متأكد من حذف الإصدار (Build #${version.versionCode})؟ لن يتمكن المستخدمون من تحميل هذه النسخة.',
      confirmText: 'حذف نهائي',
      cancelText: 'إلغاء',
      isDestructive: true,
      icon: Icons.delete_forever_rounded,
    ).then((confirmed) {
      if (confirmed == true) {
        ref.read(appVersionsProvider.notifier).deleteRelease(version.id);
      }
    });
  }
}

// -----------------------------------------------------------------------------
// BOTTOM SHEET: PUBLISH NEW RELEASE FORM
// -----------------------------------------------------------------------------
class _PublishReleaseBottomSheet extends ConsumerStatefulWidget {
  const _PublishReleaseBottomSheet();

  @override
  ConsumerState<_PublishReleaseBottomSheet> createState() => _PublishReleaseBottomSheetState();
}

class _PublishReleaseBottomSheetState extends ConsumerState<_PublishReleaseBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _minVersionCtrl = TextEditingController(text: '1');

  bool _forceUpdate = false;
  bool _isActive = true;
  PlatformFile? _pickedApk;
  Uint8List? _apkBytes;
  bool _isPickingFile = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _urlCtrl.dispose();
    _notesCtrl.dispose();
    _minVersionCtrl.dispose();
    super.dispose();
  }

  String _normalizeDownloadUrl(String url) {
    var raw = url.trim();
    if (raw.isEmpty) return raw;

    // Google Drive share link converter:
    // https://drive.google.com/file/d/FILE_ID/view?usp=sharing -> https://drive.google.com/uc?export=download&id=FILE_ID
    final gdMatch = RegExp(r'drive\.google\.com/file/d/([a-zA-Z0-9_-]+)').firstMatch(raw);
    if (gdMatch != null) {
      final fileId = gdMatch.group(1);
      return 'https://drive.google.com/uc?export=download&id=$fileId';
    }

    // Dropbox dl=0 -> dl=1
    if (raw.contains('dropbox.com') && raw.contains('dl=0')) {
      return raw.replaceAll('dl=0', 'dl=1');
    }

    return raw;
  }

  Future<void> _pickApkFile() async {
    setState(() => _isPickingFile = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['apk'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _pickedApk = file;
          _apkBytes = file.bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ تعذر اختيار الملف: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingFile = false);
    }
  }

  Future<void> _submitPublish() async {
    if (!_formKey.currentState!.validate()) return;

    final state = ref.read(appVersionsProvider);
    final int versionCode = int.parse(_codeCtrl.text.trim());

    // 1. Check duplicate version code
    final duplicate = state.versions.any((v) => v.versionCode == versionCode);
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ رقم Version Code ($versionCode) موجود بالفعل! يرجى إدخال رقم إصدار أحدث.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final directUrl = _normalizeDownloadUrl(_urlCtrl.text.trim());

    // 2. Check APK provided or Direct Link
    if (_apkBytes == null && directUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ يرجى اختيار ملف APK أو إدخال رابط التحميل المباشر'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final minVersion = int.tryParse(_minVersionCtrl.text.trim()) ?? 1;

    final success = await ref.read(appVersionsProvider.notifier).publishNewRelease(
      versionName: _nameCtrl.text.trim(),
      versionCode: versionCode,
      apkUrl: directUrl,
      releaseNotes: _notesCtrl.text.trim(),
      forceUpdate: _forceUpdate,
      minimumSupportedVersion: minVersion,
      isActive: _isActive,
      fileName: _pickedApk?.name,
      fileSize: _pickedApk?.size,
      apkBytes: _apkBytes,
    );

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 تم نشر الإصدار الجديد بنجاح وإتاحته للتحميل!'),
          backgroundColor: AppDesignTokens.success,
        ),
      );
    } else if (mounted) {
      final error = ref.read(appVersionsProvider).errorMessage ?? 'حدث خطأ أثناء الرفع.';
      String helpfulMsg = error;
      if (error.contains('SocketException') || error.contains('connection abort') || error.contains('errno = 103')) {
        helpfulMsg = '⚠️ انقطع الاتصال أثناء الرفع بسبب بطء أو انقطاع شبكة الهاتف. يمكنك إعادة المحاولة أو وضع رابط تحميل APK مباشر.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(helpfulMsg),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appVersionsProvider);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: AppDesignTokens.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: AppDesignTokens.border(context)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
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
                          borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                        ),
                        child: const Icon(Icons.cloud_upload_rounded, color: AppDesignTokens.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'نشر إصدار جديد (Android APK)',
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
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Version Name & Code Row
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: AppInput(
                      label: 'اسم الإصدار (Version Name)',
                      hint: 'مثال: 1.1.0',
                      controller: _nameCtrl,
                      prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'مطلوب';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: AppInput(
                      label: 'Version Code',
                      hint: 'مثال: 2',
                      controller: _codeCtrl,
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.numbers_rounded, size: 18),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'مطلوب';
                        final n = int.tryParse(val.trim());
                        if (n == null || n <= 0) return 'رقم غير صالح';
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // APK File Picker Box
              Text(
                'ملف حزمة التطبيق (APK File)',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppDesignTokens.textPrimary(context)),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _isPickingFile ? null : _pickApkFile,
                borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.bg(context),
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                    border: Border.all(
                      color: _pickedApk != null ? AppDesignTokens.primary : AppDesignTokens.border(context),
                      width: _pickedApk != null ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _pickedApk != null ? Icons.check_circle_rounded : Icons.file_upload_outlined,
                        color: _pickedApk != null ? AppDesignTokens.primary : AppDesignTokens.textSecondary(context),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _pickedApk != null
                                  ? _pickedApk!.name
                                  : 'اضغط لاختيار ملف APK من جهازك',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _pickedApk != null ? FontWeight.bold : FontWeight.normal,
                                color: _pickedApk != null ? AppDesignTokens.primary : AppDesignTokens.textSecondary(context),
                              ),
                            ),
                            if (_pickedApk != null)
                              Text(
                                '${(_pickedApk!.size / (1024 * 1024)).toStringAsFixed(1)} MB • جاهز للرفع إلى Storage',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppDesignTokens.textSecondary(context),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_pickedApk != null)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => setState(() {
                            _pickedApk = null;
                            _apkBytes = null;
                          }),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Alternative Direct APK URL
              AppInput(
                label: 'رابط التحميل المباشر للـ APK (Google Drive / GitHub / MediaFire)',
                hint: 'https://...',
                controller: _urlCtrl,
                keyboardType: TextInputType.url,
                prefixIcon: const Icon(Icons.link_rounded, size: 18),
              ),

              const SizedBox(height: 14),

              // Release Notes
              AppInput(
                label: 'ملاحظات وتفاصيل التحديث (Release Notes)',
                hint: '• تحسين استقرار الحضور\n• إصلاح مشكلة الإشعارات...',
                controller: _notesCtrl,
                maxLines: 3,
                prefixIcon: const Icon(Icons.notes_rounded, size: 18),
              ),

              const SizedBox(height: 14),

              // Minimum supported version
              AppInput(
                label: 'الحد الأدنى المدعوم (Minimum Supported Version Code)',
                hint: '1',
                controller: _minVersionCtrl,
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.verified_user_outlined, size: 18),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'مطلوب';
                  final n = int.tryParse(val.trim());
                  if (n == null || n <= 0) return 'رقم غير صالح';
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // Switches
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('تحديث إجباري (Force Update)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppDesignTokens.textPrimary(context))),
                        Text('يمنع فتح واستخدام التطبيق حتى يتم التحديث', style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context))),
                      ],
                    ),
                  ),
                  Switch(
                    value: _forceUpdate,
                    activeColor: AppDesignTokens.primary,
                    onChanged: (val) => setState(() => _forceUpdate = val),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('تفعيل الإصدار فور النشر (Active)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppDesignTokens.textPrimary(context))),
                        Text('يصبح الإصدار الرسمي المتاح لجميع الطلاب فوراً', style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context))),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isActive,
                    activeColor: AppDesignTokens.primary,
                    onChanged: (val) => setState(() => _isActive = val),
                  ),
                ],
              ),

              if (state.isSaving) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
                    border: Border.all(color: AppDesignTokens.primary.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              state.uploadStatusText ?? 'جارٍ رفع الحزمة...',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppDesignTokens.textPrimary(context),
                              ),
                            ),
                          ),
                          Text(
                            '${(state.uploadProgress * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppDesignTokens.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: state.uploadProgress > 0 ? state.uploadProgress : null,
                          minHeight: 8,
                          backgroundColor: AppDesignTokens.primary.withOpacity(0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppDesignTokens.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Submit Button
              AppButton(
                text: state.isSaving
                    ? 'جارٍ الرفع (${(state.uploadProgress * 100).toInt()}%) والنشر...'
                    : 'نشر الإصدار الرسمي الآن',
                icon: Icons.cloud_upload_rounded,
                isLoading: state.isSaving,
                onPressed: state.isSaving ? null : _submitPublish,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
