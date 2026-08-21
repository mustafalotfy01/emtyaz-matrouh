import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ios/app_badge.dart';
import '../../../core/widgets/ios/app_button.dart';
import '../../../core/widgets/ios/app_card.dart';
import '../../../core/widgets/ios/app_section_header.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../roster/providers/final_roster_provider.dart';

class StudentDashboardScreen extends ConsumerWidget {
  final Function(int) onNavigateTab;

  const StudentDashboardScreen({super.key, required this.onNavigateTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final attendanceState = ref.watch(attendanceProvider);
    final finalApprovedShifts = ref.watch(studentFinalApprovedRosterProvider).value ?? [];
    final l10n = context.l10n;
    
    final studentName = user?.fullName.isNotEmpty == true 
        ? user!.fullName.split(' ')[0] 
        : 'أحمد';
    final groupName = user?.studentGroup.name == 'groupB' ? l10n.groupB : l10n.groupA;
    final universityCode = user?.universityCode.isNotEmpty == true 
        ? user!.universityCode 
        : 'NUR-2026-081';

    final longCount = finalApprovedShifts.where((s) => s.shiftType.name == 'longShift').length;
    final nightCount = finalApprovedShifts.where((s) => s.shiftType.name == 'night').length;
    final morningCount = finalApprovedShifts.where((s) => s.shiftType.name == 'morning').length;
    final totalAssigned = finalApprovedShifts.length;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. iOS Top User Header ─────────────────────────────────────
              _buildTopHeader(
                context,
                l10n: l10n,
                studentName: studentName,
                groupName: groupName,
                universityCode: universityCode,
              ),

              const SizedBox(height: 16),

              // ── 2. Today's Shift Hero Card ─────────────────────────────────
              _buildTodayShiftHeroCard(
                context,
                l10n: l10n,
                attendanceState: attendanceState,
                onCheckinTap: () => onNavigateTab(2), // Attendance tab
              ),

              const SizedBox(height: 18),

              // ── 3. Your Month Summary Card ─────────────────────────────────
              _buildMonthSummaryCard(
                context,
                l10n: l10n,
                total: totalAssigned > 0 ? totalAssigned : 12,
                longCount: longCount > 0 ? longCount : 10,
                nightCount: nightCount > 0 ? nightCount : 2,
                morningCount: morningCount,
                onViewRosterTap: () => onNavigateTab(1), // Roster tab
              ),

              const SizedBox(height: 20),

              // ── 4. Quick Actions (2x2 Compact iOS Grid) ────────────────────
              AppSectionHeader(
                title: l10n.quickAccessTitle,
                subtitle: l10n.quickAccessSubtitle,
              ),
              const SizedBox(height: 8),
              _buildQuickActionsGrid(context, l10n: l10n),

              const SizedBox(height: 20),

              // ── 5. Daily Quiz Banner Card ──────────────────────────────────
              _buildDailyQuizBanner(
                context,
                l10n: l10n,
                onStartQuiz: () => onNavigateTab(3), // Quiz tab
              ),

              const SizedBox(height: 20),

              // ── 6. Clinical Learning Carousel ──────────────────────────────
              AppSectionHeader(
                title: l10n.whatToLearnTitle,
                subtitle: l10n.whatToLearnSubtitle,
                actionText: l10n.libraryViewAll,
                onActionTap: () => onNavigateTab(4), // Knowledge tab
              ),
              const SizedBox(height: 10),
              _buildLearningCarousel(context),

              const SizedBox(height: 20),

              // ── 7. Recent Activity Timeline ────────────────────────────────
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
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryTeal.withOpacity(0.3), width: 1.5),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: AppColors.primaryTeal,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.greetingMorning(studentName),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(context),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${l10n.roleStudent} • $groupName',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.subtext(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),

        // University Code Pill Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(context), width: 1),
            boxShadow: AppTheme.iosCardShadow(context),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.badge_outlined, size: 13, color: AppColors.primaryTeal),
              const SizedBox(width: 4),
              Text(
                universityCode,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Today's Shift Hero Card ────────────────────────────────────────────────
  Widget _buildTodayShiftHeroCard(
    BuildContext context, {
    required AppLocalizations l10n,
    required dynamic attendanceState,
    required VoidCallback onCheckinTap,
  }) {
    final isCheckedIn = attendanceState.activeRecord != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.heroDarkGradient : AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: isDark ? Border.all(color: AppColors.darkDivider) : null,
        boxShadow: [
          BoxShadow(
            color: AppColors.deepNavy.withOpacity(isDark ? 0.35 : 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -20,
            bottom: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(
                            l10n.todayShiftTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCheckedIn
                            ? AppColors.success.withOpacity(0.9)
                            : Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCheckedIn ? Icons.check_circle : Icons.radio_button_checked,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isCheckedIn ? l10n.checkedInStatus : '${l10n.shiftLongShort} (12h)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Text(
                  '${l10n.hospitalName} — ${l10n.deptEmergency}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 14, color: Colors.white.withOpacity(0.8)),
                    const SizedBox(width: 5),
                    Text(
                      l10n.shiftLongTiming,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                AppButton(
                  text: isCheckedIn ? l10n.viewCheckInDetails : l10n.checkInNow,
                  icon: isCheckedIn ? Icons.verified_rounded : Icons.fingerprint_rounded,
                  variant: AppButtonVariant.whitePill,
                  height: 44,
                  onPressed: onCheckinTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Your Month Summary Card ────────────────────────────────────────────────
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_note_rounded, size: 20, color: AppColors.primaryTeal),
                  const SizedBox(width: 8),
                  Text(
                    l10n.monthlyRosterSummary,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(context),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.successDarkBg : AppColors.successLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.daysCount(total, 12),
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.longPurpleDarkBg : AppColors.longPurpleBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.shiftLongShort,
                        style: const TextStyle(fontSize: 11, color: AppColors.longPurple, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        l10n.shiftCount(longCount),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.longPurple),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.nightDarkThemeBg : AppColors.nightDarkBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.shiftNightShort,
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : AppColors.nightDark, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        l10n.shiftCount(nightCount),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.nightDark),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.morningBlueDarkBg : AppColors.morningBlueBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.shiftMorningShort,
                        style: const TextStyle(fontSize: 11, color: AppColors.morningBlue, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        l10n.shiftCount(morningCount),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.morningBlue),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          InkWell(
            onTap: onViewRosterTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.viewFullApprovedRoster,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primaryTeal),
                ],
              ),
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
        color: AppColors.primaryTeal,
        bgColor: AppColors.primaryTeal.withOpacity(0.1),
        onTap: () => onNavigateTab(2),
      ),
      _QuickActionItem(
        title: l10n.quickActionRoster,
        subtitle: l10n.quickActionRosterSub,
        icon: Icons.calendar_month_rounded,
        color: AppColors.tilePurple,
        bgColor: AppColors.tilePurple.withOpacity(0.1),
        onTap: () => onNavigateTab(1),
      ),
      _QuickActionItem(
        title: l10n.quickActionQuizzes,
        subtitle: l10n.quickActionQuizzesSub,
        icon: Icons.quiz_rounded,
        color: AppColors.tileOrange,
        bgColor: AppColors.tileOrange.withOpacity(0.1),
        onTap: () => onNavigateTab(3),
      ),
      _QuickActionItem(
        title: l10n.quickActionLogbook,
        subtitle: l10n.quickActionLogbookSub,
        icon: Icons.folder_shared_rounded,
        color: AppColors.info,
        bgColor: AppColors.info.withOpacity(0.1),
        onTap: () => onNavigateTab(4),
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
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              tile.onTap();
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppColors.border(context), width: 1),
                boxShadow: AppTheme.iosCardShadow(context),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: tile.bgColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(tile.icon, color: tile.color, size: 23),
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
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tile.subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.subtext(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Daily Quiz Banner ──────────────────────────────────────────────────────
  Widget _buildDailyQuizBanner(BuildContext context, {required AppLocalizations l10n, required VoidCallback onStartQuiz}) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.quizBannerGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEA580C).withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 12,
            top: 10,
            bottom: 10,
            child: Opacity(
              opacity: 0.18,
              child: const Icon(
                Icons.lightbulb_rounded,
                size: 90,
                color: Colors.white,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.dailyQuizBannerTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.dailyQuizBannerSubtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onStartQuiz();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.startDailyQuiz,
                                style: const TextStyle(
                                  color: Color(0xFFEA580C),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.play_arrow_rounded,
                                size: 16,
                                color: Color(0xFFEA580C),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.psychology_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Clinical Learning Carousel ─────────────────────────────────────────────
  Widget _buildLearningCarousel(BuildContext context) {
    final procedures = [
      _LearningItem(title: 'Foley Catheter', subtitle: 'قسطرة بولية', icon: Icons.healing_rounded, color: AppColors.primaryTeal),
      _LearningItem(title: 'NG Tube', subtitle: 'أنبوبة أنفية معدية', icon: Icons.medical_services_rounded, color: AppColors.tilePurple),
      _LearningItem(title: 'CPR Protocol', subtitle: 'إنعاش قلبي رئوي', icon: Icons.favorite_rounded, color: AppColors.danger),
      _LearningItem(title: 'IV Cannulation', subtitle: 'تركيب الكانولا', icon: Icons.vaccines_rounded, color: AppColors.info),
      _LearningItem(title: 'Emergency Triage', subtitle: 'فرز الطوارئ', icon: Icons.emergency_rounded, color: AppColors.warning),
    ];

    return SizedBox(
      height: 95,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: procedures.length,
        itemBuilder: (context, index) {
          final item = procedures[index];
          return Container(
            width: 140,
            margin: EdgeInsets.only(left: index == procedures.length - 1 ? 0 : 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onNavigateTab(4); // Knowledge tab
                },
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(color: AppColors.border(context), width: 1),
                    boxShadow: AppTheme.iosCardShadow(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: item.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(item.icon, size: 16, color: item.color),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.textMuted),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.subtext(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
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
            color: AppColors.primaryTeal,
            title: l10n.attendanceScreenTitle,
            subtitle: isCheckedIn ? '07:55 AM • ${l10n.checkedInStatus}' : l10n.checkInNow,
            time: 'اليوم',
          ),
          Divider(height: 12, color: AppColors.border(context)),
          _buildActivityRow(
            context,
            icon: Icons.verified_rounded,
            color: AppColors.success,
            title: l10n.approvedRosterTitle,
            subtitle: l10n.statusApproved,
            time: 'أمس',
          ),
          Divider(height: 12, color: AppColors.border(context)),
          _buildActivityRow(
            context,
            icon: Icons.quiz_rounded,
            color: AppColors.tileOrange,
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
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(context),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.subtext(context),
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  _QuickActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
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
