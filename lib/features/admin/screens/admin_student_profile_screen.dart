import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/user_app_version_model.dart';
import '../../../core/services/presence_service.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/utils/timezone_helper.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../auth/models/user_profile.dart';
import '../../groups/repositories/student_groups_repository.dart';
import '../models/admin_student_overview_model.dart';
import '../services/admin_student_management_service.dart';

class AdminStudentProfileScreen extends StatefulWidget {
  final String studentId;
  final String initialName;
  final String? initialAvatarUrl;
  final String? initialCode;
  final AdminStudentOverviewModel? initialOverview;

  const AdminStudentProfileScreen({
    super.key,
    required this.studentId,
    required this.initialName,
    this.initialAvatarUrl,
    this.initialCode,
    this.initialOverview,
  });

  static Future<void> show(
    BuildContext context, {
    required String studentId,
    required String initialName,
    String? initialAvatarUrl,
    String? initialCode,
    AdminStudentOverviewModel? initialOverview,
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    if (isDesktop) {
      return showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 850),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AdminStudentProfileScreen(
                studentId: studentId,
                initialName: initialName,
                initialAvatarUrl: initialAvatarUrl,
                initialCode: initialCode,
                initialOverview: initialOverview,
              ),
            ),
          ),
        ),
      );
    }

    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => AdminStudentProfileScreen(
          studentId: studentId,
          initialName: initialName,
          initialAvatarUrl: initialAvatarUrl,
          initialCode: initialCode,
          initialOverview: initialOverview,
        ),
      ),
    );
  }

  @override
  State<AdminStudentProfileScreen> createState() => _AdminStudentProfileScreenState();
}

