import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/notification_model.dart';
import '../providers/notifications_provider.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends ConsumerState<NotificationCenterScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(notificationsProvider.notifier).fetchNotifications();
    });
  }

  void _handleNotificationTap(NotificationItem item) {
    ref.read(notificationsProvider.notifier).markAsRead(item.id);

    final targetRoute = item.metadata?['route'];
    if (targetRoute != null && targetRoute.toString().isNotEmpty) {
      context.push(targetRoute.toString());
      return;
    }

    if (item.type == 'NEW_STUDENT_REGISTRATION') {
      context.push('/approvals');
    } else if (item.type == 'ROSTER_APPROVED') {
      context.push('/main');
    } else if (item.type == 'PREFERENCES_REOPENED') {
      context.push('/main');
    }
  }

  String _formatNotificationTime(DateTime time, BuildContext context) {
    final now = DateTime.now();
    final diff = now.difference(time);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    if (diff.inMinutes < 1) {
      return isAr ? 'الآن' : 'Just now';
    } else if (diff.inHours < 1) {
      return isAr ? 'منذ ${diff.inMinutes} دقيقة' : '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return isAr ? 'منذ ${diff.inHours} ساعة' : '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return isAr ? 'أمس' : 'Yesterday';
    } else {
      return DateFormat('yyyy-MM-dd • hh:mm a').format(time);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isStaff = user?.role == UserRole.leader ||
        user?.role == UserRole.superAdmin ||
        user?.role == UserRole.evaluatingDoctor;

    final state = ref.watch(notificationsProvider);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: Text(
          isAr ? 'مركز التنبيهات والإشعارات' : 'Notification Center',
          style: TextStyle(
            color: AppDesignTokens.textPrimary(context),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          if (isStaff)
            IconButton(
              icon: const Icon(Icons.campaign_outlined, color: AppDesignTokens.primary),
              tooltip: isAr ? 'إرسال إشعار فوري للطلاب 📢' : 'Broadcast Push Notification',
              onPressed: () => context.push('/send-notification'),
            ),
          if (state.unreadCount > 0)
            TextButton.icon(
              onPressed: () {
                ref.read(notificationsProvider.notifier).markAllAsRead();
              },
              icon: const Icon(Icons.done_all_rounded, size: 18, color: AppDesignTokens.primary),
              label: Text(
                isAr ? 'تحديد الكل كمقروء' : 'Mark all read',
                style: const TextStyle(fontSize: 12, color: AppDesignTokens.primary, fontWeight: FontWeight.bold),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(notificationsProvider.notifier).fetchNotifications();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppDesignTokens.primary,
        onRefresh: () => ref.read(notificationsProvider.notifier).fetchNotifications(),
        child: state.isLoading && state.items.isEmpty
            ? const Center(child: CircularProgressIndicator(color: AppDesignTokens.primary))
            : state.items.isEmpty
                ? const AppEmptyState(
                    title: 'لا توجد إشعارات جديدة حالياً',
                    message: 'ستصلك هنا إشعارات فورية عند تسجيل الطلاب الجدد واعتماد الشيفتات والتكليفات',
                    icon: Icons.notifications_off_outlined,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: state.items.length,
                    itemBuilder: (context, idx) {
                      final item = state.items[idx];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: AppCard(
                          padding: const EdgeInsets.all(12),
                          variant: item.isRead ? AppCardVariant.standard : AppCardVariant.accentTeal,
                          onTap: () => _handleNotificationTap(item),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: item.color.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(item.icon, color: item.color, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.title,
                                            style: TextStyle(
                                              fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                                              fontSize: 13.5,
                                              color: AppDesignTokens.textPrimary(context),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatNotificationTime(item.createdAt, context),
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: AppDesignTokens.textSecondary(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.message,
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.35,
                                        color: item.isRead
                                            ? AppDesignTokens.textSecondary(context)
                                            : AppDesignTokens.textPrimary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
