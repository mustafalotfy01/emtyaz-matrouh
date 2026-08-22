import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../../attendance/screens/students_map_overview_screen.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/student_approvals_provider.dart';
import '../../auth/screens/student_approvals_screen.dart';
import '../../departments/providers/department_provider.dart';
import '../../notifications/screens/send_notification_screen.dart';
import '../../app_versions/screens/app_versions_screen.dart';
import '../../roster/models/roster_preference.dart';
import '../../roster/providers/roster_provider.dart';

class LeaderDashboardScreen extends ConsumerWidget {
  const LeaderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderState = ref.watch(leaderRosterProvider);
    final studentsAsync = ref.watch(studentApprovalsProvider);
    final attendanceState = ref.watch(attendanceProvider);
    final matrixAsync = ref.watch(distributionMatrixProvider);
    final l10n = context.l10n;

    final totalStudentsCount = studentsAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    final pendingApprovalCount = studentsAsync.maybeWhen(
      data: (list) => list.where((s) => s.registrationStatus == RegistrationStatus.pending).length,
      orElse: () => 0,
    );

    final pendingSubmissions = leaderState.summaries
        .where((s) => s.submissionStatus != PreferenceStatus.submitted)
        .length;

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Supervision Station Header ─────────────────────────────
              AppCard(
                padding: const EdgeInsets.all(16),
                variant: AppCardVariant.accentTeal,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppDesignTokens.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: AppDesignTokens.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.isArabic ? 'منظومة إشراف وتنسيق الامتياز' : 'Internship Supervision Hub',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                              color: AppDesignTokens.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.isArabic
                                ? 'متابعة الجداول، الاعتمادات، والحضور الميداني للأقسام'
                                : 'Roster approvals, shift assignments, and hospital attendance',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppDesignTokens.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 2. Primary KPI Metric Grid ─────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('إجمالي الطلاب', style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context))),
                          const SizedBox(height: 4),
                          Text(
                            '$totalStudentsCount',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppDesignTokens.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('الحضور الفعلي', style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context))),
                          const SizedBox(height: 4),
                          Text(
                            '${attendanceState.history.length}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppDesignTokens.success),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('اعتمادات معلقة', style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context))),
                          const SizedBox(height: 4),
                          Text(
                            '$pendingApprovalCount',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppDesignTokens.warning),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('بانتظار التقديم', style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context))),
                          const SizedBox(height: 4),
                          Text(
                            '$pendingSubmissions',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppDesignTokens.danger),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── 3. Department Distribution Matrix (Feature 7 & Supervision System) ──
              AppSectionHeader(
                title: 'مصفوفة توزيع الأقسام والأطباء المشرفين',
                subtitle: 'مستشفى مطروح العام — توزيع الحصص والسعة الاستيعابية',
              ),
              const SizedBox(height: 8),

              matrixAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Text('حدث خطأ أثناء تحميل مصفوفة التوزيع: $err'),
                ),
                data: (matrix) {
                  if (matrix.isEmpty) {
                    return const AppCard(
                      padding: EdgeInsets.all(16),
                      child: Text('لا توجد أقسام مسجلة بالمستشفى حالياً.'),
                    );
                  }

                  return AppCard(
                    padding: const EdgeInsets.all(12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowHeight: 40,
                        dataRowMinHeight: 48,
                        dataRowMaxHeight: 52,
                        horizontalMargin: 12,
                        columnSpacing: 16,
                        columns: const [
                          DataColumn(label: Text('القسم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('المشرف الطبي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('👨 الذكور', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('👩 الإناث', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('👥 الإجمالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('المتبقي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('الحالة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                        rows: matrix.map((row) {
                          return DataRow(
                            cells: [
                              DataCell(Text(row.departmentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                              DataCell(Text(row.doctorName, style: const TextStyle(fontSize: 12))),
                              DataCell(Text('${row.currentMale} / ${row.maleCapacity}', style: const TextStyle(fontSize: 12))),
                              DataCell(Text('${row.currentFemale} / ${row.femaleCapacity}', style: const TextStyle(fontSize: 12))),
                              DataCell(Text('${row.currentTotal} / ${row.totalCapacity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataCell(
                                Text(
                                  '${row.remainingTotal} شاغر',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: row.remainingTotal > 0 ? AppDesignTokens.success : AppDesignTokens.danger,
                                  ),
                                ),
                              ),
                              DataCell(
                                AppBadge(
                                  label: row.assignmentStatus == 'approved' ? 'معتمد' : 'مسودة',
                                  variant: row.assignmentStatus == 'approved' ? AppBadgeVariant.success : AppBadgeVariant.warning,
                                  size: AppBadgeSize.small,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // ── 4. Quick Action Hub ────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const StudentApprovalsScreen()),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppDesignTokens.warning.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                            ),
                            child: const Icon(Icons.how_to_reg_rounded, color: AppDesignTokens.warning, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('طلبات التسجيل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppDesignTokens.textPrimary(context))),
                                Text('$pendingApprovalCount بانتظار الاعتماد', style: TextStyle(fontSize: 10.5, color: AppDesignTokens.textSecondary(context))),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SendNotificationScreen()),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppDesignTokens.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                            ),
                            child: const Icon(Icons.campaign_rounded, color: AppDesignTokens.primary, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('بث إشعار فوري', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppDesignTokens.textPrimary(context))),
                                Text('تنبيهات الدفعة والأقسام', style: TextStyle(fontSize: 10.5, color: AppDesignTokens.textSecondary(context))),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Student GPS Map Overview Tile
              AppCard(
                padding: const EdgeInsets.all(14),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StudentsMapOverviewScreen()),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppDesignTokens.info.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                      ),
                      child: const Icon(Icons.map_rounded, color: AppDesignTokens.info, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('خريطة توزيع الطلاب وسكنهم الميداني', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppDesignTokens.textPrimary(context))),
                          Text('توزيع المقيمين والمغتربين حول المستشفى والنطاق الجغرافي', style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context))),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ── 4.1. App Versions (Read-Only) ──────────────────────────────
              AppCard(
                padding: const EdgeInsets.all(14),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AppVersionsScreen()),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppDesignTokens.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                      ),
                      child: const Icon(Icons.system_update_rounded, color: AppDesignTokens.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('إصدارات التطبيق الرسمية (متابعة)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppDesignTokens.textPrimary(context))),
                          Text('استعراض الإصدارات النشطة وملاحظات التحديثات (للعرض)', style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context))),
                        ],
                      ),
                    ),
                    const AppBadge(label: 'للعرض', variant: AppBadgeVariant.neutral, size: AppBadgeSize.small),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── 5. Student Roster Preferences Status ───────────────────────
              AppSectionHeader(
                title: l10n.isArabic ? 'تفضيلات الروستر للطلاب' : 'Intern Shift Proposals',
                subtitle: l10n.isArabic ? 'حالة تسليم المقترحات ومراجعة المشرف' : 'Submission status and coordinator review',
                actionText: '${leaderState.summaries.length} طالب',
              ),
              const SizedBox(height: 10),

              if (leaderState.summaries.isEmpty)
                AppCard(
                  padding: const EdgeInsets.all(28),
                  child: Center(
                    child: Text(
                      'لا توجد مقترحات مسجلة حالياً ✅',
                      style: TextStyle(color: AppDesignTokens.textSecondary(context), fontSize: 13),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: leaderState.summaries.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final s = leaderState.summaries[index];
                    return AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          AppAvatar(
                            name: s.studentName,
                            size: AppAvatarSize.small,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.studentName,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppDesignTokens.textPrimary(context)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${s.studentGroup == StudentGroup.groupA ? l10n.groupA : l10n.groupB} • صباحي: ${s.prefMorningCount} | طويل: ${s.prefLongCount} | ليلي: ${s.prefNightCount} • ${s.isSubmitted ? 'تم الإرسال 📨' : 'مسودة 📝'}',
                                  style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                                ),
                              ],
                            ),
                          ),
                          AppBadge(
                            label: s.totalPrefCount == 0
                                ? 'لم يبدأ (0/12)'
                                : (s.totalPrefCount == 12 && s.isPrefComplete
                                    ? 'مكتمل ومستوفٍ (12/12) ✅'
                                    : (s.totalPrefCount > 12
                                        ? '${s.totalPrefCount}/12 (زيادة ${s.totalPrefCount - 12}) ⚠️'
                                        : '${s.totalPrefCount}/12 (متبقي ${12 - s.totalPrefCount}) ⏳')),
                            variant: s.totalPrefCount == 12 && s.isPrefComplete
                                ? AppBadgeVariant.success
                                : (s.totalPrefCount > 12
                                    ? AppBadgeVariant.danger
                                    : (s.totalPrefCount == 0 ? AppBadgeVariant.neutral : AppBadgeVariant.warning)),
                            size: AppBadgeSize.small,
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
