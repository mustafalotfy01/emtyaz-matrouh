class AppConfig {
  AppConfig._();

  // ── Supabase ────────────────────────────────────────────────────────────────
  static const String supabaseUrl = 'https://zlxumwvygqcxhareknul.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpseHVtd3Z5Z3FjeGhhcmVrbnVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY3NzIyMjEsImV4cCI6MjEwMjM0ODIyMX0.7FRbGAuFHh8sqfwBXQM5n3WVfyNbnuIAk3ucND3Kh-s';
  static const String supabaseServiceRoleKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpseHVtd3Z5Z3FjeGhhcmVrbnVsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Njc3MjIyMSwiZXhwIjoyMTAyMzQ4MjIxfQ.kzcY871QMGYOKFougygGtHZnopmzkAxZWJlFtGxNC7E';

  // ── GPS / Geofence ──────────────────────────────────────────────────────────
  /// Maximum acceptable GPS accuracy in meters.
  /// Positions with accuracy > this value trigger a "poor accuracy" warning.
  /// Configurable — increase if students are in dense hospital buildings.
  static const double gpsAccuracyThresholdMeters = 30.0;

  // ── Google Maps Platform ────────────────────────────────────────────────────
  // API keys are NOT stored here. They are injected per-platform:
  //
  //   Android → android/local.properties → MAPS_API_KEY
  //             (read by build.gradle.kts → manifestPlaceholders → AndroidManifest)
  //
  //   iOS     → ios/Flutter/Debug.xcconfig & Release.xcconfig → IOS_MAPS_API_KEY
  //             (read by Info.plist build variable → passed to GMSServices in AppDelegate)
  //
  //   Web     → web/index.html → Google Maps JS API <script src="...?key=...">
  //             (restricted by HTTP referrer in Google Cloud Console)
  //
  // NEVER put a real API key in this file or anywhere under lib/.
}
