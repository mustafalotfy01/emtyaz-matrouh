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
import '../services/admin_student_management_service.dart';

class AdminStudentProfileScreen extends StatefulWidget {
  final String studentId;
  final String initialName;
  final String? initialAvatarUrl;
  final String? initialCode;

  const AdminStudentProfileScreen({
    super.key,
    required this.studentId,
    required this.initialName,
    this.initialAvatarUrl,
    this.initialCode,
  });

  static Future<void> show(
    BuildContext context, {
    required String studentId,
    required String initialName,
    String? initialAvatarUrl,
    String? initialCode,
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
        _profileData = data;
        _isLoading = false;
      });
    }
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
    final gpa = _profileData?['gpa']?.toString() ?? 'غير محدد';
    final group = _profileData?['student_group'] ?? 'A';
    final attStats = _profileData?['attendance_stats'] as Map<String, dynamic>?;
    final attPct = attStats?['attendance_percentage']?.toString() ?? '100.0';
    final rewardsList = _profileData?['rewards'] as List? ?? [];
    final penaltiesList = _profileData?['penalties'] as List? ?? [];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricCard('المعدل التراكمي (GPA)', gpa, Icons.school_rounded, AppDesignTokens.primary)),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricCard('المجموعة', 'Group $group', Icons.group_rounded, Colors.indigo)),
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
        _buildSectionTitle('ملخص النشاط الأخير'),
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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('البيانات الأكاديمية والشخصية'),
              const SizedBox(height: 12),
              _buildInfoRow('الاسم بالكامل', _profileData?['full_name'] ?? '-'),
              _buildInfoRow('الكود الجامعي', _profileData?['university_code'] ?? '-'),
              _buildInfoRow('المعدل التراكمي (GPA)', _profileData?['gpa']?.toString() ?? 'غير محدد'),
              _buildInfoRow('المجموعة التدريبية', 'المجموعة ${_profileData?['student_group'] ?? "A"}'),
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
