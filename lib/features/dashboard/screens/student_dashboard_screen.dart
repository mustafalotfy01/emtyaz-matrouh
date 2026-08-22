import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/platform_service.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/utils/distance_calculator.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../fingerprint/models/fingerprint_request.dart';
import '../../fingerprint/providers/fingerprint_provider.dart';
import '../../groups/screens/group_selection_screen.dart';
import '../../handover/screens/shift_handover_screen.dart';
import '../../leaderboard/screens/clinical_leaderboard_screen.dart';
import '../../quizzes/screens/quiz_list_screen.dart';
import '../../roster/models/roster_entry.dart';
import '../../roster/providers/final_roster_provider.dart';

class StudentDashboardScreen extends ConsumerWidget {
  final Function(int) onNavigateTab;

  const StudentDashboardScreen({super.key, required this.onNavigateTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final attendanceState = ref.watch(attendanceProvider);
    final finalApprovedShifts = ref.watch(studentFinalApprovedRosterProvider).value ?? [];
    final activeFingerprintReq = ref.watch(studentActiveFingerprintRequestProvider);
    final l10n = context.l10n;

    final studentName = user?.fullName.isNotEmpty == true
        ? user!.fullName
        : 'طالب امتياز';
    final groupName = 'طالب امتياز سريري';
    final universityCode = user?.universityCode.isNotEmpty == true
        ? user!.universityCode
        : (user != null ? 'NUR-${user.id.substring(0, 6)}' : 'دفعة 2026');

    final now = DateTime.now();
    final todayShift = finalApprovedShifts.where((s) =>
        s.shiftDate.year == now.year &&
        s.shiftDate.month == now.month &&
        s.shiftDate.day == now.day).firstOrNull;

    final longCount = finalApprovedShifts.where((s) => s.shiftType == ShiftType.long).length;
    final nightCount = finalApprovedShifts.where((s) => s.shiftType == ShiftType.night).length;
    final morningCount = finalApprovedShifts.where((s) => s.shiftType == ShiftType.morning).length;
    final totalAssigned = finalApprovedShifts.length;

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Clean Clinical Top Header ──────────────────────────────
              _buildTopHeader(
                context,
                l10n: l10n,
                studentName: studentName,
                groupName: groupName,
                universityCode: universityCode,
                avatarUrl: user?.avatarUrl,
              ),

              if (activeFingerprintReq != null) ...[
                const SizedBox(height: 12),
                _buildUrgentFingerprintBanner(context, ref, activeFingerprintReq),
              ],

              const SizedBox(height: 14),

              // ── 1.1 Restrained Gold Leaderboard Banner ─────────────────────
              _buildLeaderboardBanner(context),

              const SizedBox(height: 16),

              // ── 2. Today's Clinical Shift Card ────────────────────────────
              _buildTodayShiftCard(
                context,
                l10n: l10n,
                attendanceState: attendanceState,
                todayShift: todayShift,
                onCheckinTap: () => onNavigateTab(3), // Attendance tab (index 3)
                onViewRosterTap: () => onNavigateTab(1), // Roster tab (index 1)
              ),

              const SizedBox(height: 18),

              // ── 3. Monthly Roster & 36-Hour Progress ──────────────────────
              _buildMonthSummaryCard(
                context,
                l10n: l10n,
                total: totalAssigned,
                longCount: longCount,
                nightCount: nightCount,
                morningCount: morningCount,
                onViewRosterTap: () => onNavigateTab(1), // Roster tab (index 1)
              ),

              const SizedBox(height: 20),

              // ── 4. Quick Actions Grid (2x2 Clean Clinical Tiles) ──────────
              AppSectionHeader(
                title: l10n.quickAccessTitle,
                subtitle: l10n.quickAccessSubtitle,
              ),
              const SizedBox(height: 8),
              _buildQuickActionsGrid(context, l10n: l10n),

              const SizedBox(height: 20),

              // ── 5. Daily Clinical Case / Quiz Card ────────────────────────
              _buildDailyQuizCard(
                context,
                l10n: l10n,
                onStartQuiz: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QuizListScreen()),
                  );
                },
              ),

              const SizedBox(height: 20),

              // ── 6. Nursing Procedures Library Carousel ────────────────────
              AppSectionHeader(
                title: l10n.whatToLearnTitle,
                subtitle: l10n.whatToLearnSubtitle,
                actionText: l10n.libraryViewAll,
                onActionTap: () => onNavigateTab(4), // Knowledge tab (index 4)
              ),
              const SizedBox(height: 10),
              _buildLearningCarousel(context),

              const SizedBox(height: 20),

              // ── 7. Shift Activity Log ─────────────────────────────────────
              AppSectionHeader(
                title: l10n.recentActivityTitle,
                subtitle: l10n.recentActivitySubtitle,
              ),
              const SizedBox(height: 8),
              _buildRecentActivityList(context, l10n: l10n, attendanceState: attendanceState),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Header ─────────────────────────────────────────────────────────────
  Widget _buildTopHeader(
    BuildContext context, {
    required AppLocalizations l10n,
    required String studentName,
    required String groupName,
    required String universityCode,
    String? avatarUrl,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            AppAvatar(
              name: studentName,
              imageUrl: avatarUrl,
              size: AppAvatarSize.medium,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.greetingMorning(studentName.split(' ')[0]),
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: AppDesignTokens.textPrimary(context),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      l10n.roleStudent,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppDesignTokens.textSecondary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      ' • $groupName',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppDesignTokens.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // University Code Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppDesignTokens.surfaceMuted(context),
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
            border: Border.all(color: AppDesignTokens.border(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.badge_outlined, size: 13, color: AppDesignTokens.primary),
              const SizedBox(width: 5),
              Text(
                universityCode,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: AppDesignTokens.textPrimary(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Today's Clinical Shift Card ────────────────────────────────────────────
  Widget _buildTodayShiftCard(
    BuildContext context, {
    required AppLocalizations l10n,
    required AttendanceState attendanceState,
    required RosterEntry? todayShift,
    required VoidCallback onCheckinTap,
    required VoidCallback onViewRosterTap,
  }) {
    final isCheckedIn = attendanceState.activeRecord != null;

    if (todayShift == null) {
      return AppCard(
        variant: AppCardVariant.standard,
        padding: const EdgeInsets.all(18),
        child: Column(
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
                        color: AppDesignTokens.slateMuted.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                      ),
                      child: const Icon(
                        Icons.weekend_rounded,
                        size: 16,
                        color: AppDesignTokens.slateMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.todayShiftTitle,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AppDesignTokens.textPrimary(context),
                      ),
                    ),
                  ],
                ),
                const AppBadge(
                  label: 'يوم راحة (Off)',
                  icon: Icons.event_available_rounded,
                  variant: AppBadgeVariant.neutral,
                  size: AppBadgeSize.medium,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'أنت لست على الروستر اليوم',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppDesignTokens.textPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'لا يوجد لديك شيفت معتمد مسجل لتاريخ اليوم. استمتع بيوم الراحة أو راجع جدول الروستر الشهري.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppDesignTokens.textSecondary(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              text: 'عرض الروستر الشهري',
              icon: Icons.calendar_month_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: onViewRosterTap,
            ),
          ],
        ),
      );
    }

    final shiftType = todayShift.shiftType;
    final shiftInitial = shiftType == ShiftType.night
        ? '${l10n.shiftNightShort} (12h)'
        : (shiftType == ShiftType.long ? '${l10n.shiftLongShort} (12h)' : '${l10n.shiftMorningShort} (6h)');
    final shiftBadgeVariant = shiftType == ShiftType.night
        ? AppBadgeVariant.shiftNight
        : (shiftType == ShiftType.long ? AppBadgeVariant.shiftLong : AppBadgeVariant.shiftMorning);

    final shiftTimeText = shiftType == ShiftType.morning
        ? '08:00 ص - 02:00 م (6 ساعات تدريبية)'
        : (shiftType == ShiftType.night
            ? '08:00 م - 08:00 ص (12 ساعة تدريبية)'
            : '08:00 ص - 08:00 م (12 ساعة تدريبية)');

    return AppCard(
      variant: AppCardVariant.accentTeal,
      padding: const EdgeInsets.all(18),
      child: Column(
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
                      color: AppDesignTokens.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                    ),
                    child: const Icon(
                      Icons.local_hospital_rounded,
                      size: 16,
                      color: AppDesignTokens.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.todayShiftTitle,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: AppDesignTokens.textPrimary(context),
                    ),
                  ),
                ],
              ),
              AppBadge(
                label: isCheckedIn ? l10n.checkedInStatus : shiftInitial,
                icon: isCheckedIn ? Icons.check_circle_rounded : Icons.access_time_rounded,
                variant: isCheckedIn ? AppBadgeVariant.success : shiftBadgeVariant,
                size: AppBadgeSize.medium,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            todayShift.departmentName.isNotEmpty == true
                ? '${l10n.hospitalName} — ${todayShift.departmentName}'
                : '${l10n.hospitalName} — ${l10n.deptEmergency}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppDesignTokens.textPrimary(context),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 14, color: AppDesignTokens.textSecondary(context)),
              const SizedBox(width: 5),
              Text(
                shiftTimeText,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppDesignTokens.textSecondary(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppButton(
            text: isCheckedIn ? l10n.viewCheckInDetails : l10n.checkInNow,
            icon: isCheckedIn ? Icons.verified_rounded : Icons.fingerprint_rounded,
            variant: isCheckedIn ? AppButtonVariant.secondary : AppButtonVariant.primary,
            onPressed: onCheckinTap,
          ),
        ],
      ),
    );
  }

  // ── Month Summary Card ─────────────────────────────────────────────────────
  Widget _buildMonthSummaryCard(
    BuildContext context, {
    required AppLocalizations l10n,
    required int total,
    required int longCount,
    required int nightCount,
    required int morningCount,
    required VoidCallback onViewRosterTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: AppDesignTokens.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.monthlyRosterSummary,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppDesignTokens.textPrimary(context),
                    ),
                  ),
                ],
              ),
              AppBadge(
                label: l10n.daysCount(total, 12),
                variant: total >= 12 ? AppBadgeVariant.success : AppBadgeVariant.warning,
                size: AppBadgeSize.medium,
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              // Morning Shift
              Expanded(
                child: _buildShiftStatChip(
                  context,
                  title: l10n.shiftMorningShort,
                  countText: l10n.shiftCount(morningCount),
                  icon: Icons.wb_sunny_rounded,
                  bgColor: isDark ? AppDesignTokens.shiftMorningBgDark : AppDesignTokens.shiftMorningBgLight,
                  borderColor: AppDesignTokens.shiftMorning.withOpacity(isDark ? 0.35 : 0.2),
                  accentColor: isDark ? const Color(0xFF7DD3FC) : AppDesignTokens.shiftMorning,
                ),
              ),
              const SizedBox(width: 10),
              // Long Shift
              Expanded(
                child: _buildShiftStatChip(
                  context,
                  title: l10n.shiftLongShort,
                  countText: l10n.shiftCount(longCount),
                  icon: Icons.timelapse_rounded,
                  bgColor: isDark ? AppDesignTokens.shiftLongBgDark : AppDesignTokens.shiftLongBgLight,
                  borderColor: AppDesignTokens.shiftLong.withOpacity(isDark ? 0.35 : 0.2),
                  accentColor: isDark ? const Color(0xFFC4B5FD) : AppDesignTokens.shiftLong,
                ),
              ),
              const SizedBox(width: 10),
              // Night Shift
              Expanded(
                child: _buildShiftStatChip(
                  context,
                  title: 'ليلي',
                  countText: l10n.shiftCount(nightCount),
                  icon: Icons.nightlight_round,
                  bgColor: isDark ? AppDesignTokens.shiftNightBgDark : const Color(0xFFE2E8F0),
                  borderColor: isDark ? const Color(0xFF22D3EE).withOpacity(0.3) : AppDesignTokens.navyDark.withOpacity(0.2),
                  accentColor: isDark ? const Color(0xFF22D3EE) : AppDesignTokens.navyDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          AppButton(
            text: l10n.viewFullApprovedRoster,
            icon: Icons.event_available_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: onViewRosterTap,
          ),
        ],
      ),
    );
  }

  Widget _buildShiftStatChip(
    BuildContext context, {
    required String title,
    required String countText,
    required IconData icon,
    required Color bgColor,
    required Color borderColor,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            countText,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Actions Grid ─────────────────────────────────────────────────────
  Widget _buildQuickActionsGrid(BuildContext context, {required AppLocalizations l10n}) {
    final tiles = [
      _QuickActionItem(
        title: l10n.quickActionCheckIn,
        subtitle: l10n.quickActionCheckInSub,
        icon: Icons.fingerprint_rounded,
        color: AppDesignTokens.primary,
        onTap: () => onNavigateTab(3), // Attendance tab
      ),
      _QuickActionItem(
        title: l10n.quickActionRoster,
        subtitle: l10n.quickActionRosterSub,
        icon: Icons.calendar_month_rounded,
        color: AppDesignTokens.shiftLong,
        onTap: () => onNavigateTab(1), // Roster tab
      ),
      _QuickActionItem(
        title: 'تسليم واستلام',
        subtitle: 'محاضر الشيفتات',
        icon: Icons.assignment_turned_in_rounded,
        color: AppDesignTokens.success,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ShiftHandoverScreen()),
          );
        },
      ),
      _QuickActionItem(
        title: 'تفضيلات المجموعة',
        subtitle: 'اقتراح الزملاء',
        icon: Icons.group_add_rounded,
        color: AppDesignTokens.warning,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GroupSelectionScreen()),
          );
        },
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.6,
      ),
      itemCount: tiles.length,
      itemBuilder: (context, index) {
        final tile = tiles[index];
        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          onTap: () {
            HapticFeedback.lightImpact();
            tile.onTap();
          },
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tile.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                ),
                child: Icon(tile.icon, color: tile.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tile.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppDesignTokens.textPrimary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tile.subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppDesignTokens.textSecondary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Daily Clinical Quiz Card ───────────────────────────────────────────────
  Widget _buildDailyQuizCard(BuildContext context, {required AppLocalizations l10n, required VoidCallback onStartQuiz}) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      variant: AppCardVariant.standard,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppDesignTokens.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
            ),
            child: const Icon(Icons.psychology_rounded, color: AppDesignTokens.warning, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.dailyQuizBannerTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppDesignTokens.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.dailyQuizBannerSubtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppDesignTokens.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          AppButton(
            text: l10n.startDailyQuiz,
            variant: AppButtonVariant.outline,
            size: AppButtonSize.small,
            onPressed: onStartQuiz,
          ),
        ],
      ),
    );
  }

  // ── Clinical Learning Carousel ─────────────────────────────────────────────
  Widget _buildLearningCarousel(BuildContext context) {
    final procedures = [
      _LearningItem(title: 'Foley Catheter', subtitle: 'قسطرة بولية', icon: Icons.healing_rounded, color: AppDesignTokens.primary),
      _LearningItem(title: 'NG Tube', subtitle: 'أنبوبة أنفية معدية', icon: Icons.medical_services_rounded, color: AppDesignTokens.shiftLong),
      _LearningItem(title: 'CPR Protocol', subtitle: 'إنعاش قلبي رئوي', icon: Icons.favorite_rounded, color: AppDesignTokens.danger),
      _LearningItem(title: 'IV Cannulation', subtitle: 'تركيب الكانولا', icon: Icons.vaccines_rounded, color: AppDesignTokens.info),
      _LearningItem(title: 'Emergency Triage', subtitle: 'فرز الطوارئ', icon: Icons.emergency_rounded, color: AppDesignTokens.warning),
    ];

    return SizedBox(
      height: 84,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: procedures.length,
        itemBuilder: (context, index) {
          final item = procedures[index];
          return Container(
            width: 140,
            margin: EdgeInsets.only(left: index == procedures.length - 1 ? 0 : 10),
            child: AppCard(
              padding: const EdgeInsets.all(10),
              onTap: () {
                HapticFeedback.lightImpact();
                onNavigateTab(4); // Knowledge tab
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(item.icon, size: 14, color: item.color),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AppDesignTokens.textMuted(context)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppDesignTokens.textPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppDesignTokens.textSecondary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Recent Activity Timeline ───────────────────────────────────────────────
  Widget _buildRecentActivityList(BuildContext context, {required AppLocalizations l10n, required dynamic attendanceState}) {
    final isCheckedIn = attendanceState.activeRecord != null;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          _buildActivityRow(
            context,
            icon: Icons.fingerprint_rounded,
            color: AppDesignTokens.primary,
            title: l10n.attendanceScreenTitle,
            subtitle: isCheckedIn ? '07:55 AM • ${l10n.checkedInStatus}' : l10n.checkInNow,
            time: 'اليوم',
          ),
          Divider(height: 12, color: AppDesignTokens.borderSubtle(context)),
          _buildActivityRow(
            context,
            icon: Icons.verified_rounded,
            color: AppDesignTokens.success,
            title: l10n.approvedRosterTitle,
            subtitle: l10n.statusApproved,
            time: 'أمس',
          ),
          Divider(height: 12, color: AppDesignTokens.borderSubtle(context)),
          _buildActivityRow(
            context,
            icon: Icons.quiz_rounded,
            color: AppDesignTokens.warning,
            title: l10n.quizzesScreenTitle,
            subtitle: '100% (5/5)',
            time: 'منذ يومين',
          ),
        ],
      ),
    );
  }

  Widget _buildActivityRow(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppDesignTokens.textPrimary(context),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppDesignTokens.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              color: AppDesignTokens.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardBanner(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ClinicalLeaderboardScreen()),
        );
      },
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
          border: Border.all(color: const Color(0xFFF59E0B)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFFB45309),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🏆 لوحة المتصدرين',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF78350F),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'اعرف ترتيبك بين زملائك',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Color(0xFFB45309),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgentFingerprintBanner(BuildContext context, WidgetRef ref, FingerprintRequest req) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF4444), width: 1.8),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🚨 تنبيه عاجل: مطلوب بصمة تأكيد التواجد فوراً!',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'مرسل من: ${req.senderName} • ${DateFormat('hh:mm a', 'ar').format(req.sentAt)}',
                          style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer_outlined, size: 12, color: Color(0xFFDC2626)),
                              const SizedBox(width: 3),
                              Text(
                                'متبقي ${req.remainingTimeFormatted}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFDC2626),
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
          if (req.notes != null && req.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              req.notes!,
              style: TextStyle(fontSize: 12, color: AppDesignTokens.textPrimary(context)),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.touch_app_rounded, color: Colors.white, size: 18),
              label: const Text(
                'تأكيد البصمة داخل المستشفى الآن 📱📍',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
              ),
              onPressed: () => _showUrgentFingerprintDialog(context, ref, req),
            ),
          ),
        ],
      ),
    );
  }

  void _showUrgentFingerprintDialog(BuildContext context, WidgetRef ref, FingerprintRequest req) {
    HapticFeedback.heavyImpact();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: AppDesignTokens.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppDesignTokens.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fingerprint_rounded, size: 42, color: Color(0xFFDC2626)),
              ),
              const SizedBox(height: 12),
              const Text(
                'تأكيد التواجد الفوري بمستشفى مطروح العام',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_rounded, size: 14, color: Color(0xFFDC2626)),
                    const SizedBox(width: 4),
                    Text(
                      'المهلة المتبقية: ${req.remainingTimeFormatted} دقيقة (حد أقصى 5 دقائق)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'طلب رسمي صادر من: ${req.senderName}\nيرجى تأكيد البصمة الحيوية وإرسال الموقع الجغرافي من داخل نطاق المستشفى لإثبات الحضور الفعلي.',
                style: TextStyle(fontSize: 12.5, color: AppDesignTokens.textSecondary(context), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (isSubmitting)
                const Column(
                  children: [
                    CircularProgressIndicator(color: Color(0xFFDC2626)),
                    SizedBox(height: 10),
                    Text('جارٍ التحقق البيومتري وتأكيد النطاق الجغرافي للمستشفى...', style: TextStyle(fontSize: 12)),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إغلاق'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.fingerprint_rounded, color: Colors.white),
                        label: const Text('بصم الآن 📱📍', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          // 1. Check 5-minute timeout expiration
                          if (req.isExpired) {
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: AppDesignTokens.danger,
                                  duration: Duration(seconds: 4),
                                  content: Text('عذراً، انتهت مهلة الـ 5 دقائق المحددة لتأكيد البصمة الفورية ⏰'),
                                ),
                              );
                            }
                            return;
                          }

                          setModalState(() => isSubmitting = true);
                          try {
                            // 2. Biometric verification
                            final bioRes = await PlatformService.biometric.authenticate(
                              reason: 'تأكيد بصمة التواجد الفوري بمستشفى مطروح العام',
                            );

                            if (!bioRes.success && !PlatformService.isWeb) {
                              setModalState(() => isSubmitting = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: AppDesignTokens.danger,
                                    content: Text('فشل التحقق البيومتري من البصمة ❌'),
                                  ),
                                );
                              }
                              return;
                            }

                            // 3. Fetch GPS coordinates
                            final loc = await LocationService.getCurrentLocation();
                            final userLat = loc.latitude ?? 0.0;
                            final userLon = loc.longitude ?? 0.0;

                            // 4. Verify Hospital Geofence (Matrouh General Hospital)
                            const hospitalLat = 31.3543;
                            const hospitalLon = 27.2373;
                            const allowedRadiusMeters = 200.0;
                            final isInsideHospital = (loc.latitude != null && loc.longitude != null) &&
                                DistanceCalculator.isWithinZone(
                                  userLat: userLat,
                                  userLon: userLon,
                                  zoneLat: hospitalLat,
                                  zoneLon: hospitalLon,
                                  radiusMeters: allowedRadiusMeters,
                                );

                            final distanceMeters = (loc.latitude != null && loc.longitude != null)
                                ? DistanceCalculator.calculateDistanceMeters(
                                    userLat,
                                    userLon,
                                    hospitalLat,
                                    hospitalLon,
                                  )
                                : 999999.0;

                            if (!isInsideHospital) {
                              setModalState(() => isSubmitting = false);
                              if (context.mounted) {
                                final distText = distanceMeters >= 1000
                                    ? '${(distanceMeters / 1000).toStringAsFixed(1)} كم'
                                    : '${distanceMeters.round()} متر';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppDesignTokens.danger,
                                    duration: const Duration(seconds: 5),
                                    content: Text(
                                      'أنت خارج نطاق مستشفى مطروح العام ($distText بعيداً). يجب التواجد داخل المستشفى لإثبات البصمة الفورية 📍🏥',
                                    ),
                                  ),
                                );
                              }
                              return;
                            }

                            // 5. Confirm in Supabase
                            await ref.read(fingerprintRequestsProvider.notifier).confirmFingerprint(
                              requestId: req.id,
                              latitude: loc.latitude,
                              longitude: loc.longitude,
                            );

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: AppDesignTokens.success,
                                  content: Text('تم تأكيد التواجد داخل مستشفى مطروح العام بالبصمة الحيوية بنجاح ✅📍'),
                                ),
                              );
                            }
                          } catch (e) {
                            setModalState(() => isSubmitting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppDesignTokens.danger,
                                  content: Text('حدث خطأ أثناء تأكيد البصمة: $e'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}


class _QuickActionItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _QuickActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _LearningItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  _LearningItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
