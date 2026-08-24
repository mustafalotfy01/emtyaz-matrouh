import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/student_shift_status_model.dart';
import '../../../core/models/user_presence_model.dart';
import '../../../core/services/presence_service.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/utils/timezone_helper.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../auth/models/user_profile.dart';
import '../services/user_profile_details_service.dart';

class UserProfileDetailsScreen extends StatefulWidget {
  final String userId;
  final String? initialName;
  final String? initialAvatarUrl;
  final UserRole? initialRole;
  final String? initialCode;

  const UserProfileDetailsScreen({
    super.key,
    required this.userId,
    this.initialName,
    this.initialAvatarUrl,
    this.initialRole,
    this.initialCode,
  });

  /// Opens the user profile modal
  static Future<void> show(
    BuildContext context, {
    required String userId,
    String? initialName,
    String? initialAvatarUrl,
    UserRole? initialRole,
    String? initialCode,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UserProfileDetailsScreen(
        userId: userId,
        initialName: initialName,
        initialAvatarUrl: initialAvatarUrl,
        initialRole: initialRole,
        initialCode: initialCode,
      ),
    );
  }

  @override
  State<UserProfileDetailsScreen> createState() => _UserProfileDetailsScreenState();
}

class _UserProfileDetailsScreenState extends State<UserProfileDetailsScreen> {
  UserProfileDetailsData? _data;
  bool _isLoading = true;
  StreamSubscription<Map<String, UserPresenceModel>>? _presenceSubscription;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _subscribeToLivePresence();
  }

  @override
  void dispose() {
    _presenceSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToLivePresence() {
    _presenceSubscription = PresenceService.instance.presenceStream.listen((presenceMap) {
      if (mounted && presenceMap.containsKey(widget.userId)) {
        final updatedPresence = presenceMap[widget.userId];
        if (updatedPresence != null && _data != null) {
          setState(() {
            _data = _data!.copyWithPresence(updatedPresence);
          });
        }
      }
    });
  }

  Future<void> _loadProfile() async {
    final result = await UserProfileDetailsService.loadUserProfileDetails(widget.userId);
    if (mounted) {
      setState(() {
        _data = result;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _data?.fullName ?? widget.initialName ?? 'مستخدم المنظومة';
    final avatarUrl = _data?.avatarUrl ?? widget.initialAvatarUrl;
    final role = _data?.role ?? widget.initialRole ?? UserRole.student;
    final code = _data?.code ?? widget.initialCode;
    final presence = _data?.presence;
    final canViewPresence = _data?.canViewPresence ?? false;
    final isOnline = presence?.isEffectivelyOnline ?? false;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: AppDesignTokens.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppDesignTokens.border(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppDesignTokens.border(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Avatar + Online Indicator
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: AppDesignTokens.primary.withOpacity(0.12),
                        backgroundImage: (avatarUrl != null && avatarUrl.trim().isNotEmpty)
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: (avatarUrl == null || avatarUrl.trim().isEmpty)
                            ? Text(
                                name.isNotEmpty ? name.substring(0, 1) : 'U',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppDesignTokens.primary,
                                ),
                              )
                            : null,
                      ),
                      if (isOnline && canViewPresence)
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppDesignTokens.surface(context),
                              width: 3,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2. Name & Role Badge
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppDesignTokens.textPrimary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),

                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      AppBadge(
                        label: role.displayNameAr,
                        variant: _getRoleBadgeVariant(role),
                        size: AppBadgeSize.small,
                      ),
                      if (code != null && code.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppDesignTokens.bg(context),
                            borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                            border: Border.all(color: AppDesignTokens.border(context)),
                          ),
                          child: Text(
                            'كود: $code',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppDesignTokens.textSecondary(context),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 3. Online Status / Last Seen (Subtle dot + Arabic text)
                  if (canViewPresence) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isOnline) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'متصل الآن',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ] else ...[
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: AppDesignTokens.textMuted(context),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            presence?.formattedStatusArabic ?? 'آخر ظهور غير متاح',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppDesignTokens.textSecondary(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    const SizedBox(height: 12),
                  ],

                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // 4. Loading indicator or role-tailored cards
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                    )
                  else ...[
                    // Student: Today's live shift & department
                    if (role == UserRole.student) ...[
                      _buildStudentShiftCard(context, _data?.shiftStatus),
                      const SizedBox(height: 12),
                      _buildStudentAcademicCard(context, _data),
                    ],

                    // Doctor: Supervised departments
                    if (role == UserRole.evaluatingDoctor) ...[
                      _buildDoctorSupervisionCard(context, _data?.supervisedDepartments ?? []),
                    ],

                    // Leader / Admin info
                    if (role == UserRole.leader || role == UserRole.superAdmin) ...[
                      _buildStaffInfoCard(context, role),
                    ],
                  ],

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                        ),
                        side: BorderSide(color: AppDesignTokens.border(context)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'إغلاق',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppDesignTokens.textPrimary(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBadgeVariant _getRoleBadgeVariant(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return AppBadgeVariant.danger;
      case UserRole.leader:
        return AppBadgeVariant.warning;
      case UserRole.evaluatingDoctor:
        return AppBadgeVariant.primary;
      case UserRole.student:
        return AppBadgeVariant.neutral;
    }
  }

  Widget _buildStudentShiftCard(BuildContext context, StudentShiftStatus? shift) {
    final s = shift ?? const StudentShiftStatus(category: ShiftStatusCategory.noAssignment);
    final cairoNow = AppTimezoneHelper.serverNowCairo;
    final todayArabic = DateFormat('EEEE، d MMMM', 'ar').format(cairoNow);

    return AppCard(
      padding: const EdgeInsets.all(14),
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 16, color: AppDesignTokens.primary),
                  const SizedBox(width: 6),
                  Text(
                    'توزيعة اليوم ($todayArabic)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppDesignTokens.textPrimary(context),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: s.statusBadgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                  border: Border.all(color: s.statusBadgeColor.withOpacity(0.3)),
                ),
                child: Text(
                  s.categoryTitleArabic,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: s.statusBadgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Department & Shift Details
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'القسم الطبي:',
                      style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.departmentName ?? 'غير محدد',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppDesignTokens.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نوع النوبتجية:',
                      style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.shiftDisplayNameArabic,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppDesignTokens.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (s.formattedTimeInterval.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 14, color: AppDesignTokens.textMuted(context)),
                const SizedBox(width: 4),
                Text(
                  s.formattedTimeInterval,
                  style: TextStyle(fontSize: 11.5, color: AppDesignTokens.textSecondary(context)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentAcademicCard(BuildContext context, UserProfileDetailsData? data) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      variant: AppCardVariant.standard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school_outlined, size: 16, color: AppDesignTokens.primary),
              const SizedBox(width: 6),
              Text(
                'البيانات الأكاديمية والسريرية',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppDesignTokens.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              if (data?.assignedGroup != null && data!.assignedGroup!.isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المجموعة / الفريق:',
                        style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'فريق ${data.assignedGroup}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppDesignTokens.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              if (data?.leaderboardPoints != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'نقاط التميز السريري:',
                        style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${data!.leaderboardPoints} نقطة',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppDesignTokens.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorSupervisionCard(BuildContext context, List<DoctorDepartmentSupervision> depts) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_hospital_outlined, size: 16, color: AppDesignTokens.primary),
              const SizedBox(width: 6),
              Text(
                'الأقسام الخاضعة للإشراف الأكاديمي',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppDesignTokens.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          if (depts.isEmpty)
            Text(
              'لا توجد أقسام مسندة حالياً لهذا المشرف.',
              style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context)),
            )
          else
            ...depts.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
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
                          'مسؤول عن: قسم ${d.departmentName}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppDesignTokens.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          d.staffingRequirementText,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppDesignTokens.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildStaffInfoCard(BuildContext context, UserRole role) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      variant: AppCardVariant.standard,
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, size: 20, color: AppDesignTokens.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              role == UserRole.leader
                  ? 'عضو في الهيئة القيادية لدفعة طلاب الامتياز.'
                  : 'عضو في الإدارة العليا لمنظومة امتياز مطروح.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppDesignTokens.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
