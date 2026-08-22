import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading_skeleton.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../auth/providers/auth_provider.dart';
import '../../departments/models/department.dart';
import '../../departments/providers/department_provider.dart';
import '../../evaluations/screens/evaluation_logger_screen.dart';
import '../../handover/screens/shift_handover_screen.dart';
import '../../knowledge/screens/knowledge_article_form_screen.dart';
import '../../quizzes/screens/quiz_create_screen.dart';
import '../../roster/screens/roster_overview_screen.dart';

class DoctorDashboardScreen extends ConsumerWidget {
  const DoctorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final doctorId = user?.id ?? '';
    final dutiesAsync = ref.watch(doctorDutiesProvider(doctorId));
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor Header Card
              AppCard(
                padding: const EdgeInsets.all(16),
                variant: AppCardVariant.accentTeal,
                child: Row(
                  children: [
                    AppAvatar(
                      name: user?.fullName ?? 'د. طارق السويفي',
                      imageUrl: user?.avatarUrl,
                      size: AppAvatarSize.medium,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? 'د. طارق السويفي',
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
                                '${l10n.universityCodeLabel} ${user?.universityCode ?? "DOC-044"}',
                                style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Assigned Departments Section
              AppSectionHeader(
                title: 'الأقسام المسؤول عنها',
                subtitle: 'إشراف سريري مباشر وتوزيع الطلاب بمستشفى مطروح العام',
              ),
              const SizedBox(height: 8),

              dutiesAsync.when(
                loading: () => const AppLoadingSkeleton(itemCount: 2, height: 160),
                error: (err, _) => AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Text('حدث خطأ أثناء تحميل بيانات الإشراف: $err'),
                ),
                data: (duties) {
                  if (duties.isEmpty) {
                    return const AppEmptyState(
                      title: 'لم يتم تكليفك بأي قسم حتى الآن',
                      message: 'ستظهر هنا الأقسام السريرية المسندة إليك من قبل إدارة الكلية فور اعتماد التكليف.',
                      icon: Icons.domain_disabled_rounded,
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: duties.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final duty = duties[index];
                      return _buildDoctorDutyCard(context, duty);
                    },
                  );
                },
              ),

              const SizedBox(height: 20),

              // Quick Evaluation Logger Action Card
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

              // Quick Overview of Roster Distribution
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.isArabic ? 'نظرة عامة على الروستر وتغطية الأقسام' : 'Roster Overview & Hospital Coverage',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AppDesignTokens.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.isArabic ? 'التحقق من جداول شيفتات الطلاب والتغطية في مستشفى مطروح العام.' : 'Review intern shifts and hospital departmental coverage.',
                      style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context)),
                    ),
                    const SizedBox(height: 14),
                    AppButton(
                      text: l10n.viewCombinedRoster,
                      icon: Icons.table_chart_rounded,
                      variant: AppButtonVariant.secondary,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RosterOverviewScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Quick Quizzes & Knowledge CMS Card
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أدوات المشرف (الاختبارات والمكتبة الطبية)',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AppDesignTokens.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'إنشاء وتعيين كويزات تقييمية للطلاب أو إضافة إجراءات ومراجع إكلينيكية جديدة للمكتبة.',
                      style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context)),
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
    );
  }

  Widget _buildDoctorDutyCard(BuildContext context, DoctorDepartmentDuty duty) {
    return AppCard(
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
                      duty.nameAr,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: AppDesignTokens.textPrimary(context),
                      ),
                    ),
                    const Text(
                      'أنت المسؤول الطبي المعتمد عن هذا القسم',
                      style: TextStyle(fontSize: 11, color: AppDesignTokens.success, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              AppBadge(
                label: 'الإجمالي: ${duty.currentTotal} / ${duty.totalCapacity}',
                variant: AppBadgeVariant.primary,
                size: AppBadgeSize.small,
              ),
            ],
          ),

          const Divider(height: 20),

          // Students Breakdown
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppDesignTokens.surfaceMuted(context),
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('👨 الذكور', '${duty.currentMale} / ${duty.maleCapacity}', 'المتبقي: ${duty.remainingMale}', AppDesignTokens.info),
                Container(height: 36, width: 1, color: AppDesignTokens.border(context)),
                _buildStatColumn('👩 الإناث', '${duty.currentFemale} / ${duty.femaleCapacity}', 'المتبقي: ${duty.remainingFemale}', AppDesignTokens.primary),
                Container(height: 36, width: 1, color: AppDesignTokens.border(context)),
                _buildStatColumn('📝 المعلقة', '${duty.evaluationsCount} تقييم', '${duty.pendingHandoversCount} تسليم', AppDesignTokens.warning),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Quick Action buttons
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: 'عرض الروستر',
                  icon: Icons.calendar_month_rounded,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.small,
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RosterOverviewScreen()));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  text: 'التقييمات',
                  icon: Icons.rate_review_rounded,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EvaluationLoggerScreen()));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  text: 'التسليم',
                  icon: Icons.sync_alt_rounded,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ShiftHandoverScreen()));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, String sub, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        Text(sub, style: const TextStyle(fontSize: 10, color: AppDesignTokens.slateMuted)),
      ],
    );
  }
}
