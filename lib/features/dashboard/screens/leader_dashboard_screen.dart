import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/utils/timezone_helper.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../app_versions/screens/app_versions_screen.dart';
import '../../attendance/providers/clinical_training_provider.dart';
import '../../attendance/repositories/clinical_training_repository.dart';
import '../../attendance/screens/group_clinical_management_screen.dart';
import '../../attendance/screens/students_map_overview_screen.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/student_approvals_provider.dart';
import '../../auth/screens/student_approvals_screen.dart';
import '../../leaderboard/screens/clinical_leaderboard_screen.dart';
import '../../notifications/screens/send_notification_screen.dart';
import '../../roster/providers/roster_provider.dart';
import '../../roster/screens/final_approved_roster_screen.dart';

class LeaderDashboardScreen extends ConsumerWidget {
  const LeaderDashboardScreen({super.key});

  static const List<String> arabicMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];

  static const List<String> arabicDays = [
    'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(leaderDashboardSummaryProvider);
    final studentsAsync = ref.watch(studentApprovalsProvider);
    final l10n = context.l10n;

    final cairoNow = AppTimezoneHelper.serverNowUtc;
    final dayName = arabicDays[cairoNow.weekday - 1];
    final monthName = arabicMonths[cairoNow.month - 1];
    final formattedDateAr = '$dayName، ${cairoNow.day} $monthName ${cairoNow.year}';

    final pendingApprovalCount = studentsAsync.maybeWhen(
      data: (list) => list.where((s) => s.registrationStatus == RegistrationStatus.pending).length,
      orElse: () => 0,
    );

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(leaderDashboardSummaryProvider);
            ref.invalidate(studentApprovalsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Top Hub Header ──────────────────────────────────────
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
                          Icons.local_hospital_rounded,
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
                              l10n.isArabic ? 'إدارة التدريب الإكلينيكي والامتياز' : 'Clinical Training Management',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                color: AppDesignTokens.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 12, color: AppDesignTokens.primary),
                                const SizedBox(width: 5),
                                Text(
                                  formattedDateAr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppDesignTokens.textSecondary(context),
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

                const SizedBox(height: 14),

                // ── 2. Morning Pass (8:30) Notice ──────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.alarm_on_rounded, color: Color(0xFFD97706), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'تنبيه المرور الصباحي الميداني (08:30 AM)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: Color(0xFF92400E),
                              ),
                            ),
                            Text(
                              'قم بفتح الجروب وتسجيل حالة الطلاب (موجود / غياب / عارضة) وحفظ الكشف مرة واحدة.',
                              style: TextStyle(fontSize: 11, color: Colors.brown.shade700, height: 1.2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── 3. High-level KPIs Grid ────────────────────────────────
                summaryAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Text('حدث خطأ أثناء تحميل المؤشرات: $err'),
                  ),
                  data: (summary) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildKpiCard(
                                context,
                                'عدد الجروبات',
                                '${summary.groupsCount}',
                                AppDesignTokens.primary,
                                Icons.group_work_rounded,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildKpiCard(
                                context,
                                'إجمالي الطلاب',
                                '${summary.totalStudents}',
                                const Color(0xFF0284C7),
                                Icons.school_rounded,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildKpiCard(
                                context,
                                'حاضر اليوم',
                                '${summary.presentToday}',
                                AppDesignTokens.success,
                                Icons.check_circle_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildKpiCard(
                                context,
                                'غائب اليوم',
                                '${summary.absentToday}',
                                AppDesignTokens.danger,
                                Icons.cancel_rounded,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildKpiCard(
                                context,
                                'لم يُسجل بعد',
                                '${summary.unrecordedToday}',
                                AppDesignTokens.warning,
                                Icons.hourglass_empty_rounded,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 20),

                // ── 4. Group Cards (Clinical Management Hub) ───────────────
                AppSectionHeader(
                  title: 'جروبات الامتياز والتدريب السريري',
                  subtitle: 'مستشفى مطروح العام — متابعة الحضور والروستر والتقارير لكل جروب',
                ),
                const SizedBox(height: 10),

                summaryAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => const SizedBox.shrink(),
                  data: (summary) {
                    if (summary.groups.isEmpty) {
                      return const AppEmptyState(
                        title: 'لا توجد جروبات نشطة مسجلة',
                        message: 'ستظهر هنا الجروبات فور إنشائها وتسكين الطلاب بها.',
                        icon: Icons.groups_outlined,
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: summary.groups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final g = summary.groups[index];
                        return _buildGroupCard(context, g);
                      },
                    );
                  },
                ),

                const SizedBox(height: 24),

                // ── 5. Quick Administrative Tools ──────────────────────────
                AppSectionHeader(
                  title: 'أدوات وإشراف الامتياز',
                  subtitle: 'الاعتمادات، البث الفوري، وإحصائيات الطلاب',
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.all(12),
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
                                  const Text('طلبات التسجيل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                  Text('$pendingApprovalCount بانتظار الاعتماد', style: TextStyle(fontSize: 10.5, color: AppDesignTokens.textSecondary(context))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.all(12),
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
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('بث إشعار فوري', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                  Text('تنبيه الجروبات والأقسام', style: TextStyle(fontSize: 10.5, color: AppDesignTokens.slateMuted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.all(12),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const FinalApprovedRosterScreen()),
                          );
                        },
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppDesignTokens.success.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                              ),
                              child: const Icon(Icons.table_chart_rounded, color: AppDesignTokens.success, size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('الروستر الشهري العام', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                  Text('اعتماد ونشر الجداول', style: TextStyle(fontSize: 10.5, color: AppDesignTokens.slateMuted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.all(12),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ClinicalLeaderboardScreen()),
                          );
                        },
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                              ),
                              child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFD97706), size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('لوحة المتصدرين', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                  Text('ترتيب وتفوق الطلاب', style: TextStyle(fontSize: 10.5, color: AppDesignTokens.slateMuted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // GPS Map Overview Card
                AppCard(
                  padding: const EdgeInsets.all(12),
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
                            Text('خريطة توزيع الطلاب وسكنهم الميداني', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppDesignTokens.textPrimary(context))),
                            Text('توزيع المقيمين والمغتربين حول مستشفى مطروح العام', style: TextStyle(fontSize: 10.5, color: AppDesignTokens.textSecondary(context))),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard(
    BuildContext context,
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, GroupCardSummary g) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Group Name & Department
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppDesignTokens.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                ),
                child: const Icon(Icons.group_rounded, color: AppDesignTokens.primary, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.groupName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'القسم: ${g.departmentName}',
                      style: TextStyle(fontSize: 11.5, color: AppDesignTokens.textSecondary(context)),
                    ),
                  ],
                ),
              ),
              AppBadge(
                label: '${g.studentCount} طالب',
                variant: AppBadgeVariant.neutral,
                size: AppBadgeSize.small,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Doctor name
          Row(
            children: [
              const Icon(Icons.person_pin_rounded, size: 14, color: AppDesignTokens.slateMuted),
              const SizedBox(width: 6),
              Text(
                'المشرف الطبي: ${g.doctorName}',
                style: TextStyle(fontSize: 11.5, color: AppDesignTokens.textSecondary(context)),
              ),
            ],
          ),

          const Divider(height: 18),

          // Attendance stats & Action Button
          Row(
            children: [
              _buildAttendanceMetric('حاضر', '${g.presentToday}', AppDesignTokens.success),
              const SizedBox(width: 8),
              _buildAttendanceMetric('غياب', '${g.absentToday}', AppDesignTokens.danger),
              const SizedBox(width: 8),
              _buildAttendanceMetric('غير مسجل', '${g.unrecordedToday}', AppDesignTokens.warning),

              const Spacer(),

              // Open Group Button
              AppButton(
                text: 'فتح الجروب',
                icon: Icons.login_rounded,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroupClinicalManagementScreen(
                        groupId: g.groupId,
                        groupName: g.groupName,
                        initialDepartmentName: g.departmentName,
                        initialDoctorName: g.doctorName,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 10.5, color: color)),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
