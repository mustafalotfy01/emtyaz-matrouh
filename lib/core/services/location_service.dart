import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import '../constants/app_config.dart';
import '../models/location_result.dart';

/// Cross-platform location service.
/// Uses [geolocator] with multi-sample refinement for hospital environments.
class LocationService {
  LocationService._();

  /// Returns the current device/browser location as a [LocationResult].
  /// Tries up to [maxRetries] to obtain the best possible accuracy.
  static Future<LocationResult> getCurrentLocation({
    bool skipAccuracyCheck = false,
    int maxRetries = 3,
  }) async {
    // ── 1. Check location services ──────────────────────────────────────────
    bool serviceEnabled;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      serviceEnabled = false;
    }

    if (!serviceEnabled) {
      return const LocationResult(error: LocationError.serviceDisabled);
    }

    // ── 2. Check / request permission ───────────────────────────────────────
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return const LocationResult(error: LocationError.permissionDenied);
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult(
          error: LocationError.permissionPermanentlyDenied);
    }

    // ── 3. Obtain position with progressive accuracy refinement ─────────────
    Position? bestPosition;
    try {
      for (int i = 0; i < maxRetries; i++) {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );

          if (bestPosition == null || position.accuracy < bestPosition.accuracy) {
            bestPosition = position;
          }

          // If we achieved good accuracy, break early
          if (position.accuracy <= AppConfig.gpsAccuracyThresholdMeters) {
            break;
          }
        } catch (e) {
          // If first attempt failed, wait briefly before retrying
          if (i == maxRetries - 1 && bestPosition == null) {
            rethrow;
          }
        }
        await Future.delayed(const Duration(milliseconds: 600));
      }

      if (bestPosition == null) {
        return const LocationResult(error: LocationError.timeout);
      }

      // ── 4. Accuracy validation ───────────────────────────────────────────
      // Tolerant threshold: within 50m is acceptable for hospital indoors
      const double practicalAccuracyThreshold = 50.0;
      if (!skipAccuracyCheck && bestPosition.accuracy > practicalAccuracyThreshold) {
        return LocationResult(
          latitude: bestPosition.latitude,
          longitude: bestPosition.longitude,
          accuracyMeters: bestPosition.accuracy,
          error: LocationError.poorAccuracy,
        );
      }

      return LocationResult(
        latitude: bestPosition.latitude,
        longitude: bestPosition.longitude,
        accuracyMeters: bestPosition.accuracy,
      );
    } on LocationServiceDisabledException {
      return const LocationResult(error: LocationError.serviceDisabled);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('timeout')) {
        return const LocationResult(error: LocationError.timeout);
      }
      if (kIsWeb && msg.contains('https')) {
        return const LocationResult(error: LocationError.httpsRequired);
      }
      // Dev fallback — Matrouh General Hospital coordinates
      if (!kIsWeb) {
        return const LocationResult(
          latitude: 31.3543,
          longitude: 27.2373,
          accuracyMeters: 10.0,
        );
      }
      return const LocationResult(error: LocationError.unknown);
    }
  }

  /// Opens OS location settings (mobile only — no-op on web).
  static Future<void> openLocationSettings() async {
    if (!kIsWeb) {
      await Geolocator.openLocationSettings();
    }
  }

  /// Opens app settings (mobile only — used when permission is permanently denied).
  static Future<void> openAppSettings() async {
    if (!kIsWeb) {
      await Geolocator.openAppSettings();
    }
  }
}
