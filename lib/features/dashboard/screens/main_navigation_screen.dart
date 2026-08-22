import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/platform_service.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/ios/app_bottom_nav.dart';
import '../../../core/widgets/ios/language_segmented_control.dart';
import '../../../core/services/app_update_service.dart';
import '../../profile/widgets/app_update_dialog.dart';
import '../../attendance/screens/attendance_checkin_screen.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/student_approvals_screen.dart';
import '../../community/screens/community_screen.dart';
import '../../disciplinary/screens/admin_disciplinary_review_screen.dart';
import '../../fingerprint/screens/fingerprint_log_screen.dart';
import '../../knowledge/screens/knowledge_library_screen.dart';
import '../../notifications/screens/notification_center_screen.dart';
import '../../profile/profile_screen.dart';
import '../../quizzes/screens/quiz_list_screen.dart';
import '../../roster/screens/roster_calendar_screen.dart';
import '../../roster/screens/roster_overview_screen.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForAppUpdate();
    });
  }

  Future<void> _checkForAppUpdate() async {
    try {
      final info = await AppUpdateService.checkForUpdates();
      if (info.hasUpdate && mounted) {
        AppUpdateModal.showUpdateDialog(context, info);
      }
    } catch (_) {
      // Gracefully ignore startup check errors
    }
  }

  void _navigateToTab(int index) => setState(() => _currentIndex = index);

  List<AppNavItem> _buildNavItems(UserProfile? currentUser, AppLocalizations l10n) {
    final role = currentUser?.role ?? UserRole.student;

    if (role == UserRole.superAdmin) {
      return [
        AppNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: l10n.navHome,
        ),
        const AppNavItem(
          icon: Icons.how_to_reg_outlined,
          activeIcon: Icons.how_to_reg_rounded,
          label: 'المستخدمون',
        ),
        const AppNavItem(
          icon: Icons.fingerprint_outlined,
          activeIcon: Icons.fingerprint_rounded,
          label: 'البصمة',
        ),
        const AppNavItem(
          icon: Icons.forum_outlined,
          activeIcon: Icons.forum_rounded,
          label: 'المجتمع',
        ),
        AppNavItem(
          icon: Icons.menu_book_outlined,
          activeIcon: Icons.menu_book_rounded,
          label: l10n.navLibrary,
        ),
      ];
    } else if (role == UserRole.evaluatingDoctor) {
      return [
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
          icon: Icons.quiz_outlined,
          activeIcon: Icons.quiz_rounded,
          label: l10n.navQuizzes,
        ),
        const AppNavItem(
          icon: Icons.forum_outlined,
          activeIcon: Icons.forum_rounded,
          label: 'المجتمع',
        ),
        AppNavItem(
          icon: Icons.menu_book_outlined,
          activeIcon: Icons.menu_book_rounded,
          label: l10n.navLibrary,
        ),
      ];
    } else if (role == UserRole.leader) {
      return [
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
        const AppNavItem(
          icon: Icons.fingerprint_outlined,
          activeIcon: Icons.fingerprint_rounded,
          label: 'البصمة',
        ),
        const AppNavItem(
          icon: Icons.forum_outlined,
          activeIcon: Icons.forum_rounded,
          label: 'المجتمع',
        ),
        AppNavItem(
          icon: Icons.menu_book_outlined,
          activeIcon: Icons.menu_book_rounded,
          label: l10n.navLibrary,
        ),
      ];
    }

    // Default Student
    return [
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
      const AppNavItem(
        icon: Icons.forum_outlined,
        activeIcon: Icons.forum_rounded,
        label: 'المجتمع',
      ),
      AppNavItem(
        icon: Icons.fingerprint_outlined,
        activeIcon: Icons.fingerprint_rounded,
        label: l10n.navAttendance,
      ),
      AppNavItem(
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book_rounded,
        label: l10n.navLibrary,
      ),
    ];
  }

  List<Widget> _buildPages(UserProfile? currentUser) {
    final role = currentUser?.role ?? UserRole.student;

    if (role == UserRole.superAdmin) {
      return const [
        AdminDashboardScreen(),
        StudentApprovalsScreen(),
        FingerprintLogScreen(),
        CommunityScreen(),
        KnowledgeLibraryScreen(),
      ];
    } else if (role == UserRole.evaluatingDoctor) {
      return const [
        DoctorDashboardScreen(),
        RosterOverviewScreen(),
        QuizListScreen(),
        CommunityScreen(),
        KnowledgeLibraryScreen(),
      ];
    } else if (role == UserRole.leader) {
      return const [
        LeaderDashboardScreen(),
        RosterCalendarScreen(),
        FingerprintLogScreen(),
        CommunityScreen(),
        KnowledgeLibraryScreen(),
      ];
    }

    // Student
    return [
      StudentDashboardScreen(onNavigateTab: _navigateToTab),
      const RosterCalendarScreen(),
      const CommunityScreen(),
      const AttendanceCheckinScreen(),
      const KnowledgeLibraryScreen(),
    ];
  }

  List<Widget> _buildActions(BuildContext context, UserProfile? user, AppLocalizations l10n) {
    final role = user?.role;
    final isDoctor = role == UserRole.evaluatingDoctor;
    final isAdmin = role == UserRole.superAdmin;
    final isLeader = role == UserRole.leader;

    return [
      // Compact Language Switcher
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
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
          tooltip: 'مراجعة الجزاءات والمكافآت',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminDisciplinaryReviewScreen()),
          ),
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
    final navItems = _buildNavItems(currentUser, l10n);

    // Safeguard index if role changed
    final safeIndex = _currentIndex < pages.length ? _currentIndex : 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop =
            constraints.maxWidth >= PlatformService.desktopBreakpoint;

        if (isDesktop) {
          return _buildDesktopLayout(context, currentUser, pages, navItems, l10n, safeIndex);
        }
        return _buildMobileLayout(context, currentUser, pages, navItems, l10n, safeIndex);
      },
    );
  }

  Widget _buildMobileLayout(
      BuildContext context, UserProfile? user, List<Widget> pages, List<AppNavItem> navItems, AppLocalizations l10n, int safeIndex) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: _buildAppBar(context, user, l10n),
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: pages[safeIndex],
          ),
          AppFloatingBottomNav(
            currentIndex: safeIndex,
            onTap: (idx) => setState(() => _currentIndex = idx),
            items: navItems,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(
      BuildContext context, UserProfile? user, List<Widget> pages, List<AppNavItem> navItems, AppLocalizations l10n, int safeIndex) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: _buildAppBar(context, user, l10n),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: safeIndex,
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
          Expanded(child: pages[safeIndex]),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, UserProfile? user, AppLocalizations l10n) {
    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.bg(context),
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      leading: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
        child: AppLogo(fit: BoxFit.contain),
      ),
      actions: _buildActions(context, user, l10n),
    );
  }
}
