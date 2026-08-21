import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/platform_service.dart';
import '../../../core/widgets/ios/app_bottom_nav.dart';
import '../../../core/widgets/ios/language_segmented_control.dart';
import '../../attendance/screens/attendance_checkin_screen.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/student_approvals_screen.dart';
import '../../disciplinary/screens/leader_discipline_dashboard_screen.dart';
import '../../knowledge/screens/knowledge_library_screen.dart';
import '../../notifications/screens/notification_center_screen.dart';
import '../../profile/profile_screen.dart';
import '../../quizzes/screens/quiz_list_screen.dart';
import '../../roster/screens/roster_calendar_screen.dart';
import 'admin_dashboard_screen.dart';
import 'doctor_dashboard_screen.dart';
import 'leader_dashboard_screen.dart';
import 'student_dashboard_screen.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState
    extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;

  void _navigateToTab(int index) => setState(() => _currentIndex = index);

  List<AppNavItem> _buildNavItems(AppLocalizations l10n) => [
        AppNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: l10n.navHome,
        ),
        AppNavItem(
          icon: Icons.calendar_month_outlined,
          activeIcon: Icons.calendar_month_rounded,
          label: l10n.navRoster,
        ),
        AppNavItem(
          icon: Icons.fingerprint_outlined,
          activeIcon: Icons.fingerprint_rounded,
          label: l10n.navAttendance,
        ),
        AppNavItem(
          icon: Icons.quiz_outlined,
          activeIcon: Icons.quiz_rounded,
          label: l10n.navQuizzes,
        ),
        AppNavItem(
          icon: Icons.menu_book_outlined,
          activeIcon: Icons.menu_book_rounded,
          label: l10n.navLibrary,
        ),
      ];

  List<Widget> _buildPages(UserProfile? currentUser) => [
        if (currentUser?.role == UserRole.student)
          StudentDashboardScreen(onNavigateTab: _navigateToTab)
        else if (currentUser?.role == UserRole.leader)
          const LeaderDashboardScreen()
        else if (currentUser?.role == UserRole.evaluatingDoctor)
          const DoctorDashboardScreen()
        else if (currentUser?.role == UserRole.superAdmin)
          const AdminDashboardScreen()
        else
          StudentDashboardScreen(onNavigateTab: _navigateToTab),
        const RosterCalendarScreen(),
        const AttendanceCheckinScreen(),
        const QuizListScreen(),
        const KnowledgeLibraryScreen(),
      ];

  List<Widget> _buildActions(BuildContext context, UserProfile? user, AppLocalizations l10n) {
    final role = user?.role;
    final isDoctor = role == UserRole.evaluatingDoctor;
    final isAdmin = role == UserRole.superAdmin;
    final isLeader = role == UserRole.leader;

    return [
      // Compact Language Switcher
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: AppLanguageSegmentedControl(),
      ),

      // Registration Requests Approval (Leader / Admin)
      if (isLeader || isAdmin)
        IconButton(
          icon: const Icon(Icons.how_to_reg_outlined, color: AppColors.primaryTeal, size: 22),
          tooltip: 'طلبات تسجيل الطلاب',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StudentApprovalsScreen()),
          ),
        ),

      // Disciplinary Action System (Doctor / Admin ONLY)
      if (isDoctor || isAdmin)
        IconButton(
          icon: const Icon(Icons.gavel_outlined, color: AppColors.primaryTeal, size: 22),
          tooltip: 'نظام الانضباط والجزاءات',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LeaderDisciplineDashboardScreen()),
          ),
        ),

      // Emergency Call (Doctor / Admin ONLY)
      if (isDoctor || isAdmin)
        IconButton(
          icon: const Icon(Icons.emergency_outlined, color: AppColors.danger, size: 22),
          tooltip: 'نداء طوارئ',
          onPressed: () => _showEmergencyDialog(context),
        ),

      // Notifications Center
      IconButton(
        icon: Icon(Icons.notifications_none_rounded, color: AppColors.text(context), size: 22),
        tooltip: l10n.navNotifications,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
        ),
      ),

      // User Profile
      IconButton(
        icon: Icon(Icons.person_outline_rounded, color: AppColors.text(context), size: 22),
        tooltip: l10n.navProfile,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ),
      ),
      const SizedBox(width: 4),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).user;
    final l10n = context.l10n;

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.user == null && mounted) {
        context.go('/login');
      }
    });

    final pages = _buildPages(currentUser);
    final navItems = _buildNavItems(l10n);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop =
            constraints.maxWidth >= PlatformService.desktopBreakpoint;

        if (isDesktop) {
          return _buildDesktopLayout(context, currentUser, pages, navItems, l10n);
        }
        return _buildMobileLayout(context, currentUser, pages, navItems, l10n);
      },
    );
  }

  Widget _buildMobileLayout(
      BuildContext context, UserProfile? user, List<Widget> pages, List<AppNavItem> navItems, AppLocalizations l10n) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: _buildAppBar(context, user, l10n),
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: pages[_currentIndex],
          ),
          AppFloatingBottomNav(
            currentIndex: _currentIndex,
            onTap: (idx) => setState(() => _currentIndex = idx),
            items: navItems,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(
      BuildContext context, UserProfile? user, List<Widget> pages, List<AppNavItem> navItems, AppLocalizations l10n) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: _buildAppBar(context, user, l10n),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: (idx) =>
                setState(() => _currentIndex = idx),
            labelType: NavigationRailLabelType.all,
            selectedIconTheme:
                const IconThemeData(color: AppColors.primaryTeal),
            selectedLabelTextStyle:
                const TextStyle(color: AppColors.primaryTeal, fontSize: 11, fontWeight: FontWeight.bold),
            unselectedIconTheme:
                IconThemeData(color: AppColors.subtext(context)),
            unselectedLabelTextStyle:
                TextStyle(color: AppColors.subtext(context), fontSize: 11),
            destinations: navItems
                .map((item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.activeIcon),
                      label: Text(item.label),
                    ))
                .toList(),
          ),
          VerticalDivider(width: 1, thickness: 1, color: AppColors.border(context)),
          Expanded(child: pages[_currentIndex]),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, UserProfile? user, AppLocalizations l10n) {
    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.bg(context),
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Image.asset(AppAssets.logo, fit: BoxFit.contain),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            l10n.appName,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
                letterSpacing: -0.2),
          ),
          Text(
            user?.role.displayNameAr ?? l10n.roleStudent,
            style:
                const TextStyle(fontSize: 11, color: AppColors.primaryTeal, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      actions: _buildActions(context, user, l10n),
    );
  }

  void _showEmergencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.danger, size: 28),
            SizedBox(width: 8),
            Text('نداء طوارئ عاجل',
                style: TextStyle(color: AppColors.danger)),
          ],
        ),
        content: const Text(
          'سيتم إرسال إشعار فوري لجميع طلاب الامتياز والدكاترة الأقرب لقسم الطوارئ بمستشفى مطروح العام للتوجه الفوري لمساندة الطاقم الطبي!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'تم إرسال نداء الطوارئ الفوري بنجاح!'),
                  backgroundColor: AppColors.danger,
                ),
              );
            },
            child: const Text('إرسال الاستدعاء الفوري'),
          ),
        ],
      ),
    );
  }
}
