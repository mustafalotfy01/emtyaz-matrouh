import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_skeleton.dart';
import '../models/disciplinary_action.dart';
import '../providers/disciplinary_provider.dart';
import '../../auth/providers/auth_provider.dart';

class StudentDisciplineHistoryScreen extends ConsumerWidget {
  const StudentDisciplineHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final actionsAsync = ref.watch(disciplinaryProvider);

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: const Text('سجل الالتزام والتميز'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(disciplinaryProvider.notifier).loadActions(),
          ),
        ],
      ),
      body: SafeArea(
        child: actionsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: AppLoadingSkeleton(itemCount: 3, height: 160),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: AppErrorState(
              title: 'تعذر تحميل سجل الالتزام',
              message: err.toString().replaceAll('Exception: ', ''),
              onRetry: () => ref.read(disciplinaryProvider.notifier).loadActions(),
            ),
          ),
          data: (actionsList) {
            final studentId = user?.id ?? '';
            final studentActions = actionsList.where((a) => a.studentId == studentId).toList();
            final metrics = ref.read(disciplinaryProvider.notifier).getStudentMetrics(studentId);

            return RefreshIndicator(
              onRefresh: () => ref.read(disciplinaryProvider.notifier).loadActions(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                children: [
                  // Attendance & Discipline Summary Metric Card
                  AppCard(
                    variant: AppCardVariant.accentTeal,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'مؤشر الانضباط العام ⭐',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'الالتزام: ${metrics.attendancePercentage.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.35,
                          children: [
                            _buildMetricTile('🟠 التأخير', '${metrics.totalLates} مرات'),
                            _buildMetricTile('🔴 الغياب', '${metrics.totalAbsences} شيفت'),
                            _buildMetricTile('⚠️ الإنذارات', '${metrics.totalWarnings}'),
                            _buildMetricTile('📜 المخالفات', '${metrics.totalViolations}'),
                            _buildMetricTile('❌ الخصومات', '${metrics.totalDeductions}'),
                            _buildMetricTile('🌟 المكافآت', '${metrics.totalRewards}'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'السجل الرسمي للإجراءات والمكافآت',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: AppDesignTokens.textPrimary(context),
                        ),
                      ),
                      Text(
                        '${studentActions.length} إجراء',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppDesignTokens.textSecondary(context),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (studentActions.isEmpty)
                    const AppEmptyState(
                      title: 'لا توجد ملاحظات أو جزاءات مسجلة 🎉',
                      message: 'سجلك نظيف ومثالي! استمر في الالتزام والتميز السريري.',
                      icon: Icons.verified_outlined,
                    )
                  else
                    ...studentActions.map((act) => _buildActionCard(context, act)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMetricTile(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 10, color: Colors.white70),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, DisciplinaryAction act) {
    final isReward = act.actionType.isReward;
    final isWarning = act.actionType == DisciplinaryActionType.warning ||
        act.actionType == DisciplinaryActionType.lateCheckin;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isReward
                          ? Icons.military_tech_rounded
                          : (isWarning ? Icons.warning_amber_rounded : Icons.gavel_rounded),
                      size: 18,
                      color: isReward
                          ? AppDesignTokens.accentGold
                          : (isWarning ? AppDesignTokens.warning : AppDesignTokens.danger),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      act.actionType.displayNameAr,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isReward
                            ? AppDesignTokens.accentGold
                            : (isWarning ? AppDesignTokens.warning : AppDesignTokens.danger),
                      ),
                    ),
                  ],
                ),
                AppBadge(
                  label: act.status.displayNameAr,
                  variant: act.status == ActionStatus.approved
                      ? AppBadgeVariant.success
                      : AppBadgeVariant.warning,
                  size: AppBadgeSize.small,
                ),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              act.reason,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppDesignTokens.textPrimary(context),
              ),
            ),

            if (act.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                act.description,
                style: TextStyle(
                  fontSize: 12,
                  color: AppDesignTokens.textSecondary(context),
                  height: 1.3,
                ),
              ),
            ],

            const SizedBox(height: 10),

            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_hospital_outlined, size: 13, color: AppDesignTokens.textSecondary(context)),
                    const SizedBox(width: 4),
                    Text(
                      act.departmentName,
                      style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_outline_rounded, size: 13, color: AppDesignTokens.textSecondary(context)),
                    const SizedBox(width: 4),
                    Text(
                      'المسؤول: ${act.createdByName}',
                      style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 13, color: AppDesignTokens.textSecondary(context)),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('yyyy-MM-dd').format(act.actionDate),
                      style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                    ),
                  ],
                ),
              ],
            ),

            if (act.deductionValue > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isReward
                      ? AppDesignTokens.accentGold.withValues(alpha: 0.12)
                      : AppDesignTokens.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                ),
                child: Text(
                  'الأثر: ${isReward ? '+' : '-'}${act.deductionValue.toStringAsFixed(0)} ${act.deductionUnit}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isReward ? AppDesignTokens.accentGold : AppDesignTokens.danger,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
