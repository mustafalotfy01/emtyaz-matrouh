import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/firebase_options.dart';
import 'push_notification_service.dart';
import 'supabase_service.dart';

class FirebaseMessagingService {
  FirebaseMessagingService._();

  static final FirebaseMessagingService instance = FirebaseMessagingService._();

  bool _isFirebaseCoreInitialized = false;
  bool _isMessagingInitialized = false;
  FirebaseMessaging? _messaging;

  String? _fcmToken;
  String? _lastError;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  /// Live dynamic checks against runtime Firebase status
  bool get isFirebaseCoreInitialized => Firebase.apps.isNotEmpty || _isFirebaseCoreInitialized;
  bool get isMessagingInitialized => _isMessagingInitialized && _messaging != null;
  bool get isInitialized => isFirebaseCoreInitialized && isMessagingInitialized;
  String? get currentToken => _fcmToken;
  String? get lastError => _lastError;

  /// Masked token for secure UI display
  String get maskedToken {
    if (_fcmToken == null || _fcmToken!.isEmpty) return 'غير متوفر (Not Generated)';
    if (_fcmToken!.length <= 20) return _fcmToken!;
    return '${_fcmToken!.substring(0, 10)}...${_fcmToken!.substring(_fcmToken!.length - 10)} (طول الرمز: ${_fcmToken!.length} حرف)';
  }

  /// 1. Initialize Firebase Core safely, idempotently, and handling duplicate-app gracefully
  Future<bool> ensureFirebaseCoreInitialized() async {
    if (kDebugMode) {
      print('[FcmTrace] CORE_START');
      print('[FcmTrace] CORE_APPS_BEFORE: ${Firebase.apps.map((a) => a.name).toList()}');
    }

    if (Firebase.apps.isNotEmpty) {
      _isFirebaseCoreInitialized = true;
      if (kDebugMode) {
        print('[FcmTrace] CORE_APPS_AFTER: ${Firebase.apps.map((a) => a.name).toList()}');
        print('[FcmTrace] CORE_READY: true');
      }
      return true;
    }

    try {
      if (kDebugMode) print('[FcmTrace] CORE_INIT_CALL');

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      _isFirebaseCoreInitialized = Firebase.apps.isNotEmpty;
      if (kDebugMode) {
        print('[FcmTrace] CORE_APPS_AFTER: ${Firebase.apps.map((a) => a.name).toList()}');
        print('[FcmTrace] CORE_READY: $_isFirebaseCoreInitialized');
      }
      return _isFirebaseCoreInitialized;
    } catch (e, stack) {
      // Handle case where app already exists in underlying JS runtime
      if (e.toString().contains('duplicate-app') || Firebase.apps.isNotEmpty) {
        _isFirebaseCoreInitialized = true;
        if (kDebugMode) {
          print('[FcmTrace] CORE_INIT duplicate-app resolved: true');
          print('[FcmTrace] CORE_READY: true');
        }
        return true;
      }

      _isFirebaseCoreInitialized = false;
      _lastError = 'Firebase Core Init Error: $e\n$stack';
      if (kDebugMode) {
        print('[FcmTrace] CORE_ERROR: $e');
        print(stack);
        print('[FcmTrace] CORE_READY: false');
      }
      return false;
    }
  }

  /// 2. Initialize Firebase Messaging instance with zero listener blocking
  Future<bool> ensureMessagingInitialized() async {
    if (kDebugMode) print('[FcmTrace] MESSAGING_START');

    if (_isMessagingInitialized && _messaging != null) {
      if (kDebugMode) print('[FcmTrace] MESSAGING_READY: true (already initialized)');
      return true;
    }

    final coreReady = await ensureFirebaseCoreInitialized();
    if (!coreReady) {
      if (kDebugMode) print('[FcmTrace] MESSAGING_READY: false (Core initialization failed)');
      return false;
    }

    try {
      if (kDebugMode) print('[FcmTrace] MESSAGING_INSTANCE_START');

      _messaging = FirebaseMessaging.instance;
      _isMessagingInitialized = true;

      if (kDebugMode) {
        print('[FcmTrace] MESSAGING_INSTANCE_CREATED');
        print('[FcmTrace] MESSAGING_READY: true');
      }
    } catch (e, stack) {
      _isMessagingInitialized = false;
      _lastError = 'FCM Messaging Init Error: $e\n$stack';
      if (kDebugMode) {
        print('[FcmTrace] MESSAGING_ERROR: $e');
        print(stack);
        print('[FcmTrace] MESSAGING_READY: false');
      }
      return false;
    }

    // Attach listeners separately and non-blockingly
    _attachListenersSafely();

    return true;
  }

  /// Attach message listeners safely after instance creation
  void _attachListenersSafely() {
    if (kDebugMode) print('[FcmTrace] MESSAGING_LISTENER_START');
    _setupForegroundListener();
    _setupTokenRefreshListener();
  }

  /// Unified Idempotent Initialization
  Future<bool> initialize() async {
    await ensureFirebaseCoreInitialized();
    return await ensureMessagingInitialized();
  }

