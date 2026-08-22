import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../attendance/screens/students_map_overview_screen.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/student_approvals_provider.dart';
import '../../auth/screens/student_approvals_screen.dart';
import '../../community/screens/community_screen.dart';
import '../../community/screens/create_post_screen.dart';
import '../../departments/providers/department_provider.dart';
import '../../departments/screens/department_form_screen.dart';
import '../../departments/screens/department_management_screen.dart';
import '../../disciplinary/screens/admin_disciplinary_review_screen.dart';
import '../../fingerprint/screens/fingerprint_log_screen.dart';
import '../../knowledge/screens/knowledge_article_form_screen.dart';
import '../../knowledge/screens/knowledge_library_screen.dart';
import '../../notifications/screens/send_notification_screen.dart';
import '../../app_versions/screens/app_versions_screen.dart';
import '../../quizzes/screens/quiz_create_screen.dart';
import '../../quizzes/screens/quiz_list_screen.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final studentsAsync = ref.watch(studentApprovalsProvider);
    final deptsAsync = ref.watch(departmentsProvider);
    final l10n = context.l10n;

    final totalCount = studentsAsync.maybeWhen(data: (l) => l.length, orElse: () => 0);
    final pendingCount = studentsAsync.maybeWhen(
      data: (l) => l.where((s) => s.registrationStatus == RegistrationStatus.pending).length,
      orElse: () => 0,
    );
    final activeDeptsCount = deptsAsync.maybeWhen(
      data: (l) => l.where((d) => d.isActive).length,
      orElse: () => 0,
    );

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Operations Console Header
              AppCard(
                padding: const EdgeInsets.all(16),
                variant: AppCardVariant.accentTeal,
                child: Row(
                  children: [
                    AppAvatar(
                      name: user?.fullName ?? 'إدارة الكلية',
                      imageUrl: user?.avatarUrl,
                      size: AppAvatarSize.medium,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.isArabic
                                ? 'لوحة تحكم الإدارة العليا (Operations Console)'
                                : 'Super Admin Operations Console',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppDesignTokens.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'إدارة المستخدمين، الأقسام، الانضباط، وسجل البصمة الحيوية',
                            style: TextStyle(fontSize: 11.5, color: AppDesignTokens.textSecondary(context)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // KPI Metrics
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('المستخدمون', style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context))),
                          const SizedBox(height: 4),
                          Text('$totalCount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppDesignTokens.primary)),
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
                          Text('$pendingCount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppDesignTokens.warning)),
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
                          Text('الأقسام النشطة', style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context))),
                          const SizedBox(height: 4),
                          Text('$activeDeptsCount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppDesignTokens.success)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Quick Actions Row (FEATURE 15)
              AppSectionHeader(
                title: 'الإجراءات السريعة (Quick Actions)',
                subtitle: 'تنفيذ العمليات الإدارية الفورية بنقرة واحدة',
              ),
              const SizedBox(height: 8),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickActionChip(
                      context,
                      icon: Icons.domain_add_rounded,
                      label: '+ إضافة قسم',
                      color: AppDesignTokens.primary,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DepartmentFormScreen())),
                    ),
                    const SizedBox(width: 8),
                    _buildQuickActionChip(
                      context,
                      icon: Icons.add_task_rounded,
                      label: '+ إضافة اختبار',
                      color: AppDesignTokens.shiftLong,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizCreateScreen())),
                    ),
                    const SizedBox(width: 8),
                    _buildQuickActionChip(
                      context,
                      icon: Icons.note_add_rounded,
                      label: '+ محتوى للمكتبة',
                      color: AppDesignTokens.info,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KnowledgeArticleFormScreen())),
                    ),
                    const SizedBox(width: 8),
                    _buildQuickActionChip(
                      context,
                      icon: Icons.fingerprint_rounded,
                      label: 'طلب بصمة فوري',
                      color: AppDesignTokens.danger,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FingerprintLogScreen())),
                    ),
                    const SizedBox(width: 8),
                    _buildQuickActionChip(
                      context,
                      icon: Icons.gavel_rounded,
                      label: 'مراجعة الجزاءات',
                      color: AppDesignTokens.warning,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDisciplinaryReviewScreen())),
                    ),
                    const SizedBox(width: 8),
                    _buildQuickActionChip(
                      context,
                      icon: Icons.military_tech_rounded,
                      label: 'مراجعة المكافآت',
                      color: AppDesignTokens.success,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDisciplinaryReviewScreen())),
                    ),
                    const SizedBox(width: 8),
                    _buildQuickActionChip(
                      context,
                      icon: Icons.edit_note_rounded,
                      label: 'نشر في المجتمع',
                      color: AppDesignTokens.navyDark,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen())),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Modules Grid (FEATURE 14)
              AppSectionHeader(
                title: 'إدارة وحدات النظام الأساسية',
                subtitle: 'التحكم في الصلاحيات، التوزيع الإشرافي، والمحتوى الأكاديمي',
              ),
              const SizedBox(height: 8),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.35,
                children: [
                  // 1. المستخدمون والاعتمادات
                  _buildAdminTile(
                    context,
                    Icons.how_to_reg_rounded,
                    'المستخدمون والاعتمادات',
                    '$pendingCount طلب بانتظار الاعتماد',
                    AppDesignTokens.primary,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentApprovalsScreen())),
                  ),
                  // 2. الأقسام والتوزيع
                  _buildAdminTile(
                    context,
                    Icons.domain_rounded,
                    'الأقسام والتوزيع',
                    'إدارة السعة والأطباء المشرفين',
                    AppDesignTokens.shiftLong,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DepartmentManagementScreen())),
                  ),
                  // 3. الجزاءات والمكافآت
                  _buildAdminTile(
                    context,
                    Icons.gavel_rounded,
                    'الجزاءات والمكافآت',
                    'مراجعة وتطبيق الإجراءات',
                    AppDesignTokens.danger,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDisciplinaryReviewScreen())),
                  ),
                  // 4. بث الإعلانات والتنبيهات
                  _buildAdminTile(
                    context,
                    Icons.campaign_rounded,
                    'بث الإعلانات والتنبيهات',
                    'إرسال إشعار فوري للدفعة',
                    AppDesignTokens.warning,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SendNotificationScreen())),
                  ),
                  // 5. سجل البصمة
                  _buildAdminTile(
                    context,
                    Icons.fingerprint_rounded,
                    'سجل البصمة',
                    'متابعة طلبات تأكيد الحضور',
                    AppDesignTokens.success,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FingerprintLogScreen())),
                  ),
                  // 6. الاختبارات
                  _buildAdminTile(
                    context,
                    Icons.quiz_rounded,
                    'الاختبارات السريرية',
                    'إعداد بنك الأسئلة والتقييم',
                    AppDesignTokens.info,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizListScreen())),
                  ),
                  // 7. المجتمع
                  _buildAdminTile(
                    context,
                    Icons.forum_rounded,
                    'المجتمع السريري',
                    'منشورات الحالات والخبرات',
                    AppDesignTokens.shiftMorning,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunityScreen())),
                  ),
                  // 8. المكتبة
                  _buildAdminTile(
                    context,
                    Icons.menu_book_rounded,
                    'المكتبة والبروتوكولات',
                    'إدارة المراجع السريرية',
                    AppDesignTokens.primaryAccent,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KnowledgeLibraryScreen())),
                  ),
                  // 9. إصدارات التطبيق (Android APK)
                  _buildAdminTile(
                    context,
                    Icons.system_update_rounded,
                    'إصدارات التطبيق (Android)',
                    'نشر وإدارة ملفات APK والتحديثات',
                    AppDesignTokens.primary,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppVersionsScreen())),
                  ),
                  // 10. GPS Geofence (Kept)
                  _buildAdminTile(
                    context,
                    Icons.pin_drop_rounded,
                    'نطاقات GPS Geofence',
                    'مستشفى مطروح العام (150م)',
                    AppDesignTokens.slateMedium,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentsMapOverviewScreen())),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppDesignTokens.textPrimary(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10.5, color: AppDesignTokens.textSecondary(context)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
