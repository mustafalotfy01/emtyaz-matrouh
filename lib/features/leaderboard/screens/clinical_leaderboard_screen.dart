import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/screens/user_profile_details_screen.dart';
import '../models/leaderboard_entry.dart';
import '../providers/leaderboard_provider.dart';

class ClinicalLeaderboardScreen extends ConsumerWidget {
  const ClinicalLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider);
    final sortModeAsync = ref.watch(leaderboardSortModeProvider);
    final sortMode = sortModeAsync.valueOrNull ?? LeaderboardSortMode.gpa;
    final currentUser = ref.watch(authProvider).user;

    final isAdmin = currentUser?.role == UserRole.superAdmin;
    final isLeader = currentUser?.role == UserRole.leader;
    final isStaff = isAdmin || isLeader;

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: const Text(
          'لوحة المتصدرين',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: AppDesignTokens.textPrimary(context),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppDesignTokens.primary,
          onRefresh: () async {
            ref.invalidate(leaderboardProvider);
            ref.invalidate(leaderboardSortModeProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Criteria & Mode Control (Visible ONLY to Admin & Leader)
                if (isStaff) ...[
                  AppCard(
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
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings_rounded,
                                color: AppDesignTokens.primary,
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
                                        'معايير لوحة المتصدرين',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppDesignTokens.textPrimary(context),
                                        ),
                                      ),
                                      const Spacer(),
                                      const AppBadge(
                                        label: 'خاص بالإدارة والليدرز',
                                        variant: AppBadgeVariant.neutral,
                                        size: AppBadgeSize.small,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    sortMode == LeaderboardSortMode.gpa
                                        ? 'الترتيب الحالي معتمد على المعدل التراكمي (GPA) من الأعلى للأقل. لا يتم إظهار سبب الترتيب أو المعدلات للطلاب حفاظاً على الخصوصية.'
                                        : 'الترتيب الحالي معتمد على نقاط التميز السريري (الحضور الفعلي، الاختبارات، وتقييمات المشرفين والجزاءات/المكافآت).',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppDesignTokens.textSecondary(context),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Super Admin Switcher for GPA vs Points
                        if (isAdmin) ...[
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Text(
                                'تحديد طريقة ترتيب الطلاب:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppDesignTokens.textPrimary(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSortModeButton(
                                  context: context,
                                  title: '🎓 المعدل (GPA)',
                                  subtitle: 'ترتيب حسب المعدل التراكمي',
                                  isSelected: sortMode == LeaderboardSortMode.gpa,
                                  onTap: () async {
                                    if (sortMode != LeaderboardSortMode.gpa) {
                                      HapticFeedback.mediumImpact();
                                      await ref
                                          .read(leaderboardSortModeProvider.notifier)
                                          .setMode(LeaderboardSortMode.gpa);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('تم ضبط ترتيب الطلاب ليكون بالمعدل التراكمي (GPA)'),
                                            behavior: SnackBarBehavior.floating,
                                            backgroundColor: AppDesignTokens.success,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildSortModeButton(
                                  context: context,
                                  title: '🏆 النقاط (Points)',
                                  subtitle: 'ترتيب حسب الأداء السريري',
                                  isSelected: sortMode == LeaderboardSortMode.points,
                                  onTap: () async {
                                    if (sortMode != LeaderboardSortMode.points) {
                                      HapticFeedback.mediumImpact();
                                      await ref
                                          .read(leaderboardSortModeProvider.notifier)
                                          .setMode(LeaderboardSortMode.points);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('تم ضبط ترتيب الطلاب ليكون بنقاط التميز السريري (Points)'),
                                            behavior: SnackBarBehavior.floating,
                                            backgroundColor: AppDesignTokens.primary,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 2. Section Header
                AppSectionHeader(
                  title: 'ترتيب الطلاب',
                  subtitle: isStaff
                      ? 'الترتيب الفعلي المعتمد: ${sortMode.displayNameAr}'
                      : 'لوحة الشرف لطلاب الامتياز بمستشفى مطروح العام',
                ),
                const SizedBox(height: 8),

                // 3. Ranked List
                leaderboardAsync.when(
                  data: (list) {
                    if (list.isEmpty) {
                      return AppCard(
                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                        child: AppEmptyState(
                          title: 'لا توجد بيانات متصدرين حاليًا',
                          subtitle: isStaff
                              ? 'سيتم ظهور ترتيب الطلاب بمجرد اعتماد الطلاب أو تسجيل التقييمات.'
                              : 'سيتم ظهور ترتيب الطلاب المعتمدين هنا قريباً.',
                          icon: Icons.emoji_events_outlined,
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = list[index];
                        final isCurrentUser = currentUser?.id == item.studentId;
                        return _buildLeaderboardRow(
                          context: context,
                          item: item,
                          isCurrentUser: isCurrentUser,
                          isStaff: isStaff,
                          sortMode: sortMode,
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(color: AppDesignTokens.primary),
                    ),
                  ),
                  error: (_, __) => const AppCard(
                    padding: EdgeInsets.all(20),
                    child: AppEmptyState(
                      title: 'لا توجد بيانات متصدرين حاليًا',
                      subtitle: 'تعذر جلب البيانات. اسحب لأسفل للتحديث.',
                      icon: Icons.error_outline_rounded,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardRow({
    required BuildContext context,
    required LeaderboardEntry item,
    required bool isCurrentUser,
    required bool isStaff,
    required LeaderboardSortMode sortMode,
  }) {
    final rank = item.rank;
    final rankStyle = _getRankStyle(rank, context);

    return InkWell(
      onTap: () => UserProfileDetailsScreen.show(
        context,
        userId: item.studentId,
        initialName: item.fullName,
        initialAvatarUrl: item.avatarUrl,
      ),
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          color: isCurrentUser
              ? AppDesignTokens.primary.withOpacity(0.08)
              : (rank <= 5 ? rankStyle.cardBgColor : AppDesignTokens.surface(context)),
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
          border: Border.all(
            color: isCurrentUser
                ? AppDesignTokens.primary
                : (rank <= 5 ? rankStyle.borderColor.withOpacity(0.6) : AppDesignTokens.borderSubtle(context)),
            width: rank <= 3 || isCurrentUser ? 1.5 : 1.0,
          ),
          boxShadow: rank <= 3
              ? [
                  BoxShadow(
                    color: rankStyle.borderColor.withOpacity(0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // 1. Rank Circle (#1..#5 distinctive colors)
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: rankStyle.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: rankStyle.borderColor.withOpacity(0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    color: rankStyle.badgeTextColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // 2. Avatar Circle (in a circle with matching border)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: rankStyle.borderColor,
                  width: rank <= 5 ? 2.0 : 1.0,
                ),
              ),
              child: ClipOval(
                child: (item.avatarUrl != null && item.avatarUrl!.isNotEmpty)
                    ? Image.network(
                        item.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildAvatarFallback(item.fullName),
                      )
                    : _buildAvatarFallback(item.fullName),
              ),
            ),
            const SizedBox(width: 12),

            // 3. Name & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.fullName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppDesignTokens.textPrimary(context),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 6),
                        const AppBadge(
                          label: 'أنت',
                          variant: AppBadgeVariant.success,
                          size: AppBadgeSize.small,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        'طالب امتياز',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppDesignTokens.textSecondary(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isStaff && item.attendedShifts > 0) ...[
                        Text(
                          ' • الشيفتات: ${item.attendedShifts}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppDesignTokens.textMuted(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

          // 4. Points Badge (Visible to EVERYONE) & GPA info (For Staff)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppBadge(
                label: item.score % 1 == 0
                    ? '${item.score.toInt()} نقطة'
                    : '${item.score.toStringAsFixed(1)} نقطة',
                variant: item.score < 0
                    ? AppBadgeVariant.danger
                    : (item.score > 0 ? AppBadgeVariant.success : AppBadgeVariant.neutral),
                size: AppBadgeSize.small,
              ),
              if (isStaff && sortMode == LeaderboardSortMode.gpa && item.gpa != null) ...[
                const SizedBox(height: 3),
                Text(
                  'GPA: ${item.gpa!.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppDesignTokens.textSecondary(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildAvatarFallback(String name) {
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').take(2).map((e) => e.isNotEmpty ? e[0] : '').join()
        : 'ط';

    return Container(
      color: const Color(0xFF0E7C8C).withOpacity(0.15),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Color(0xFF0E7C8C),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  _RankStyle _getRankStyle(int rank, BuildContext context) {
    switch (rank) {
      case 1:
        // 🥇 1st: Pure Gold
        return _RankStyle(
          cardBgColor: const Color(0xFFFEF9C3).withOpacity(0.3),
          borderColor: const Color(0xFFF59E0B),
          badgeTextColor: const Color(0xFF78350F),
          gradientColors: const [Color(0xFFFFD54F), Color(0xFFF59E0B)],
        );
      case 2:
        // 🥈 2nd: Shiny Silver / Platinum
        return _RankStyle(
          cardBgColor: const Color(0xFFF1F5F9).withOpacity(0.35),
          borderColor: const Color(0xFF94A3B8),
          badgeTextColor: const Color(0xFF1E293B),
          gradientColors: const [Color(0xFFE2E8F0), Color(0xFF94A3B8)],
        );
      case 3:
        // 🥉 3rd: Bronze / Copper
        return _RankStyle(
          cardBgColor: const Color(0xFFFFEDD5).withOpacity(0.3),
          borderColor: const Color(0xFFF97316),
          badgeTextColor: const Color(0xFF7C2D12),
          gradientColors: const [Color(0xFFFFB74D), Color(0xFFE65100)],
        );
      case 4:
        // 💎 4th: Emerald Green / Jade
        return _RankStyle(
          cardBgColor: const Color(0xFFD1FAE5).withOpacity(0.25),
          borderColor: const Color(0xFF10B981),
          badgeTextColor: const Color(0xFF064E3B),
          gradientColors: const [Color(0xFFA7F3D0), Color(0xFF059669)],
        );
      case 5:
        // 🔮 5th: Royal Purple / Amethyst
        return _RankStyle(
          cardBgColor: const Color(0xFFEDE9FE).withOpacity(0.25),
          borderColor: const Color(0xFF8B5CF6),
          badgeTextColor: const Color(0xFF4C1D95),
          gradientColors: const [Color(0xFFDDD6FE), Color(0xFF7C3AED)],
        );
      default:
        // Standard ranks #6+
        return _RankStyle(
          cardBgColor: AppDesignTokens.surface(context),
          borderColor: AppDesignTokens.borderSubtle(context),
          badgeTextColor: AppDesignTokens.textSecondary(context),
          gradientColors: [
            AppDesignTokens.surfaceMuted(context),
            AppDesignTokens.surfaceMuted(context),
          ],
        );
    }
  }

  Widget _buildSortModeButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppDesignTokens.primary.withOpacity(0.15)
              : AppDesignTokens.surfaceMuted(context),
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
          border: Border.all(
            color: isSelected ? AppDesignTokens.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? AppDesignTokens.primary
                        : AppDesignTokens.textPrimary(context),
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: AppDesignTokens.primary, size: 14),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? AppDesignTokens.primary
                    : AppDesignTokens.textMuted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankStyle {
  final Color cardBgColor;
  final Color borderColor;
  final Color badgeTextColor;
  final List<Color> gradientColors;

  _RankStyle({
    required this.cardBgColor,
    required this.borderColor,
    required this.badgeTextColor,
    required this.gradientColors,
  });
}