  /// Setup foreground message listener
  void _setupForegroundListener() {
    _foregroundSubscription?.cancel();
    try {
      _foregroundSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) print('[FCM] Foreground message received: ${message.messageId}');

        final title = message.notification?.title ?? message.data['title'] ?? 'MANU';
        final body = message.notification?.body ?? message.data['body'] ?? 'لديك تحديث جديد';
        final route = message.data['route'] ?? '/';

        PushNotificationService.instance.showBrowserNotification(
          title: title,
          body: body,
          route: route,
          metadata: message.data,
        );
      });
    } catch (e) {
      if (kDebugMode) print('[FcmTrace] FOREGROUND_LISTENER_FAILED: $e');
    }
  }

  /// Setup token refresh listener
  void _setupTokenRefreshListener() {
    _tokenRefreshSubscription?.cancel();
    try {
      final messaging = _messaging;
      if (messaging != null) {
        _tokenRefreshSubscription = messaging.onTokenRefresh.listen((String newToken) {
          if (kDebugMode) print('[FCM] Token refreshed: ${newToken.substring(0, 10)}...');
          _fcmToken = newToken;
          _syncTokenToSupabase(newToken);
        });
        if (kDebugMode) print('[FcmTrace] TOKEN_REFRESH_LISTENER_ATTACHED');
      }
    } catch (e) {
      if (kDebugMode) print('[FcmTrace] TOKEN_REFRESH_LISTENER_FAILED: $e');
    }
  }

  /// Request browser notification permission explicitly (Only triggered on user gesture)
  Future<NotificationSettings?> requestPermission() async {
    try {
      if (kDebugMode) print('[FcmTrace] PERMISSION_START');

      await ensureFirebaseCoreInitialized();
      final ready = await ensureMessagingInitialized();
      final messaging = _messaging;
      if (!ready || messaging == null) {
        throw StateError('Firebase Messaging instance is not initialized');
      }

      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (kDebugMode) {
        print('[FcmTrace] PERMISSION_RESULT: ${settings.authorizationStatus}');
      }

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await retrieveToken();
      }

      return settings;
    } catch (e, stack) {
      _lastError = 'Permission Request Error: $e\n$stack';
      if (kDebugMode) {
        print('[FcmTrace] PERMISSION_ERROR: $e');
        print(stack);
      }
      return null;
    }
  }

  /// Generate or retrieve the FCM registration token using VAPID (On user gesture)
  Future<String?> retrieveToken({String? customVapidKey}) async {
    try {
      if (kDebugMode) print('[FcmTrace] TOKEN_START');

      await ensureFirebaseCoreInitialized();
      final messagingReady = await ensureMessagingInitialized();

      final messaging = _messaging;
      if (!messagingReady || messaging == null) {
        throw StateError('Firebase Messaging instance is not initialized');
      }

      final vapid = customVapidKey ?? DefaultFirebaseOptions.webVapidKey;
      if (kDebugMode) {
        final vapidPrefix = vapid.length > 10 ? '${vapid.substring(0, 10)}...' : vapid;
        print('[FcmTrace] TOKEN_REQUEST: VAPID prefix: $vapidPrefix');
      }

      if (kIsWeb) {
        try {
          _fcmToken = await messaging.getToken(
            vapidKey: vapid.isNotEmpty ? vapid : null,
          );
        } catch (e) {
          if (kDebugMode) print('[FcmTrace] Primary getToken fallback: $e');
          _fcmToken = await messaging.getToken();
        }
      } else {
        _fcmToken = await messaging.getToken();
      }

      if (_fcmToken != null && _fcmToken!.isNotEmpty) {
        _lastError = null;
        if (kDebugMode) {
          print('[FcmTrace] TOKEN_RESULT: SUCCESS | length: ${_fcmToken!.length} | prefix: ${_fcmToken!.substring(0, 10)}...');
        }
        await _syncTokenToSupabase(_fcmToken!);
      } else {
        _lastError = 'getToken() returned empty or null token';
        if (kDebugMode) print('[FcmTrace] TOKEN_RESULT: FAILED: Empty token returned');
      }

      return _fcmToken;
    } catch (e, stack) {
      _lastError = 'FCM getToken Error: $e\n$stack';
      if (kDebugMode) {
        print('[FcmTrace] TOKEN_RESULT: FAILED: $e');
        print(stack);
      }
      return null;
    }
  }

  /// Synchronize the active FCM push token with the authenticated user in Supabase
  Future<void> _syncTokenToSupabase(String token) async {
    if (!SupabaseService.isInitialized) return;

    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return;

      final platform = kIsWeb ? (PushNotificationService.instance.isIosSafariNonStandalone() ? 'ios_pwa' : 'web') : defaultTargetPlatform.name;

      // 1. Update Auth User Metadata
      try {
        await SupabaseService.client.auth.updateUser(
          UserAttributes(data: {'fcm_token': token, 'platform': platform}),
        );
      } catch (_) {}

      // 2. Upsert into push_subscriptions table if exists
      try {
        await SupabaseService.client.from('push_subscriptions').upsert({
          'user_id': user.id,
          'endpoint': 'fcm:$token',
          'platform': platform,
          'device_name': kIsWeb ? 'Web Browser (FCM)' : defaultTargetPlatform.name,
          'is_active': true,
          'last_seen_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,endpoint');
      } catch (_) {}
    } catch (e) {
      if (kDebugMode) print('[FCM] Token sync to Supabase warning: $e');
    }
  }

  /// Cleanly deactivate FCM token on logout
  Future<void> handleLogout() async {
    try {
      if (_fcmToken != null && SupabaseService.isInitialized) {
        final user = SupabaseService.client.auth.currentUser;
        if (user != null) {
          await SupabaseService.client
              .from('push_subscriptions')
              .update({'is_active': false})
              .eq('user_id', user.id)
              .eq('endpoint', 'fcm:$_fcmToken');
        }
      }
      _fcmToken = null;
    } catch (_) {}
  }
}
