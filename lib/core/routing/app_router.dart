import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/student_approvals_screen.dart';
import '../../features/dashboard/screens/main_navigation_screen.dart';
import '../../features/notifications/screens/fcm_debug_screen.dart';
import '../../features/notifications/screens/notification_center_screen.dart';
import '../../features/notifications/screens/send_notification_screen.dart';

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
      path: '/fcm-debug',
      builder: (context, state) => const FcmDebugScreen(),
    ),
  ],
);
