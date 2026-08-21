/// Unified result from any location request.
/// Used by LocationService across all platforms (Android, iOS, Web).
class LocationResult {
  final double? latitude;
  final double? longitude;

  /// GPS/browser accuracy in meters. Lower = better.
  final double? accuracyMeters;

  /// Non-null when the request failed.
  final LocationError? error;

  const LocationResult({
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.error,
  });

  bool get isSuccess => error == null && latitude != null && longitude != null;

  /// Returns the user-facing Arabic error message for this result.
  String get errorMessageAr {
    switch (error) {
      case LocationError.serviceDisabled:
        return 'خدمة الموقع GPS غير مفعّلة. يرجى تفعيلها من إعدادات الجهاز.';
      case LocationError.permissionDenied:
        return 'تم رفض صلاحية الوصول إلى الموقع. يرجى السماح بذلك من الإعدادات.';
      case LocationError.permissionPermanentlyDenied:
        return 'تم رفض صلاحية الموقع نهائياً. يرجى تفعيلها يدوياً من إعدادات التطبيق.';
      case LocationError.poorAccuracy:
        return 'دقة الموقع الحالية غير كافية لتسجيل الحضور. حاول الوقوف في مكان مفتوح وأعد المحاولة.';
      case LocationError.timeout:
        return 'انتهت مهلة تحديد الموقع. يرجى التحقق من إشارة GPS والمحاولة مجدداً.';
      case LocationError.httpsRequired:
        return 'تحديد الموقع يتطلب اتصالاً آمناً (HTTPS). يرجى استخدام النسخة الرسمية من التطبيق.';
      case LocationError.unknown:
      case null:
        return 'تعذر تحديد الموقع. يرجى المحاولة مجدداً.';
    }
  }

  @override
  String toString() =>
      isSuccess
          ? 'LocationResult(lat=$latitude, lng=$longitude, acc=${accuracyMeters?.toStringAsFixed(1)}m)'
          : 'LocationResult(error=$error)';
}

enum LocationError {
  /// GPS / location services turned off on device.
  serviceDisabled,

  /// User denied location permission.
  permissionDenied,

  /// User permanently denied (Android) — must go to app settings.
  permissionPermanentlyDenied,

  /// Position obtained but accuracy exceeds acceptable threshold.
  poorAccuracy,

  /// Timed out waiting for a position fix.
  timeout,

  /// Web: browser geolocation only works on HTTPS.
  httpsRequired,

  /// Unexpected error.
  unknown,
}
