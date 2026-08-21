import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/notification_model.dart';

class NotificationsState {
  final List<NotificationItem> items;
  final bool isLoading;
  final String? errorMessage;

  const NotificationsState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  int get unreadCount => items.where((n) => !n.isRead).length;

  NotificationsState copyWith({
    List<NotificationItem>? items,
    bool? isLoading,
    String? errorMessage,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final Ref _ref;

  NotificationsNotifier(this._ref) : super(const NotificationsState()) {
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    final user = _ref.read(authProvider).user;
    if (user == null || !SupabaseService.isInitialized) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final res = await SupabaseService.adminClient
          .from('notifications')
          .select()
          .or('user_id.eq.${user.id},user_id.is.null')
          .order('created_at', ascending: false)
          .limit(50);

      if (res is List) {
        final notifications = res.map((r) => NotificationItem.fromJson(r)).toList();
        state = state.copyWith(items: notifications, isLoading: false);
      } else {
        state = state.copyWith(items: [], isLoading: false);
      }
    } catch (e) {
      if (kDebugMode) print('[NotificationsNotifier] fetch error: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> markAsRead(String notificationId) async {
    // Optimistic UI update
    final updated = state.items.map((n) {
      if (n.id == notificationId) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();
    state = state.copyWith(items: updated);

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.adminClient
            .from('notifications')
            .update({'is_read': true})
            .eq('id', notificationId);
      } catch (e) {
        if (kDebugMode) print('[NotificationsNotifier] markAsRead error: $e');
      }
    }
  }

  Future<void> markAllAsRead() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    final updated = state.items.map((n) => n.copyWith(isRead: true)).toList();
    state = state.copyWith(items: updated);

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.adminClient
            .from('notifications')
            .update({'is_read': true})
            .or('user_id.eq.${user.id},user_id.is.null');
      } catch (e) {
        if (kDebugMode) print('[NotificationsNotifier] markAllAsRead error: $e');
      }
    }
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  return NotificationsNotifier(ref);
});
