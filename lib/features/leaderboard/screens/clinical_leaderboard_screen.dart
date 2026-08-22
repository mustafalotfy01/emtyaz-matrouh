import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/leaderboard_provider.dart';

class ClinicalLeaderboardScreen extends ConsumerWidget {
  const ClinicalLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider);
    final currentUser = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: const Text('لوحة المتصدرين والتميز السريري'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppDesignTokens.primary,
          onRefresh: () async {
            ref.invalidate(leaderboardProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Criteria Header Card
                AppCard(
                  variant: AppCardVariant.accentTeal,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppDesignTokens.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.military_tech_rounded, color: AppDesignTokens.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'معايير التقييم السريري ولوحة الشرف',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: AppDesignTokens.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'يتم احتساب النقاط بناءً على الحضور الفعلي، الاختبارات، وتقييمات الدكاترة المشرفين على حالات التسليم والتسلم.',
                              style: TextStyle(fontSize: 11.5, color: AppDesignTokens.textSecondary(context), height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                AppSectionHeader(
                  title: 'ترتيب الطلاب',
                  subtitle: 'استناداً إلى السجلات المعتمدة بمستشفى مطروح العام',
                ),
                const SizedBox(height: 8),

                // Ranked List
                leaderboardAsync.when(
                  data: (list) {
                    if (list.isEmpty) {
                      return const AppCard(
                        padding: EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                        child: AppEmptyState(
                          title: 'لا توجد بيانات متصدرين حاليًا',
                          subtitle: 'سيتم ظهور ترتيب الطلاب بمجرد تسجيل الشيفتات والتقييمات السريرية.',
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
                        final isTop3 = item.rank <= 3;

                        return AppCard(
                          padding: const EdgeInsets.all(12),
                          variant: isCurrentUser
                              ? AppCardVariant.accentTeal
                              : (isTop3 ? AppCardVariant.elevated : AppCardVariant.standard),
                          child: Row(
                            children: [
                              // Rank Badge
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: item.rank == 1
                                      ? const Color(0xFFFBBF24).withOpacity(0.2)
                                      : (item.rank == 2
                                          ? const Color(0xFF94A3B8).withOpacity(0.2)
                                          : (item.rank == 3
                                              ? const Color(0xFFB45309).withOpacity(0.2)
                                              : AppDesignTokens.surfaceMuted(context))),
                                ),
                                child: Center(
                                  child: Text(
                                    '#${item.rank}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: item.rank == 1
                                          ? const Color(0xFFB45309)
                                          : (item.rank == 2
                                              ? const Color(0xFF475569)
                                              : (item.rank == 3
                                                  ? const Color(0xFF78350F)
                                                  : AppDesignTokens.textSecondary(context))),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              AppAvatar(name: item.fullName, imageUrl: item.avatarUrl, size: AppAvatarSize.small),
                              const SizedBox(width: 10),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          item.fullName,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: AppDesignTokens.textPrimary(context),
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
                                    const SizedBox(height: 2),
                                    Text(
                                      'حضور: ${item.attendancePercentage.toStringAsFixed(0)}% • الشيفتات: ${item.attendedShifts}',
                                      style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                                    ),
                                  ],
                                ),
                              ),

                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  AppBadge(
                                    label: '${item.score.toStringAsFixed(1)} نقطة',
                                    variant: isTop3 ? AppBadgeVariant.success : AppBadgeVariant.neutral,
                                    size: AppBadgeSize.small,
                                  ),
                                ],
                              ),
                            ],
                          ),
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
}
