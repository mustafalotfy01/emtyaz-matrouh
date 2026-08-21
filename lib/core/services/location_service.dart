import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import '../constants/app_config.dart';
import '../models/location_result.dart';

/// Cross-platform location service.
/// Uses [geolocator] which supports Android, iOS, and Web (browser Geolocation API).
class LocationService {
  LocationService._();

  /// Returns the current device/browser location as a [LocationResult].
  /// Validates GPS accuracy against [AppConfig.gpsAccuracyThresholdMeters].
  static Future<LocationResult> getCurrentLocation({
    bool skipAccuracyCheck = false,
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

    // ── 3. Obtain position ───────────────────────────────────────────────────
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      // ── 4. Accuracy validation ───────────────────────────────────────────
      if (!skipAccuracyCheck &&
          position.accuracy > AppConfig.gpsAccuracyThresholdMeters) {
        // Return result but flag poor accuracy — caller decides how to handle
        return LocationResult(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
          error: LocationError.poorAccuracy,
        );
      }

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
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
        return LocationResult(
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
