import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class VibrationService {
  VibrationService._();

  /// Strong repeated multi-pulse vibration for urgent alerts (e.g. fingerprint requests)
  static Future<void> triggerUrgentVibration({int pulses = 4}) async {
    if (kIsWeb) return;
    try {
      for (int i = 0; i < pulses; i++) {
        await HapticFeedback.vibrate();
        await HapticFeedback.heavyImpact();
        if (i < pulses - 1) {
          await Future.delayed(const Duration(milliseconds: 320));
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[VibrationService] Error triggering urgent vibration: $e');
      }
    }
  }

  /// Single short vibration for standard events
  static Future<void> triggerNotificationVibrate() async {
    if (kIsWeb) return;
    try {
      await HapticFeedback.vibrate();
    } catch (_) {}
  }
}
