import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/custom_card.dart';
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
    final l10n = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Text(
          isAr ? 'مركز التنبيهات والإشعارات' : 'Notification Center',
          style: TextStyle(
            color: AppColors.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          if (isStaff)
            IconButton(
              icon: const Icon(Icons.campaign_outlined, color: AppColors.primaryTeal),
              tooltip: isAr ? 'إرسال إشعار فوري للطلاب 📢' : 'Broadcast Push Notification',
              onPressed: () => context.push('/send-notification'),
            ),
          if (state.unreadCount > 0)
            TextButton.icon(
              onPressed: () {
                ref.read(notificationsProvider.notifier).markAllAsRead();
              },
              icon: const Icon(Icons.done_all, size: 18, color: AppColors.primaryTeal),
              label: Text(
                isAr ? 'تحديد الكل كمقروء' : 'Mark all read',
                style: const TextStyle(fontSize: 12, color: AppColors.primaryTeal, fontWeight: FontWeight.w600),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(notificationsProvider.notifier).fetchNotifications();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(notificationsProvider.notifier).fetchNotifications(),
        child: state.isLoading && state.items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : state.items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 64,
                            color: AppColors.subtext(context).withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isAr ? 'لا توجد إشعارات جديدة حالياً' : 'No notifications yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isAr
                                ? 'ستصلك هنا إشعارات فورية عند تسجيل الطلاب الجدد، واعتماد الشيفتات والتكليفات.'
                                : 'You will receive instant alerts here for new registrations, roster approvals, and shift assignments.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.subtext(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: state.items.length,
                    itemBuilder: (context, idx) {
                      final item = state.items[idx];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: InkWell(
                          onTap: () => _handleNotificationTap(item),
                          borderRadius: BorderRadius.circular(16),
                          child: CustomCard(
                            borderColor: item.isRead ? null : item.color.withValues(alpha: 0.4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: item.color.withValues(alpha: 0.12),
                                      child: Icon(item.icon, color: item.color, size: 20),
                                    ),
                                    if (!item.isRead)
                                      Positioned(
                                        top: 0,
                                        right: isAr ? null : 0,
                                        left: isAr ? 0 : null,
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: item.color,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: AppColors.card(context), width: 1.5),
                                          ),
                                        ),
                                      ),
                                  ],
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
                                                fontSize: 14,
                                                color: AppColors.text(context),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatNotificationTime(item.createdAt, context),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.subtext(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        item.message,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          height: 1.35,
                                          color: item.isRead
                                              ? AppColors.subtext(context)
                                              : AppColors.text(context).withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
