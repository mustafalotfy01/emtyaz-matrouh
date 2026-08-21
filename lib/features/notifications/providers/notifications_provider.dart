import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  /// Count of unread notifications strictly belonging to the current user
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
  RealtimeChannel? _realtimeChannel;
  String? _subscribedUserId;

  NotificationsNotifier(this._ref) : super(const NotificationsState()) {
    _initForCurrentUser();
    _ref.listen(authProvider, (previous, next) {
      if (previous?.user?.id != next.user?.id) {
        _initForCurrentUser();
      }
    });
  }

  void _initForCurrentUser() {
    final user = _ref.read(authProvider).user;
    if (user == null) {
      _unsubscribeRealtime();
      state = const NotificationsState();
      return;
    }

    fetchNotifications();
    _setupRealtimeSubscription(user.id);
  }

  /// Fetch notifications strictly for the current authenticated user
  Future<void> fetchNotifications() async {
    final user = _ref.read(authProvider).user;
    if (user == null || !SupabaseService.isInitialized) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final res = await SupabaseService.client
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(100);

      if (res is List) {
        final notifications = res.map((r) => NotificationItem.fromJson(r)).toList();
        state = state.copyWith(items: notifications, isLoading: false);
      } else {
        state = state.copyWith(items: const [], isLoading: false);
      }
    } catch (e) {
      if (kDebugMode) print('[NotificationsNotifier] fetch error: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Setup Realtime Postgres Subscription for the current user's notifications
  void _setupRealtimeSubscription(String userId) {
    if (!SupabaseService.isInitialized) return;
    if (_subscribedUserId == userId && _realtimeChannel != null) return;

    _unsubscribeRealtime();
    _subscribedUserId = userId;

    try {
      _realtimeChannel = SupabaseService.client
          .channel('public:notifications:user-$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              if (kDebugMode) {
                print('[Notifications Realtime] New notification arrived: ${payload.newRecord['id']}');
              }
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty) {
                final newItem = NotificationItem.fromJson(newRecord);
                _addNewNotification(newItem);
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty) {
                final updatedItem = NotificationItem.fromJson(newRecord);
                _updateNotification(updatedItem);
              }
            },
          )
          .subscribe();
    } catch (e) {
      if (kDebugMode) print('[Notifications Realtime] Subscription warning: $e');
    }
  }

  void _addNewNotification(NotificationItem item) {
    // Duplicate protection
    if (state.items.any((n) => n.id == item.id)) return;
    state = state.copyWith(items: [item, ...state.items]);
  }

  void _updateNotification(NotificationItem item) {
    final updated = state.items.map((n) {
      return n.id == item.id ? item : n;
    }).toList();
    state = state.copyWith(items: updated);
  }

  void _unsubscribeRealtime() {
    if (_realtimeChannel != null) {
      try {
        SupabaseService.client.removeChannel(_realtimeChannel!);
      } catch (_) {}
      _realtimeChannel = null;
    }
    _subscribedUserId = null;
  }

  Future<void> markAsRead(String notificationId) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

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
        await SupabaseService.client
            .from('notifications')
            .update({'is_read': true})
            .eq('id', notificationId)
            .eq('user_id', user.id);
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
        await SupabaseService.client
            .from('notifications')
            .update({'is_read': true})
            .eq('user_id', user.id);
      } catch (e) {
        if (kDebugMode) print('[NotificationsNotifier] markAllAsRead error: $e');
      }
    }
  }

  @override
  void dispose() {
    _unsubscribeRealtime();
    super.dispose();
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  return NotificationsNotifier(ref);
});
