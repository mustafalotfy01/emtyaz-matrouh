import 'dart:js_interop';
import 'package:web/web.dart' as web;

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

/// Safely shows a browser notification if permitted
bool showBrowserNotificationImpl(String title, String body, String route) {
  try {
    if (web.Notification.permission != 'granted') return false;

    final options = web.NotificationOptions(
      body: body,
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
    );

    web.Notification(title, options);
    return true;
  } catch (_) {
    return false;
  }
}
