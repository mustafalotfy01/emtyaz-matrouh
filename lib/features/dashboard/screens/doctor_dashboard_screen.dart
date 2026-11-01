import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/utils/timezone_helper.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../attendance/providers/clinical_training_provider.dart';
import '../../attendance/repositories/clinical_training_repository.dart';
import '../../attendance/screens/group_clinical_management_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../evaluations/screens/evaluation_logger_screen.dart';
import '../../handover/screens/shift_handover_screen.dart';
import '../../knowledge/screens/knowledge_article_form_screen.dart';
import '../../quizzes/screens/quiz_create_screen.dart';
import '../../roster/screens/roster_overview_screen.dart';

class DoctorDashboardScreen extends ConsumerWidget {
  const DoctorDashboardScreen({super.key});

  static const List<String> arabicMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];

  static const List<String> arabicDays = [
    'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final doctorId = user?.id ?? '';
    final groupsAsync = ref.watch(doctorDashboardGroupsProvider(doctorId));
    final l10n = context.l10n;

    final cairoNow = AppTimezoneHelper.serverNowUtc;
    final dayName = arabicDays[cairoNow.weekday - 1];
    final monthName = arabicMonths[cairoNow.month - 1];
    final formattedDateAr = '$dayName، ${cairoNow.day} $monthName ${cairoNow.year}';

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(doctorDashboardGroupsProvider(doctorId));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Doctor Header Card ──────────────────────────────────
                AppCard(
                  padding: const EdgeInsets.all(16),
                  variant: AppCardVariant.accentTeal,
                  child: Row(
                    children: [
                      AppAvatar(
                        name: user?.fullName ?? 'المشرف الطبي',
                        imageUrl: user?.avatarUrl,
                        size: AppAvatarSize.medium,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.fullName ?? 'المشرف الطبي',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                color: AppDesignTokens.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                AppBadge(
                                  label: l10n.roleDoctor,
                                  variant: AppBadgeVariant.primary,
                                  size: AppBadgeSize.small,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${l10n.universityCodeLabel} ${user?.universityCode ?? "DOC-01"}',
                                  style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formattedDateAr,
                              style: const TextStyle(fontSize: 11, color: AppDesignTokens.primary, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // ── 2. Assigned Groups Section (Doctor's Scope Only) ───────
                AppSectionHeader(
                  title: 'الجروبات المسندة إليك سريرياً',
                  subtitle: 'متابعة الحضور الميداني، الروستر، والتقارير للطلاب تحت إشرافك',
                ),
                const SizedBox(height: 10),

                groupsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Text('حدث خطأ أثناء تحميل بيانات الإشراف: $err'),
                  ),
                  data: (groups) {
                    if (groups.isEmpty) {
                      return const AppEmptyState(
                        title: 'لم يتم تكليفك بأي جروب حتى الآن',
                        message: 'ستظهر هنا الجروبات السريرية المرتبطة بك فور اعتماد تكليفك كمشرف طبي عليها.',
                        icon: Icons.groups_outlined,
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: groups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final g = groups[index];
                        return _buildDoctorGroupCard(context, g);
                      },
                    );
                  },
                ),

                const SizedBox(height: 22),

                // ── 3. Quick Action: Evaluation Logger ─────────────────────
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.isArabic ? 'تقييم أداء طالب / تسجيل إشادة أو تنبيه' : 'Student Clinical Evaluation / Feedback',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: AppDesignTokens.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.isArabic ? 'تسجيل الملاحظات السريرية، المهارات الإجرائية، ونقاط الانضباط للطلاب.' : 'Record clinical observations, procedural skills, and commendations.',
                        style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context)),
                      ),
                      const SizedBox(height: 14),
                      AppButton(
                        text: l10n.isArabic ? 'فتح سجل التقييمات السريرية' : 'Open Clinical Evaluations',
                        icon: Icons.rate_review_rounded,
                        variant: AppButtonVariant.primary,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EvaluationLoggerScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── 4. Shift Handover & Combined Roster ────────────────────
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تسليم النوبتجيات ونظرة عامة على الروستر',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'متابعة الحالات السريرية في قسمك وتغطية الشيفتات بمستشفى مطروح العام.',
                        style: TextStyle(fontSize: 12, color: AppDesignTokens.slateMuted),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              text: 'تسليم الشيفت',
                              icon: Icons.sync_alt_rounded,
                              variant: AppButtonVariant.secondary,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ShiftHandoverScreen()),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppButton(
                              text: 'جدول الروستر العام',
                              icon: Icons.table_chart_rounded,
                              variant: AppButtonVariant.secondary,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const RosterOverviewScreen()),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── 5. Quizzes & Medical Library CMS ───────────────────────
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'أدوات المشرف (الاختبارات والمكتبة الطبية)',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'إنشاء كويزات تقييمية للطلاب أو إضافة إجراءات ومراجع إكلينيكية جديدة للمكتبة.',
                        style: TextStyle(fontSize: 12, color: AppDesignTokens.slateMuted),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              text: 'إنشاء كويز جديد',
                              icon: Icons.add_task_rounded,
                              variant: AppButtonVariant.primary,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const QuizCreateScreen()),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppButton(
                              text: 'إضافة للمكتبة',
                              icon: Icons.post_add_rounded,
                              variant: AppButtonVariant.secondary,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const KnowledgeArticleFormScreen()),
                                );
                              },
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
        ),
      ),
    );
  }

  Widget _buildDoctorGroupCard(BuildContext context, GroupCardSummary g) {
    final hasUnrecorded = g.unrecordedToday > 0;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppDesignTokens.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                ),
                child: const Icon(Icons.domain_rounded, color: AppDesignTokens.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.groupName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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

          if (hasUnrecorded) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFFD97706)),
                  const SizedBox(width: 5),
                  Text(
                    'يوجد ${g.unrecordedToday} طالب بانتظار استكمال تسجيل المرور',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFFD97706), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],

          const Divider(height: 18),

          // Attendance stats & Open button
          Row(
            children: [
              _buildAttendanceMetric('حاضر', '${g.presentToday}', AppDesignTokens.success),
              const SizedBox(width: 8),
              _buildAttendanceMetric('غياب', '${g.absentToday}', AppDesignTokens.danger),
              const SizedBox(width: 8),
              _buildAttendanceMetric('غير مسجل', '${g.unrecordedToday}', AppDesignTokens.warning),

              const Spacer(),

              // Manage Group Button
              AppButton(
                text: 'إدارة الجروب',
                icon: Icons.launch_rounded,
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
