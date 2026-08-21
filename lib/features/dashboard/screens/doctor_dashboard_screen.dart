import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ios/app_button.dart';
import '../../../core/widgets/ios/app_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../evaluations/screens/evaluation_logger_screen.dart';
import '../../roster/screens/roster_overview_screen.dart';

class DoctorDashboardScreen extends ConsumerWidget {
  const DoctorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor Header Banner
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
                      child: Icon(Icons.medical_information_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? l10n.roleDoctor,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${l10n.universityCodeLabel} ${user?.universityCode ?? "DOC-01"} | ${l10n.roleDoctor}',
                            style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Quick Evaluation Logger Action Card
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.isArabic ? 'تقييم أداء طالب / تسجيل إشادة أو تنبيه' : 'Student Clinical Evaluation / Feedback',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.isArabic ? 'تسجيل الملاحظات السريرية، المهارات الإجرائية، ونقاط الانضباط للطلاب.' : 'Record clinical observations, procedural skills, and commendations.',
                      style: TextStyle(fontSize: 12, color: AppColors.subtext(context)),
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

              const SizedBox(height: 16),

              // Quick Overview of Roster Distribution
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.isArabic ? 'نظرة عامة على الروستر وتغطية الأقسام' : 'Roster Overview & Hospital Coverage',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.isArabic ? 'التحقق من جداول شيفتات الطلاب والتغطية في مستشفى مطروح العام.' : 'Review intern shifts and hospital departmental coverage.',
                      style: TextStyle(fontSize: 12, color: AppColors.subtext(context)),
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
            ],
          ),
        ),
      ),
    );
  }
}
