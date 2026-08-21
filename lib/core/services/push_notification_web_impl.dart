import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

@JS('MatrouhPush.showBrowserNotification')
external JSBoolean? _jsShowBrowserNotification(JSString title, JSString body, JSString route);

/// Safely checks if the user is on iPhone in regular Safari (non-standalone PWA)
bool isIosSafariNonStandaloneImpl() {
  try {
    final ua = web.window.navigator.userAgent;
    final isIos = ua.contains('iPhone') || ua.contains('iPad') || ua.contains('iPod');
    if (!isIos) return false;

    // Check standalone mode
    final matchMedia = web.window.matchMedia('(display-mode: standalone)');
    final isStandalone = matchMedia.matches;
    return !isStandalone;
  } catch (_) {
    return false;
  }
}

/// Safely checks the browser notification permission
String getPermissionStatusImpl() {
  try {
    return web.Notification.permission;
  } catch (_) {
    return 'unsupported';
  }
}

/// Safely requests browser notification permission
Future<String> requestPermissionImpl() async {
  try {
    final promise = web.Notification.requestPermission();
    final result = await promise.toDart;
    return result.toDart;
  } catch (_) {
    return 'denied';
  }
}

/// Safely shows a browser notification if permitted using ServiceWorker with fallbacks
Future<bool> showBrowserNotificationImpl(String title, String body, String route) async {
  if (kDebugMode) {
    print('[TEST_PUSH] Notification.permission: ${web.Notification.permission}');
    print('[TEST_PUSH] SHOW_NOTIFICATION_START');
  }

  if (web.Notification.permission != 'granted') {
    if (kDebugMode) print('[TEST_PUSH] FAILED: Permission is ${web.Notification.permission}');
    return false;
  }

  // 1. Try ServiceWorkerRegistration.showNotification first (standard for modern browsers, HTTPS & PWA)
  try {
    if (web.window.navigator.serviceWorker.controller != null) {
      final regPromise = web.window.navigator.serviceWorker.ready;
      final reg = await regPromise.toDart;
      final options = web.NotificationOptions(
        body: body,
        icon: '/icons/Icon-192.png',
        badge: '/icons/Icon-192.png',
      );
      final showPromise = reg.showNotification(title, options);
      await showPromise.toDart;
      if (kDebugMode) print('[TEST_PUSH] SHOW_NOTIFICATION_SUCCESS (via ServiceWorker)');
      return true;
    }
  } catch (e, st) {
    if (kDebugMode) {
      print('[TEST_PUSH_ERROR] ServiceWorker showNotification failed: $e');
      print(st);
    }
  }

  // 2. Try window.MatrouhPush JS helper
  try {
    final jsRes = _jsShowBrowserNotification(title.toJS, body.toJS, route.toJS);
    if (jsRes?.toDart == true) {
      if (kDebugMode) print('[TEST_PUSH] SHOW_NOTIFICATION_SUCCESS (via MatrouhPush JS)');
      return true;
    }
  } catch (e) {
    if (kDebugMode) print('[TEST_PUSH_ERROR] MatrouhPush JS call failed: $e');
  }

  // 3. Fallback to direct web.Notification constructor
  try {
    final options = web.NotificationOptions(
      body: body,
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
    );
    web.Notification(title, options);
    if (kDebugMode) print('[TEST_PUSH] SHOW_NOTIFICATION_SUCCESS (via Notification constructor)');
    return true;
  } catch (e, st) {
    if (kDebugMode) {
      print('[TEST_PUSH_ERROR] Notification constructor failed: $e');
      print(st);
    }
    return false;
  }
}
