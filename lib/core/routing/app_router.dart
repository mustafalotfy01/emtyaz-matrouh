import 'package:go_router/go_router.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/student_approvals_screen.dart';
import '../../features/dashboard/screens/main_navigation_screen.dart';
import '../../features/app_versions/screens/app_versions_screen.dart';
import '../../features/groups/screens/dynamic_groups_management_screen.dart';
import '../../features/notifications/screens/fcm_debug_screen.dart';
import '../../features/notifications/screens/notification_center_screen.dart';
import '../../features/notifications/screens/send_notification_screen.dart';
import '../../features/attendance/screens/group_clinical_management_screen.dart';
import '../../features/attendance/screens/student_clinical_profile_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/main',
      builder: (context, state) => const MainNavigationScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationCenterScreen(),
    ),
    GoRoute(
      path: '/send-notification',
      builder: (context, state) => const SendNotificationScreen(),
    ),
    GoRoute(
      path: '/approvals',
      builder: (context, state) => const StudentApprovalsScreen(),
    ),
    GoRoute(
      path: '/groups',
      builder: (context, state) => const DynamicGroupsManagementScreen(),
    ),
    GoRoute(
      path: '/clinical-group',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return GroupClinicalManagementScreen(
          groupId: extra?['groupId'] ?? '',
          groupName: extra?['groupName'] ?? 'جروب الامتياز',
          initialDepartmentName: extra?['departmentName'],
          initialDoctorName: extra?['doctorName'],
        );
      },
    ),
    GoRoute(
      path: '/clinical-profile',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return StudentClinicalProfileScreen(
          studentId: extra?['studentId'] ?? '',
          studentName: extra?['studentName'] ?? 'طالب الامتياز',
          universityCode: extra?['universityCode'] ?? '',
          avatarUrl: extra?['avatarUrl'],
        );
      },
    ),
    GoRoute(
      path: '/fcm-debug',
      builder: (context, state) => const FcmDebugScreen(),
    ),
    GoRoute(
      path: '/app-versions',
      builder: (context, state) => const AppVersionsScreen(),
    ),
  ],
);
