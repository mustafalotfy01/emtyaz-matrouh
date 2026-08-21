import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../config/firebase_options.dart';
import 'push_notification_service.dart';
import 'supabase_service.dart';

class FirebaseMessagingService {
  FirebaseMessagingService._();

  static final FirebaseMessagingService instance = FirebaseMessagingService._();

  bool _isInitialized = false;
  String? _fcmToken;
  String? _lastError;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  bool get isInitialized => _isInitialized;
  String? get currentToken => _fcmToken;
  String? get lastError => _lastError;

  /// Masked token for secure UI display
  String get maskedToken {
    if (_fcmToken == null || _fcmToken!.isEmpty) return 'غير متوفر (Not Generated)';
    if (_fcmToken!.length <= 20) return _fcmToken!;
    return '${_fcmToken!.substring(0, 10)}...${_fcmToken!.substring(_fcmToken!.length - 10)} (طول الرمز: ${_fcmToken!.length} حرف)';
  }

  /// Initialize Firebase Core and Firebase Messaging for Web/Mobile
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      _isInitialized = true;
      _lastError = null;
      if (kDebugMode) print('[FCM] Firebase Core initialized for Emtaz-Matrouh');

      // Listen for foreground push messages
      _setupForegroundListener();

      // Listen for token refresh
      _setupTokenRefreshListener();

      return true;
    } catch (e, stack) {
      _lastError = 'Initialization Error: $e\n$stack';
      if (kDebugMode) print('[FCM INIT ERROR] $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Setup foreground message listener
  void _setupForegroundListener() {
    _foregroundSubscription?.cancel();
    try {
      _foregroundSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) print('[FCM] Foreground message received: ${message.messageId}');

        final title = message.notification?.title ?? message.data['title'] ?? 'امتياز مطروح';
        final body = message.notification?.body ?? message.data['body'] ?? 'لديك تحديث جديد';
        final route = message.data['route'] ?? '/';

        // Trigger local browser push banner
        PushNotificationService.instance.showBrowserNotification(
          title: title,
          body: body,
          route: route,
          metadata: message.data,
        );
      });
    } catch (e) {
      if (kDebugMode) print('[FCM] Foreground listener error: $e');
    }
  }

  /// Setup token refresh listener
  void _setupTokenRefreshListener() {
    _tokenRefreshSubscription?.cancel();
    try {
      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) {
        if (kDebugMode) print('[FCM] Token refreshed: ${newToken.substring(0, 10)}...');
        _fcmToken = newToken;
        _syncTokenToSupabase(newToken);
      });
    } catch (e) {
      if (kDebugMode) print('[FCM] Token refresh listener error: $e');
    }
  }

  /// Request browser notification permission explicitly
  Future<NotificationSettings?> requestPermission() async {
    try {
      await initialize();
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (kDebugMode) {
        print('[FCM] Permission status: ${settings.authorizationStatus}');
      }

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await retrieveToken();
      }

      return settings;
    } catch (e, stack) {
      _lastError = 'Permission Request Error: $e\n$stack';
      if (kDebugMode) print('[FCM PERMISSION ERROR] $e');
      return null;
    }
  }

  /// Generate or retrieve the FCM registration token using VAPID
  Future<String?> retrieveToken({String? customVapidKey}) async {
    try {
      await initialize();

      final vapid = customVapidKey ?? DefaultFirebaseOptions.webVapidKey;
      if (kDebugMode) {
        print('[FCM] Retrieving FCM registration token with VAPID: $vapid');
      }

      if (kIsWeb) {
        try {
          _fcmToken = await FirebaseMessaging.instance.getToken(
            vapidKey: vapid.isNotEmpty ? vapid : null,
          );
        } catch (e) {
          if (kDebugMode) print('[FCM] Primary getToken warning: $e, trying fallback...');
          _fcmToken = await FirebaseMessaging.instance.getToken();
        }
      } else {
        _fcmToken = await FirebaseMessaging.instance.getToken();
      }

      if (_fcmToken != null && _fcmToken!.isNotEmpty) {
        _lastError = null;
        if (kDebugMode) print('[FCM SUCCESS] Real FCM Token retrieved: $maskedToken');
        await _syncTokenToSupabase(_fcmToken!);
      } else {
        _lastError = 'getToken() returned empty or null token';
      }

      return _fcmToken;
    } catch (e, stack) {
      _lastError = 'FCM getToken Error: $e\n$stack';
      if (kDebugMode) print('[FCM TOKEN ERROR] $e\n$stack');
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

      // Upsert into push_subscriptions table
      try {
        await SupabaseService.adminClient.from('push_subscriptions').upsert({
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
          await SupabaseService.adminClient
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