class _AdminStudentProfileScreenState extends State<AdminStudentProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  Timer? _uiTicker;
  StreamSubscription? _presenceSubscription;

  final List<String> _tabs = [
    'نظرة عامة',
    'البيانات الأكاديمية',
    'توزيعة اليوم',
    'الحضور',
    'التقييمات',
    'المكافآت',
    'الجزاءات',
    'الاختبارات',
    'التطبيق والجهاز',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    // Immediately pre-seed from initialOverview to avoid blank/unknown states
    if (widget.initialOverview != null) {
      final o = widget.initialOverview!;
      _profileData = {
        'student_id': o.studentId,
        'full_name': o.fullName,
        'university_code': o.universityCode,
        'email': o.email,
        'phone_number': o.phoneNumber,
        'gpa': o.gpa,
        'student_group': o.studentGroup,
        'student_group_id': o.studentGroupId,
        'group_name': o.studentGroup,
        'department_name': o.departmentName,
        'supervisor_doctor_name': o.supervisorDoctorName,
        'student_classification': o.classification?.name,
        'previous_work_experience': o.previousWorkExperience,
        'previous_workplace': o.previousWorkplace,
        'previous_work_department': o.previousWorkDepartment,
        'registration_status': o.registrationStatus,
        'is_approved': o.isApproved,
        'avatar_url': o.avatarUrl,
        'presence': {
          'is_online': o.isOnline,
          'effective_is_online': o.effectiveIsOnline,
          'last_seen_at': o.lastSeenAt.toIso8601String(),
        },
        'app_version': {
          'platform': o.appPlatform,
          'version_name': o.installedVersionName.isNotEmpty ? o.installedVersionName : 'غير معروف',
          'version_code': o.installedVersionCode,
          'device_info': o.deviceInfo,
          'last_reported_at': o.versionReportedAt?.toIso8601String(),
          'latest_version_name': o.latestPlatformVersionName,
          'latest_version_code': o.latestPlatformVersionCode,
          'update_status': o.updateStatus.name,
        },
      };
      _isLoading = false;
    }

    _loadProfile();
    _startUiTicker();
    _subscribeToLivePresence();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _uiTicker?.cancel();
    _presenceSubscription?.cancel();
    super.dispose();
  }

  void _startUiTicker() {
    _uiTicker = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  void _subscribeToLivePresence() {
    _presenceSubscription = PresenceService.instance.presenceStream.listen((presenceMap) {
      if (mounted && presenceMap.containsKey(widget.studentId)) {
        final updated = presenceMap[widget.studentId];
        if (updated != null && _profileData != null) {
          setState(() {
            _profileData!['presence'] = {
              'is_online': updated.isOnline,
              'effective_is_online': updated.isEffectivelyOnline,
              'last_seen_at': updated.lastSeenAt.toIso8601String(),
            };
          });
        }
      }
    });
  }

  Future<void> _loadProfile() async {
    final data = await AdminStudentManagementService.instance.fetchStudentFullProfile(widget.studentId);
    if (mounted) {
      setState(() {
        if (data != null) {
          // If loaded data has no version but initialOverview had it, preserve it
          if (widget.initialOverview != null) {
            final o = widget.initialOverview!;
            final loadedVer = data['app_version'] as Map<String, dynamic>?;
            final vCode = (loadedVer?['version_code'] as num?)?.toInt() ?? 0;
            if (vCode == 0 && o.installedVersionCode > 0) {
              data['app_version'] = {
                'platform': o.appPlatform,
                'version_name': o.installedVersionName,
                'version_code': o.installedVersionCode,
                'device_info': o.deviceInfo,
                'last_reported_at': o.versionReportedAt?.toIso8601String(),
                'latest_version_name': o.latestPlatformVersionName,
                'latest_version_code': o.latestPlatformVersionCode,
                'update_status': o.updateStatus.name,
              };
            }
          }
          _profileData = data;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _showEditGpaDialog() async {
    final currentGpa = _profileData?['gpa'] != null
        ? (_profileData!['gpa'] as num).toDouble()
        : 0.0;
    final controller = TextEditingController(text: currentGpa > 0 ? currentGpa.toStringAsFixed(2) : '');
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppDesignTokens.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school_rounded, color: AppDesignTokens.primary),
              ),
              const SizedBox(width: 10),
              const Text('تعديل المعدل التراكمي (GPA)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المعدل الحالي المسجل: ${currentGpa > 0 ? currentGpa.toStringAsFixed(2) : "غير محدد"}',
                  style: TextStyle(fontSize: 13, color: AppDesignTokens.textSecondary(context)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'المعدل التراكمي الجديد (0.00 - 4.00) *',
                    hintText: '3.85',
                    prefixIcon: Icon(Icons.grade_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'يرجى إدخال المعدل التراكمي';
                    final parsed = double.tryParse(val.trim());
                    if (parsed == null) return 'قيمة غير صالحة';
                    if (parsed < 0.0 || parsed > 4.0) return 'يجب أن يكون المعدل بين 0.00 و 4.00';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'ملاحظة: هذا التعديل مقصور على Super Admin ومسجل في سجل النظام.',
                  style: TextStyle(fontSize: 11, color: AppDesignTokens.textMuted(context)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDesignTokens.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      final newGpa = double.parse(controller.text.trim());
                      setDialogState(() => isSaving = true);
                      try {
                        await AdminStudentManagementService.instance.updateStudentGpa(
                          studentId: widget.studentId,
                          newGpa: newGpa,
                        );
                        if (mounted) {
                          setState(() {
                            _profileData?['gpa'] = newGpa;
                          });
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تم تحديث المعدل التراكمي بنجاح إلى ${newGpa.toStringAsFixed(2)}'),
                              backgroundColor: AppDesignTokens.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('خطأ أثناء التعديل: ${e.toString().replaceAll("Exception: ", "")}'),
                              backgroundColor: AppDesignTokens.danger,
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('حفظ التعديل'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditClassificationDialog() async {
    final rawClass = _profileData?['student_classification'];
    StudentClassification? current = StudentClassification.fromString(rawClass?.toString());

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.military_tech_outlined, color: AppDesignTokens.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'تصنيف الطالب الأكاديمي والسريري',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'اختر تصنيف الطالب للمساعدة في توزيع الجروبات المتوازنة:',
                style: TextStyle(fontSize: 13, color: AppDesignTokens.textSecondary(context)),
              ),
              const SizedBox(height: 16),
              ...StudentClassification.values.map((cls) {
                final isSelected = current == cls;
                return ListTile(
                  leading: Text(
                    cls.emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                  title: Text(
                    cls.displayNameAr,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppDesignTokens.primary : null,
                    ),
                  ),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: AppDesignTokens.primary) : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: isSelected ? AppDesignTokens.primary.withOpacity(0.08) : null,
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    try {
                      await AdminStudentManagementService.instance.updateStudentClassification(
                        studentId: widget.studentId,
                        classification: cls,
                      );
                      if (mounted) {
                        setState(() {
                          _profileData?['student_classification'] = cls.code;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('تم تعيين تصنيف الطالب إلى: ${cls.displayNameAr}'),
                            backgroundColor: AppDesignTokens.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('خطأ في حفظ التصنيف: $e'),
                            backgroundColor: AppDesignTokens.danger,
                          ),
                        );
                      }
                    }
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showChangeGroupDialog() async {
    final groups = await StudentGroupsRepository().fetchGroups();
    String? currentGroupId = _profileData?['student_group_id']?.toString();
    String? selectedGroupId = currentGroupId;
    bool isSaving = false;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.group_work_rounded, color: Colors.indigo),
              ),
              const SizedBox(width: 10),
              const Text('تغيير جروب الطالب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'اختر الجروب التدريبي الجديد. سيرث الطالب تلقائياً الطبيب المشرف وقسم الشهر الحالي المرتبط بالجروب.',
                style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context)),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                value: selectedGroupId,
                decoration: const InputDecoration(
                  labelText: 'الجروب التدريبي',
                  prefixIcon: Icon(Icons.groups_rounded),
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('بدون جروب (إلغاء التنسيب)')),
                  ...groups.map((g) => DropdownMenuItem(
                        value: g.id,
                        child: Text('${g.name} (${g.supervisorDoctorName != null ? "د. " + g.supervisorDoctorName! : "بدون طبيب"})'),
                      )),
                ],
                onChanged: (v) => setDialogState(() => selectedGroupId = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppDesignTokens.primary, foregroundColor: Colors.white),
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      final repo = StudentGroupsRepository();
                      if (selectedGroupId != null) {
                        await repo.assignStudentToGroup(studentId: widget.studentId, groupId: selectedGroupId!);
                      } else {
                        await repo.removeStudentFromGroup(widget.studentId);
                      }
                      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                      await _loadProfile();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppDesignTokens.success,
                            content: Text('تم تحديث جروب الطالب بنجاح ✓'),
                          ),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final name = _profileData?['full_name'] ?? widget.initialName;
    final code = _profileData?['university_code'] ?? widget.initialCode ?? '';
    final avatarUrl = _profileData?['avatar_url'] ?? widget.initialAvatarUrl;

    // Presence calculation
    final presenceMap = _profileData?['presence'] as Map<String, dynamic>?;
    final isOnlineRaw = presenceMap?['is_online'] == true;
    final lastSeenStr = presenceMap?['last_seen_at']?.toString();
    final lastSeenAt = DateTime.tryParse(lastSeenStr ?? '') ?? DateTime.now().toUtc();
    final serverNow = AppTimezoneHelper.serverNowUtc;
    final diffSec = serverNow.difference(lastSeenAt.toUtc()).inSeconds;
    final isEffectivelyOnline = isOnlineRaw && diffSec <= 120;
    final presenceText = AppTimezoneHelper.formatLastSeenArabic(
      lastSeenAt: lastSeenAt,
      isEffectivelyOnline: isEffectivelyOnline,
      referenceServerNow: serverNow,
    );

    // App Version calculation
    final versionMap = _profileData?['app_version'] as Map<String, dynamic>?;
    final platform = versionMap?['platform']?.toString() ?? 'android';
    final versionName = versionMap?['version_name']?.toString() ?? '';
    final versionCode = (versionMap?['version_code'] as num?)?.toInt() ?? 0;
    final updateStatus = AppUpdateStatus.fromString(versionMap?['update_status']?.toString());

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        backgroundColor: AppDesignTokens.surface(context),
        elevation: 0,
        title: const Text(
          'الملف الإداري الشامل للطالب',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 1. Large Clinical Header
                Container(
                  padding: const EdgeInsets.all(20),
                  color: AppDesignTokens.surface(context),
                  child: Row(
                    children: [
                      AppAvatar(
                        imageUrl: avatarUrl,
                        name: name,
                        size: AppAvatarSize.xlarge,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppDesignTokens.textPrimary(context),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const AppBadge(
                                  label: 'طالب امتياز',
                                  variant: AppBadgeVariant.neutral,
                                  size: AppBadgeSize.small,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (code.isNotEmpty)
                              Text(
                                'الكود الجامعي: $code',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppDesignTokens.textSecondary(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                // Presence Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isEffectivelyOnline
                                        ? AppDesignTokens.success.withOpacity(0.12)
                                        : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isEffectivelyOnline
                                          ? AppDesignTokens.success.withOpacity(0.4)
                                          : AppDesignTokens.borderSubtle(context),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isEffectivelyOnline
                                              ? AppDesignTokens.success
                                              : AppDesignTokens.textMuted(context),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        presenceText,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isEffectivelyOnline
                                              ? AppDesignTokens.success
                                              : AppDesignTokens.textSecondary(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // App Version Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: updateStatus == AppUpdateStatus.upToDate
                                        ? AppDesignTokens.success.withOpacity(0.12)
                                        : (updateStatus == AppUpdateStatus.outdated
                                            ? AppDesignTokens.warning.withOpacity(0.12)
                                            : Colors.grey.withOpacity(0.12)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: updateStatus == AppUpdateStatus.upToDate
                                          ? AppDesignTokens.success.withOpacity(0.4)
                                          : (updateStatus == AppUpdateStatus.outdated
                                              ? AppDesignTokens.warning.withOpacity(0.4)
                                              : AppDesignTokens.borderSubtle(context)),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        platform == 'android'
                                            ? Icons.android_rounded
                                            : (platform == 'ios' ? Icons.apple_rounded : Icons.language_rounded),
                                        size: 14,
                                        color: updateStatus == AppUpdateStatus.upToDate
                                            ? AppDesignTokens.success
                                            : (updateStatus == AppUpdateStatus.outdated
                                                ? AppDesignTokens.warning
                                                : AppDesignTokens.textSecondary(context)),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        versionCode > 0 ? '$versionName (#$versionCode) • ${updateStatus.displayNameAr}' : 'الإصدار غير معروف',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: updateStatus == AppUpdateStatus.upToDate
                                              ? AppDesignTokens.success
                                              : (updateStatus == AppUpdateStatus.outdated
                                                  ? AppDesignTokens.warning
                                                  : AppDesignTokens.textSecondary(context)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Classification Badge (Clickable)
                                Builder(builder: (context) {
                                  final rawCls = _profileData?['student_classification'];
                                  final cls = StudentClassification.fromString(rawCls?.toString());
                                  return InkWell(
                                    onTap: _showEditClassificationDialog,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppDesignTokens.primary.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppDesignTokens.primary.withOpacity(0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            cls != null ? cls.displayNameAr : '🏷️ غير مصنف (اضغط للتصنيف)',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppDesignTokens.primary),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.arrow_drop_down, size: 16, color: AppDesignTokens.primary),
                                        ],
                                      ),
                                    ),
                                  );
                                }),

                                // GPA Badge with Edit Button
                                Builder(builder: (context) {
                                  final rawGpa = _profileData?['gpa'];
                                  final gpaVal = (rawGpa is num) ? rawGpa.toDouble() : double.tryParse(rawGpa?.toString() ?? '');
                                  return InkWell(
                                    onTap: _showEditGpaDialog,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.amber.withOpacity(0.5)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.school_rounded, size: 14, color: Colors.amber),
                                          const SizedBox(width: 6),
                                          Text(
                                            'GPA: ${gpaVal != null && gpaVal > 0 ? gpaVal.toStringAsFixed(2) : "غير مسجل"}',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text('تعديل GPA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.brown)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),

                                // Dynamic Group Badge (Clickable to change group)
                                Builder(builder: (context) {
                                  final grpName = _profileData?['group_name'] ?? _profileData?['student_group'] ?? 'بدون جروب';
                                  return InkWell(
                                    onTap: _showChangeGroupDialog,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.indigo.withOpacity(0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.group_work_outlined, size: 14, color: Colors.indigo),
                                          const SizedBox(width: 6),
                                          Text(
                                            'الجروب: $grpName ✏️',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Tab Bar
                Container(
                  color: AppDesignTokens.surface(context),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: AppDesignTokens.primary,
                    indicatorWeight: 3,
                    labelColor: AppDesignTokens.primary,
                    unselectedLabelColor: AppDesignTokens.textSecondary(context),
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: _tabs.map((title) => Tab(text: title)).toList(),
                  ),
                ),

                const Divider(height: 1),

                // 3. Tab Bar View Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildAcademicTab(),
                      _buildTodayShiftTab(),
                      _buildAttendanceTab(),
                      _buildEvaluationsTab(),
                      _buildRewardsTab(),
                      _buildPenaltiesTab(),
                      _buildQuizzesTab(),
                      _buildAppDeviceTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    final rawGpa = _profileData?['gpa'];
    final gpaVal = (rawGpa is num) ? rawGpa.toDouble() : double.tryParse(rawGpa?.toString() ?? '');
    final gpa = gpaVal != null && gpaVal > 0 ? gpaVal.toStringAsFixed(2) : 'غير مسجل';
    final group = _profileData?['group_name'] ?? _profileData?['student_group'] ?? 'بدون جروب';
    final deptName = _profileData?['department_name'] ?? 'غير مخصص';
    final docName = _profileData?['supervisor_doctor_name'] ?? 'غير مخصص';
    final hasPrevExp = _profileData?['previous_work_experience'] == true;
    final prevWorkplace = _profileData?['previous_workplace'] ?? 'غير محدد';
    final prevWorkDept = _profileData?['previous_work_department'] ?? 'غير محدد';
    final prevWorkDetails = _profileData?['previous_work_experience_details'] ?? '';

    final attStats = _profileData?['attendance_stats'] as Map<String, dynamic>?;
    final attPct = attStats?['attendance_percentage']?.toString() ?? '100.0';
    final rewardsList = _profileData?['rewards'] as List? ?? [];
    final penaltiesList = _profileData?['penalties'] as List? ?? [];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _showEditGpaDialog,
                borderRadius: BorderRadius.circular(12),
                child: _buildMetricCard('المعدل التراكمي (GPA) ✏️', gpa, Icons.school_rounded, AppDesignTokens.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricCard('الجروب الحالي', group, Icons.group_work_rounded, Colors.indigo)),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricCard('نسبة الحضور', '%$attPct', Icons.event_available_rounded, AppDesignTokens.success)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildMetricCard('المكافآت المعتمدة', '${rewardsList.length}', Icons.military_tech_rounded, Colors.amber)),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricCard('الجزاءات والتنبيهات', '${penaltiesList.length}', Icons.warning_amber_rounded, AppDesignTokens.danger)),
          ],
        ),
        const SizedBox(height: 20),

        // Assignment Card: Group, Department, Supervisor Doctor
        _buildSectionTitle('التوزيعة والجروب السريري'),
        const SizedBox(height: 8),
        AppCard(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.group_work_rounded, size: 18, color: Colors.indigo),
                        const SizedBox(width: 8),
                        Text('الجروب التدريبي: ', style: TextStyle(fontSize: 13, color: AppDesignTokens.textSecondary(context))),
                        Text(group, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                      label: const Text('تغيير الجروب', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: _showChangeGroupDialog,
                    ),
                  ],
                ),
              ),
              const Divider(height: 8),
              _buildInfoRow('القسم السريري الحالي', deptName),
              _buildInfoRow('الطبيب المشرف', docName),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Previous Work Experience Card
        _buildSectionTitle('الخبرة العملية السابقة'),
        const SizedBox(height: 8),
        AppCard(
          child: Column(
            children: [
              _buildInfoRow('اشتغلت قبل كده؟', hasPrevExp ? 'أيوه (لديه خبرة عمل سابقة)' : 'لا (بدون خبرة سابقة)'),
              if (hasPrevExp) ...[
                _buildInfoRow('مكان العمل السابق', prevWorkplace),
                _buildInfoRow('القسم السابق', prevWorkDept),
                if (prevWorkDetails.isNotEmpty)
                  _buildInfoRow('تفاصيل الخبرة والمهام', prevWorkDetails),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        _buildSectionTitle('ملخص النشاط وحالة الحساب'),
        const SizedBox(height: 8),
        AppCard(
          child: Column(
            children: [
              _buildInfoRow('البريد الإلكتروني', _profileData?['email'] ?? 'غير متوفر'),
              _buildInfoRow('رقم الهاتف', _profileData?['phone_number'] ?? 'غير متوفر'),
              _buildInfoRow('حالة الحساب', _profileData?['registration_status'] == 'approved' ? 'معتمد رسمي' : 'قيد المراجعة'),
              _buildInfoRow('تاريخ التسجيل', _formatDateTime(_profileData?['created_at'])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAcademicTab() {
    final rawCls = _profileData?['student_classification'];
    final cls = StudentClassification.fromString(rawCls?.toString());
    final rawGpa = _profileData?['gpa'];
    final gpaVal = (rawGpa is num) ? rawGpa.toDouble() : double.tryParse(rawGpa?.toString() ?? '');
    final gpa = gpaVal != null && gpaVal > 0 ? gpaVal.toStringAsFixed(2) : 'غير مسجل';
    final group = _profileData?['group_name'] ?? _profileData?['student_group'] ?? 'بدون جروب';
    final hasPrevExp = _profileData?['previous_work_experience'] == true;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('البيانات الأكاديمية والسريرية'),
                  TextButton.icon(
                    onPressed: _showEditGpaDialog,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('تعديل GPA'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow('الاسم بالكامل', _profileData?['full_name'] ?? '-'),
              _buildInfoRow('الكود الجامعي', _profileData?['university_code'] ?? '-'),
              _buildInfoRow('المعدل التراكمي (GPA)', gpa),
              _buildInfoRow('تصنيف الطالب الإداري', cls != null ? cls.displayNameAr : 'غير مصنف'),
              _buildInfoRow('الجروب المسكن عليه', group),
              _buildInfoRow('القسم المشرف', _profileData?['department_name'] ?? 'غير مخصص'),
              _buildInfoRow('الطبيب المشرف', _profileData?['supervisor_doctor_name'] ?? 'غير مخصص'),
              _buildInfoRow('خبرة عمل سابقة', hasPrevExp ? 'نعم (لديه خبرة)' : 'لا'),
              if (hasPrevExp) ...[
                _buildInfoRow('مكان العمل', _profileData?['previous_workplace'] ?? '-'),
                _buildInfoRow('القسم', _profileData?['previous_work_department'] ?? '-'),
                if ((_profileData?['previous_work_experience_details'] ?? '').isNotEmpty)
                  _buildInfoRow('تفاصيل الخبرة', _profileData?['previous_work_experience_details']),
              ],
              _buildInfoRow('الرقم القومي (سري للـ Super Admin)', _profileData?['national_id'] ?? '••••••••••••••'),
              _buildInfoRow('محل الإقامة', _profileData?['residence_address'] ?? 'محافظة مطروح'),
              _buildInfoRow('جهة الاتصال في الطوارئ', _profileData?['emergency_contact'] ?? 'غير مسجل'),
              _buildInfoRow('البريد الإلكتروني', _profileData?['email'] ?? '-'),
              _buildInfoRow('رقم الهاتف', _profileData?['phone_number'] ?? '-'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTodayShiftTab() {
    final shift = _profileData?['today_shift'] as Map<String, dynamic>?;
    final isOff = shift?['status'] == 'off';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('التوزيعة السريرية لليوم'),
              const SizedBox(height: 16),
              if (isOff)
                const AppEmptyState(
                  icon: Icons.hotel_rounded,
                  title: 'يوم راحة (Off)',
                  message: 'لا توجد نبطشية مسجلة للطالب في جدول اليوم.',
                )
              else ...[
                _buildInfoRow('القسم السريري', shift?['department'] ?? '-'),
                _buildInfoRow('نوع النبطشية', shift?['shift'] ?? '-'),
                _buildInfoRow('مواعيد النبطشية', '${shift?["start_time"] ?? ""} → ${shift?["end_time"] ?? ""}'),
                _buildInfoRow('الطبيب المشرف المسؤول', shift?['supervisor'] ?? 'غير محدد'),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceTab() {
    final stats = _profileData?['attendance_stats'] as Map<String, dynamic>?;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricCard('إجمالي الأيام', '${stats?["total"] ?? 0}', Icons.calendar_month_rounded, AppDesignTokens.primary)),
            const SizedBox(width: 10),
            Expanded(child: _buildMetricCard('حضور', '${stats?["present"] ?? 0}', Icons.check_circle_rounded, AppDesignTokens.success)),
            const SizedBox(width: 10),
            Expanded(child: _buildMetricCard('تأخير', '${stats?["late"] ?? 0}', Icons.schedule_rounded, AppDesignTokens.warning)),
            const SizedBox(width: 10),
            Expanded(child: _buildMetricCard('غياب', '${stats?["absent"] ?? 0}', Icons.cancel_rounded, AppDesignTokens.danger)),
          ],
        ),
        const SizedBox(height: 20),
        AppCard(
          child: Column(
            children: [
              _buildInfoRow('نسبة الحضور الإجمالية', '%${stats?["attendance_percentage"] ?? "100.0"}'),
              _buildInfoRow('آخر تسجيل حضور', _formatDateTime(stats?['last_check_in'])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEvaluationsTab() {
    final list = _profileData?['evaluations'] as List? ?? [];
    if (list.isEmpty) {
      return const AppEmptyState(
        icon: Icons.rate_review_rounded,
        title: 'لا توجد تقييمات مسجلة',
        message: 'لم يقم الأطباء المشرفون بإدخال تقييمات سريرية لهذا الطالب بعد.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final item = list[i] as Map<String, dynamic>;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('الطبيب: ${item["doctor_name"] ?? "مشرف سريري"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    AppBadge(label: 'درجة: ${item["score"] ?? 0}/100', variant: AppBadgeVariant.info),
                  ],
                ),
                if (item['notes'] != null && item['notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('ملاحظات: ${item["notes"]}', style: TextStyle(fontSize: 13, color: AppDesignTokens.textSecondary(context))),
                ],
                const SizedBox(height: 6),
                Text(_formatDateTime(item['created_at']), style: TextStyle(fontSize: 11, color: AppDesignTokens.textMuted(context))),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRewardsTab() {
    final list = _profileData?['rewards'] as List? ?? [];
    if (list.isEmpty) {
      return const AppEmptyState(
        icon: Icons.military_tech_rounded,
        title: 'لا توجد مكافآت مسجلة',
        message: 'لا توجد مكافآت تميز مضافة لهذا الطالب.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final item = list[i] as Map<String, dynamic>;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['reason'] ?? 'مكافأة تميز سريري', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('المشرف: ${item["created_by_name"] ?? "-"} • ${_formatDateTime(item["created_at"])}', style: TextStyle(fontSize: 12, color: AppDesignTokens.textMuted(context))),
                    ],
                  ),
                ),
                AppBadge(label: '+${item["points"] ?? 0} نقطة', variant: AppBadgeVariant.success),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPenaltiesTab() {
    final list = _profileData?['penalties'] as List? ?? [];
    if (list.isEmpty) {
      return const AppEmptyState(
        icon: Icons.verified_user_rounded,
        title: 'سجل الجزاءات نظيف',
        message: 'لا توجد أي جزاءات أو تنبيهات مسجلة على هذا الطالب.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final item = list[i] as Map<String, dynamic>;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppDesignTokens.danger.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.warning_amber_rounded, color: AppDesignTokens.danger, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['reason'] ?? 'جزاء إداري / سريري', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('درجة الخطورة: ${item["severity"] ?? "عادي"} • ${_formatDateTime(item["created_at"])}', style: TextStyle(fontSize: 12, color: AppDesignTokens.textMuted(context))),
                    ],
                  ),
                ),
                AppBadge(label: '-${item["points_deducted"] ?? item["points"] ?? 0} نقطة', variant: AppBadgeVariant.danger),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuizzesTab() {
    final list = _profileData?['quizzes'] as List? ?? [];
    if (list.isEmpty) {
      return const AppEmptyState(
        icon: Icons.quiz_rounded,
        title: 'لا توجد اختبارات مجتازة',
        message: 'لم يقم الطالب بأداء أي اختبارات في بنك المعرفة بعد.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final item = list[i] as Map<String, dynamic>;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('اختبار سريري / تقييمي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(_formatDateTime(item['completed_at']), style: TextStyle(fontSize: 12, color: AppDesignTokens.textMuted(context))),
                  ],
                ),
                AppBadge(
                  label: '${item["score"] ?? 0} / ${item["max_score"] ?? 100}',
                  variant: AppBadgeVariant.info,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppDeviceTab() {
    final versionMap = _profileData?['app_version'] as Map<String, dynamic>?;
    final platform = versionMap?['platform']?.toString() ?? 'android';
    final versionName = versionMap?['version_name']?.toString() ?? 'غير معروف';
    final versionCode = (versionMap?['version_code'] as num?)?.toInt() ?? 0;
    final deviceInfo = versionMap?['device_info']?.toString() ?? '';
    final latestVersion = versionMap?['latest_version_name']?.toString() ?? '';
    final latestCode = (versionMap?['latest_version_code'] as num?)?.toInt() ?? 0;
    final updateStatus = AppUpdateStatus.fromString(versionMap?['update_status']?.toString());
    final reportedAt = versionMap?['last_reported_at'];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('معلومات التطبيق والجهاز'),
              const SizedBox(height: 14),
              _buildInfoRow('نظام التشغيل / المنصة', platform.toUpperCase()),
              _buildInfoRow('الإصدار المثبت لدى الطالب', '$versionName (#$versionCode)'),
              _buildInfoRow('أحدث إصدار معتمد للمنصة', latestCode > 0 ? '$latestVersion (#$latestCode)' : 'غير محدد'),
              _buildInfoRow('حالة التحديث', updateStatus.displayNameAr),
              if (deviceInfo.isNotEmpty) _buildInfoRow('وصف الجهاز / المتصفح', deviceInfo),
              _buildInfoRow('آخر اتصال بالخادم', _formatDateTime(reportedAt)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11.5, color: AppDesignTokens.textSecondary(context), fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppDesignTokens.textPrimary(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: AppDesignTokens.textPrimary(context),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: AppDesignTokens.textSecondary(context))),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppDesignTokens.textPrimary(context)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(dynamic dateTimeStr) {
    if (dateTimeStr == null) return 'غير متوفر';
    final dt = DateTime.tryParse(dateTimeStr.toString());
    if (dt == null) return 'غير متوفر';
    final cairo = AppTimezoneHelper.toCairo(dt);
    return DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(cairo);
  }
}
