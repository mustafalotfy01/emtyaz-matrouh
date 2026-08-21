import 'package:flutter/foundation.dart';
import 'push_notification_web_stub.dart'
    if (dart.library.js_interop) 'push_notification_web_impl.dart';

enum PushPermissionStatus {
  granted,
  denied,
  prompt,
  unsupported,
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  /// Check if the current environment is an iPhone in Safari browser (not installed on Home Screen)
  bool isIosSafariNonStandalone() {
    if (!kIsWeb) return false;
    return isIosSafariNonStandaloneImpl();
  }

  /// Get the current permission status
  PushPermissionStatus getPermissionStatus() {
    if (!kIsWeb) return PushPermissionStatus.granted;
    final status = getPermissionStatusImpl();
    if (status == 'granted') return PushPermissionStatus.granted;
    if (status == 'denied') return PushPermissionStatus.denied;
    if (status == 'default' || status == 'prompt') return PushPermissionStatus.prompt;
    return PushPermissionStatus.unsupported;
  }

  /// Request browser notification permission upon direct user interaction
  Future<bool> requestPermission() async {
    if (!kIsWeb) return true;
    try {
      final perm = await requestPermissionImpl();
      return perm == 'granted';
    } catch (e) {
      if (kDebugMode) print('[PushNotificationService] requestPermission error: $e');
      return false;
    }
  }

  /// Show native browser/device push notification
  bool showBrowserNotification({
    required String title,
    required String body,
    String route = '/',
    Map<String, dynamic>? metadata,
  }) {
    if (!kIsWeb) return false;
    return showBrowserNotificationImpl(title, body, route);
  }
}
