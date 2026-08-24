import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_presence_model.dart';
import 'supabase_service.dart';

class PresenceService with WidgetsBindingObserver {
  static final PresenceService instance = PresenceService._internal();

  PresenceService._internal();

  Timer? _heartbeatTimer;
  RealtimeChannel? _realtimeChannel;
  final Map<String, UserPresenceModel> _presenceCache = {};
  final _presenceStreamController = StreamController<Map<String, UserPresenceModel>>.broadcast();

  Stream<Map<String, UserPresenceModel>> get presenceStream => _presenceStreamController.stream;
  Map<String, UserPresenceModel> get cachedPresence => Map.unmodifiable(_presenceCache);

  bool _isInitialized = false;
  bool _isAppInForeground = true;

  /// Initializes the presence service and registers lifecycle observer
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    WidgetsBinding.instance.addObserver(this);

    // Listen to Supabase auth state changes
    SupabaseService.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
        startPresence();
      } else if (event == AuthChangeEvent.signedOut) {
        stopPresence();
      }
    });

    if (SupabaseService.client.auth.currentUser != null) {
      startPresence();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isAppInForeground = true;
      setOnline(true);
      _restartHeartbeat();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _isAppInForeground = false;
      _stopHeartbeat();
      setOnline(false);
    }
  }

  /// Starts heartbeat and realtime presence updates
  void startPresence() {
    _isAppInForeground = true;
    setOnline(true);
    _restartHeartbeat();
    _subscribeToRealtime();
  }

  /// Stops heartbeat, marks user offline, and clears channels
  void stopPresence() {
    _stopHeartbeat();
    _unsubscribeFromRealtime();
    setOnline(false);
    _presenceCache.clear();
    if (!_presenceStreamController.isClosed) {
      _presenceStreamController.add({});
    }
  }

  void _restartHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (_isAppInForeground && SupabaseService.client.auth.currentUser != null) {
        setOnline(true);
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Sends presence state update to Supabase via secure RPC
  Future<void> setOnline(bool isOnline) async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

    try {
      await SupabaseService.client.rpc(
        'update_user_presence',
        params: {'p_is_online': isOnline},
      );

      final now = DateTime.now();
      _presenceCache[user.id] = UserPresenceModel(
        userId: user.id,
        isOnline: isOnline,
        lastSeenAt: now,
        updatedAt: now,
      );

      if (!_presenceStreamController.isClosed) {
        _presenceStreamController.add(_presenceCache);
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ PresenceService.setOnline error: $e');
      }
    }
  }

  /// Batch loads presence for a list of user IDs to avoid N+1 queries
  Future<Map<String, UserPresenceModel>> fetchPresenceBatch(List<String> userIds) async {
    if (userIds.isEmpty) return {};

    final currentUser = SupabaseService.client.auth.currentUser;
    if (currentUser == null) return {};

    try {
      final res = await SupabaseService.client.rpc(
        'get_effective_user_presence',
        params: {'p_user_ids': userIds},
      );

      if (res is List) {
        for (final item in res) {
          final model = UserPresenceModel.fromJson(Map<String, dynamic>.from(item));
          _presenceCache[model.userId] = model;
        }

        if (!_presenceStreamController.isClosed) {
          _presenceStreamController.add(_presenceCache);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ PresenceService.fetchPresenceBatch error: $e');
      }
    }

    return _presenceCache;
  }

  /// Gets presence for a single user (from cache or fetches)
  UserPresenceModel? getCachedPresenceForUser(String userId) {
    return _presenceCache[userId];
  }

  /// Subscribes to Supabase Realtime for live presence changes
  void _subscribeToRealtime() {
    if (_realtimeChannel != null) return;

    try {
      _realtimeChannel = SupabaseService.client
          .channel('public:user_presence')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'user_presence',
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty) {
                final model = UserPresenceModel.fromJson(newRecord);
                _presenceCache[model.userId] = model;
                if (!_presenceStreamController.isClosed) {
                  _presenceStreamController.add(_presenceCache);
                }
              }
            },
          )
          .subscribe();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ PresenceService realtime subscription error: $e');
      }
    }
  }

  void _unsubscribeFromRealtime() {
    if (_realtimeChannel != null) {
      SupabaseService.client.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopHeartbeat();
    _unsubscribeFromRealtime();
    _presenceStreamController.close();
  }
}
