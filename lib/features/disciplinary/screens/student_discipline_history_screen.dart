import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_card.dart';
import '../models/disciplinary_action.dart';
import '../providers/disciplinary_provider.dart';
import '../../auth/providers/auth_provider.dart';

class StudentDisciplineHistoryScreen extends ConsumerWidget {
  const StudentDisciplineHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final actions = ref.watch(disciplinaryProvider);
    final metrics = ref.read(disciplinaryProvider.notifier).getStudentMetrics(user?.id ?? 'student-001');

    final studentActions = actions.where((a) => a.studentId == (user?.id ?? 'student-001')).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الالتزام والانضباط الوظيفي'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Attendance & Discipline Summary Metric Grid
          CustomCard(
            backgroundColor: AppColors.deepNavy,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'نسبة الالتزام الوظيفي العامة',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '🟢 الحضور: ${metrics.attendancePercentage.toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.2,
                  children: [
                    _buildMetricTile('🟠 التأخير', '${metrics.totalLates} مرات', AppColors.warningLight),
                    _buildMetricTile('🔴 الغياب', '${metrics.totalAbsences} شيفت', AppColors.dangerLight),
                    _buildMetricTile('⚠️ الإنذارات', '${metrics.totalWarnings}', AppColors.warningLight),
                    _buildMetricTile('📜 المخالفات', '${metrics.totalViolations}', AppColors.dangerLight),
                    _buildMetricTile('❌ الخصومات', '${metrics.totalDeductions}', AppColors.dangerLight),
                    _buildMetricTile('🌟 المكافآت', '${metrics.totalRewards}', AppColors.successLight),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'سجل الإجراءات والملاحظات الرسمية',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),

          const SizedBox(height: 12),

          if (studentActions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: Text('لا توجد إجراءات مسجلة بحسابك — أداء التزامي ممتازة! 🎉')),
            )
          else
            ...studentActions.map((act) {
              final isReward = act.actionType == DisciplinaryActionType.reward;
              final isWarning = act.actionType == DisciplinaryActionType.warning || act.actionType == DisciplinaryActionType.lateCheckin;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: CustomCard(
                  borderColor: isReward
                      ? AppColors.success
                      : (isWarning ? AppColors.warning : AppColors.danger),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            act.actionType.displayNameAr,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isReward
                                  ? AppColors.success
                                  : (isWarning ? AppColors.warning : AppColors.danger),
                            ),
                          ),
                          Text(
                            DateFormat('yyyy-MM-dd').format(act.actionDate),
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'القسم: ${act.departmentName} | المقيّم: ${act.createdByName}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'السبب: ${act.reason}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        act.description,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),

                      if (act.deductionValue > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isReward ? AppColors.successLight : AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'الأثر: ${isReward ? '+' : '-'}${act.deductionValue.toStringAsFixed(0)} ${act.deductionUnit}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isReward ? AppColors.success : AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.white70)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}
