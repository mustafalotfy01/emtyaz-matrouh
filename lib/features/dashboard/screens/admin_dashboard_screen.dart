import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ios/app_card.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              // Admin Banner
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
                      child: Icon(Icons.shield_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.isArabic ? 'لوحة تحكم الإدارة العليا (Super Admin)' : 'Super Admin Dashboard',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.isArabic
                                ? 'إدارة الحسابات، الأقسام، النطاق الجغرافي (Geofencing)، والتقارير العامة'
                                : 'Manage accounts, departments, geofences, and clinical audit reports',
                            style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // System Control Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  _buildAdminTile(
                    context,
                    Icons.people_alt_rounded,
                    l10n.isArabic ? 'إدارة الحسابات والأدوار' : 'Users & Roles',
                    l10n.isArabic ? '120 طالب • 6 منسقين' : '120 Interns • 6 Coordinators',
                    AppColors.primaryTeal,
                  ),
                  _buildAdminTile(
                    context,
                    Icons.domain_rounded,
                    l10n.isArabic ? 'إدارة الأقسام الطبية' : 'Hospital Departments',
                    l10n.isArabic ? '6 أقسام نشطة' : '6 Active Units',
                    AppColors.secondaryTeal,
                  ),
                  _buildAdminTile(
                    context,
                    Icons.pin_drop_rounded,
                    l10n.isArabic ? 'نطاقات Geofence' : 'Geofence Boundaries',
                    l10n.isArabic ? 'مستشفى مطروح العام (150م)' : 'Matrouh Hospital (150m)',
                    AppColors.info,
                  ),
                  _buildAdminTile(
                    context,
                    Icons.menu_book_rounded,
                    l10n.isArabic ? 'إدارة المحتوى التعليمي' : 'Clinical Knowledge',
                    l10n.isArabic ? '18 موضوع • 5 إجراءات' : '18 Topics • 5 Procedures',
                    AppColors.success,
                  ),
                  _buildAdminTile(
                    context,
                    Icons.pie_chart_rounded,
                    l10n.isArabic ? 'التقارير والإحصائيات' : 'Reports & Analytics',
                    l10n.isArabic ? 'سجل الحضور والتراكمي' : 'Cumulative attendance logs',
                    AppColors.warning,
                  ),
                  _buildAdminTile(
                    context,
                    Icons.history_toggle_off_rounded,
                    l10n.isArabic ? 'سجل المراجعة (Audit Logs)' : 'Audit Logs',
                    l10n.isArabic ? 'تتبع الأنشطة والأمان' : 'Activity & Security logs',
                    AppColors.danger,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminTile(BuildContext context, IconData icon, String title, String subtitle, Color color) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            radius: 20,
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.text(context)),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: AppColors.subtext(context)),
          ),
        ],
      ),
    );
  }
}
