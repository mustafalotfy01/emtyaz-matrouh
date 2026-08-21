import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ios/app_card.dart';
import '../../../core/widgets/ios/app_section_header.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../../attendance/screens/students_map_overview_screen.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/student_approvals_provider.dart';
import '../../roster/models/roster_preference.dart';
import '../../roster/providers/roster_provider.dart';
import '../../notifications/screens/send_notification_screen.dart';

class LeaderDashboardScreen extends ConsumerWidget {
  const LeaderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderState = ref.watch(leaderRosterProvider);
    final studentsAsync = ref.watch(studentApprovalsProvider);
    final attendanceState = ref.watch(attendanceProvider);
    final l10n = context.l10n;

    final totalStudentsCount = studentsAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    final pendingSubmissions = leaderState.summaries
        .where((s) => s.submissionStatus != PreferenceStatus.submitted)
        .length;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Leader Header Banner ────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepNavy.withOpacity(0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.white24,
                      radius: 24,
                      child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.isArabic ? 'لوحة تحكم منسق الامتياز' : 'Coordinator Dashboard',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.isArabic ? 'متابعة الجداول، اعتمادات الروستر، وحضور المستشفيات' : 'Monitor schedules, roster approvals, and hospital attendance',
                            style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 2. Student Residence Map Entry Card ────────────────────────
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StudentsMapOverviewScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(color: AppColors.border(context)),
                      boxShadow: AppTheme.iosCardShadow(context),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTeal.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.map_rounded, color: AppColors.primaryTeal, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.isArabic ? 'خريطة توزيع الطلاب ومنازلهم 🗺️' : 'Intern Geographical Map 🗺️',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                  color: AppColors.text(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.isArabic ? 'عرض توزيع سكن الطلاب حول المستشفى (مقيمين / مغتربين)' : 'View student residence geofences around the hospital',
                                style: TextStyle(color: AppColors.subtext(context), fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.subtext(context)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── 2.1 Broadcast Push Notification Entry Card ─────────────────
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SendNotificationScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
                      boxShadow: AppTheme.iosCardShadow(context),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTeal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.campaign_rounded, color: AppColors.primaryTeal, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.isArabic ? 'بث إشعار فوري للطلاب (Push Broadcast) 📢' : 'Broadcast Push Notification 📢',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                  color: AppColors.text(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.isArabic ? 'إرسال تنبيهات الروستر والتدريب للدفعة أو المجموعات أو الأقسام' : 'Send push alerts for roster, groups or departments',
                                style: TextStyle(color: AppColors.subtext(context), fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.subtext(context)),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ── 3. Quick Stats Grid ────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.isArabic ? 'إجمالي الطلاب' : 'Total Interns', style: TextStyle(fontSize: 11.5, color: AppColors.subtext(context))),
                          const SizedBox(height: 4),
                          Text(
                            '$totalStudentsCount',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryTeal),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.isArabic ? 'سجل الحضور' : 'Attendance Log', style: TextStyle(fontSize: 11.5, color: AppColors.subtext(context))),
                          const SizedBox(height: 4),
                          Text(
                            '${attendanceState.history.length}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.success),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.isArabic ? 'بانتظار التقديم' : 'Pending', style: TextStyle(fontSize: 11.5, color: AppColors.subtext(context))),
                          const SizedBox(height: 4),
                          Text(
                            '$pendingSubmissions',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.warning),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── 4. Student Preferences Submissions Status ──────────────────
              AppSectionHeader(
                title: l10n.isArabic ? 'تفضيلات الروستر للطلاب' : 'Intern Shift Proposals',
                subtitle: l10n.isArabic ? 'حالة تسليم المقترحات ومراجعة المشرف' : 'Submission status and coordinator review',
                actionText: '${leaderState.summaries.length} ${l10n.isArabic ? "طالب" : "interns"}',
              ),
              const SizedBox(height: 10),

              if (leaderState.summaries.isEmpty)
                AppCard(
                  padding: const EdgeInsets.all(30),
                  child: Center(
                    child: Text(
                      l10n.isArabic ? 'لا توجد بيانات تفضيلات طلاب مسجلة حالياً ✅' : 'No intern proposals recorded yet ✅',
                      style: TextStyle(color: AppColors.subtext(context), fontSize: 13),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: leaderState.summaries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final s = leaderState.summaries[index];
                    return AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryTeal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.person_rounded, color: AppColors.primaryTeal, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.studentName,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.text(context)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${s.studentGroup == StudentGroup.groupA ? l10n.groupA : l10n.groupB} • ${l10n.shiftMorningLetter}: ${s.prefMorningCount} | ${l10n.shiftLongLetter}: ${s.prefLongCount} | ${l10n.shiftNightLetter}: ${s.prefNightCount}',
                                  style: TextStyle(fontSize: 11.5, color: AppColors.subtext(context)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: s.isPrefComplete ? AppColors.successLight : AppColors.warningLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              s.isPrefComplete ? (l10n.isArabic ? 'مكتمل (12)' : 'Done (12)') : (l10n.isArabic ? 'قيد الاختيار' : 'In Progress'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: s.isPrefComplete ? AppColors.success : AppColors.warning,
                              ),
                            ),
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
