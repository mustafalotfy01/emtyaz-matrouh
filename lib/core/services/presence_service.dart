import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_presence_model.dart';
import '../utils/timezone_helper.dart';
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

  /// Initializes the presence service, registers lifecycle observer, and syncs auth state
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    AppTimezoneHelper.initialize();
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

  /// Starts heartbeat (every 45s) and realtime presence updates
  void startPresence() {
    _isAppInForeground = true;
    syncServerTime();
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

  /// Periodically sends 45-second heartbeat while application is active
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

  /// Synchronizes device clock offset with PostgreSQL server time
  Future<void> syncServerTime() async {
    try {
      final res = await SupabaseService.client.rpc('get_server_time');
      if (res != null) {
        final serverTime = DateTime.tryParse(res.toString());
        if (serverTime != null) {
          AppTimezoneHelper.setServerTime(serverTime);
        }
      }
    } catch (_) {
      // Ignored if offline or fallback
    }
  }

  /// Sends presence state update to Supabase via secure RPC ONLY (never sends client timestamps)
  Future<void> setOnline(bool isOnline) async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

    try {
      await SupabaseService.client.rpc(
        'update_user_presence',
        params: {'p_is_online': isOnline},
      );
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ PresenceService.setOnline RPC error: $e');
      }
    }

    final serverTime = AppTimezoneHelper.serverNowUtc;
    _presenceCache[user.id] = UserPresenceModel(
      userId: user.id,
      isOnline: isOnline,
      lastSeenAt: serverTime,
      updatedAt: serverTime,
      effectiveIsOnline: isOnline,
      serverNow: serverTime,
    );

    if (!_presenceStreamController.isClosed) {
      _presenceStreamController.add(_presenceCache);
    }
  }

  /// Batch loads presence for a list of user IDs in ONE query to avoid N+1 queries
  Future<Map<String, UserPresenceModel>> fetchPresenceBatch(List<String> userIds) async {
    if (userIds.isEmpty) return {};

    final currentUser = SupabaseService.client.auth.currentUser;
    if (currentUser == null) return {};

    try {
      final res = await SupabaseService.client.rpc(
        'get_effective_user_presence',
        params: {'p_user_ids': userIds},
      );

      if (res is List && res.isNotEmpty) {
        for (final item in res) {
          final model = UserPresenceModel.fromJson(Map<String, dynamic>.from(item));
          _presenceCache[model.userId] = model;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ PresenceService.fetchPresenceBatch error: $e');
      }
    }

    if (!_presenceStreamController.isClosed) {
      _presenceStreamController.add(_presenceCache);
    }

    return _presenceCache;
  }

  /// Gets presence for a single user (from cache or returns null)
  UserPresenceModel? getCachedPresenceForUser(String userId) {
    return _presenceCache[userId];
  }

  /// Subscribes to Supabase Realtime for live presence changes (single subscription)
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
