import 'dart:math';

class DistanceCalculator {
  DistanceCalculator._();

  /// Calculates the distance in meters between two GPS coordinates using the Haversine formula
  static double calculateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusMeters = 6371000.0;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _toRadians(double degree) {
    return degree * pi / 180.0;
  }

  /// Checks whether a given coordinate is inside the allowed geofence zone radius
  static bool isWithinZone({
    required double userLat,
    required double userLon,
    required double zoneLat,
    required double zoneLon,
    required double radiusMeters,
  }) {
    final distance = calculateDistanceMeters(userLat, userLon, zoneLat, zoneLon);
    return distance <= radiusMeters;
  }
}
