import 'package:flutter/foundation.dart' show kIsWeb;
import 'biometric_service.dart';
import 'biometric_service_factory.dart';

/// Central platform helper.
/// Use this instead of scattered [kIsWeb] / [Platform.isAndroid] checks in UI.
class PlatformService {
  PlatformService._();

  /// True when running in a browser (Flutter Web).
  static bool get isWeb => kIsWeb;

  /// True when running as a native mobile app (Android or iOS).
  static bool get isMobile => !kIsWeb;

  /// Screen-width threshold (px) above which we show desktop/wide layout.
  static const double desktopBreakpoint = 840.0;

  /// Returns the correct [BiometricService] for the current platform.
  static BiometricService get biometric => getPlatformBiometricService();

  /// Short platform label for audit logging.
  static String get platformLabel {
    if (kIsWeb) return 'web';
    // Non-web targets
    return 'mobile';
  }
}
