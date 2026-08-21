import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance_record.dart';
import '../models/geofence_zone.dart';
import '../../../core/models/location_result.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/platform_service.dart';
import '../../../core/utils/distance_calculator.dart';

// ── Geofence result ──────────────────────────────────────────────────────────

class GeofenceResult {
  final bool isInside;
  final double distanceMeters;
  final double allowedRadiusMeters;

  const GeofenceResult({
    required this.isInside,
    required this.distanceMeters,
    required this.allowedRadiusMeters,
  });

  double get remainingToEnterMeters =>
      isInside ? 0 : (distanceMeters - allowedRadiusMeters);
}

// ── Check-in flow steps ──────────────────────────────────────────────────────

enum CheckInStep {
  idle,
  gettingLocation,
  poorAccuracyWarning,
  checkingGeofence,
  outsideZone,
  awaitingBiometric,
  biometricInProgress,
  success,
  error,
}

// ── State ────────────────────────────────────────────────────────────────────

class AttendanceState {
  final List<AttendanceRecord> history;
  final AttendanceRecord? activeRecord;
  final CheckInStep step;
  final String? errorMessage;
  final LocationResult? lastLocation;
  final GeofenceResult? geofenceResult;
  final GeofenceZone activeZone;

  AttendanceState({
    required this.history,
    this.activeRecord,
    this.step = CheckInStep.idle,
    this.errorMessage,
    this.lastLocation,
    this.geofenceResult,
    GeofenceZone? activeZone,
  }) : activeZone = activeZone ?? GeofenceZone.matrouhGeneralHospitalEmergency();

  bool get isProcessing =>
      step == CheckInStep.gettingLocation ||
      step == CheckInStep.checkingGeofence ||
      step == CheckInStep.biometricInProgress;

  AttendanceState copyWith({
    List<AttendanceRecord>? history,
    AttendanceRecord? activeRecord,
    CheckInStep? step,
    String? errorMessage,
    LocationResult? lastLocation,
    GeofenceResult? geofenceResult,
    GeofenceZone? activeZone,
    bool clearActive = false,
    bool clearError = false,
    bool clearLocation = false,
  }) {
    return AttendanceState(
      history: history ?? this.history,
      activeRecord: clearActive ? null : (activeRecord ?? this.activeRecord),
      step: step ?? this.step,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastLocation:
          clearLocation ? null : (lastLocation ?? this.lastLocation),
      geofenceResult: geofenceResult ?? this.geofenceResult,
      activeZone: activeZone ?? this.activeZone,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class AttendanceNotifier extends StateNotifier<AttendanceState> {
  AttendanceNotifier()
      : super(AttendanceState(
          history: [],
        ));

  // ── Zone management ────────────────────────────────────────────────────────

  void updateActiveZone({
    required double latitude,
    required double longitude,
    required double radius,
    required String hospitalName,
    String? departmentName,
  }) {
    final updatedZone = state.activeZone.copyWith(
      hospitalName: hospitalName,
      departmentName: departmentName,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radius,
    );
    state = state.copyWith(activeZone: updatedZone);
  }

  // ── Reset flow ─────────────────────────────────────────────────────────────

  void resetFlow() {
    state = state.copyWith(
      step: CheckInStep.idle,
      clearError: true,
      clearLocation: true,
    );
  }

  // ── Check-in flow ──────────────────────────────────────────────────────────

  Future<void> startCheckIn({
    required String studentId,
    required String studentName,
    required String departmentName,
  }) async {
    // ── Guard: duplicate check-in ─────────────────────────────────────────
    if (state.activeRecord != null) {
      state = state.copyWith(
        step: CheckInStep.error,
        errorMessage: 'تم تسجيل حضورك بالفعل لهذا الشيفت. لا يمكن تسجيل الحضور مرتين.',
      );
      return;
    }

    state = state.copyWith(
      step: CheckInStep.gettingLocation,
      clearError: true,
      clearLocation: true,
    );

    // ── Step 1: GPS ────────────────────────────────────────────────────────
    final locResult = await LocationService.getCurrentLocation();

    if (!locResult.isSuccess && locResult.error != LocationError.poorAccuracy) {
      state = state.copyWith(
        step: CheckInStep.error,
        errorMessage: locResult.errorMessageAr,
      );
      return;
    }

    if (locResult.error == LocationError.poorAccuracy) {
      state = state.copyWith(
        step: CheckInStep.poorAccuracyWarning,
        lastLocation: locResult,
        errorMessage: locResult.errorMessageAr,
      );
      return;
    }

    state = state.copyWith(lastLocation: locResult);
    await _evaluateGeofenceAndProceed(locResult, studentId, studentName, departmentName);
  }

  /// Override poor accuracy and proceed with the location we already have.
  Future<void> overridePoorAccuracy({
    required String studentId,
    required String studentName,
    required String departmentName,
  }) async {
    final loc = state.lastLocation;
    if (loc == null) return;
    // Use the existing location with skipAccuracyCheck=true
    final accepted = LocationResult(
      latitude: loc.latitude,
      longitude: loc.longitude,
      accuracyMeters: loc.accuracyMeters,
    );
    state = state.copyWith(lastLocation: accepted);
    await _evaluateGeofenceAndProceed(accepted, studentId, studentName, departmentName);
  }

  Future<void> retryLocationAccuracy({
    required String studentId,
    required String studentName,
    required String departmentName,
  }) async {
    state = state.copyWith(step: CheckInStep.gettingLocation, clearError: true);
    final locResult = await LocationService.getCurrentLocation(
      skipAccuracyCheck: false,
    );

    if (!locResult.isSuccess && locResult.error != LocationError.poorAccuracy) {
      state = state.copyWith(
        step: CheckInStep.error,
        errorMessage: locResult.errorMessageAr,
      );
      return;
    }

    state = state.copyWith(lastLocation: locResult);
    await _evaluateGeofenceAndProceed(locResult, studentId, studentName, departmentName);
  }

  Future<void> _evaluateGeofenceAndProceed(
    LocationResult locResult,
    String studentId,
    String studentName,
    String departmentName,
  ) async {
    // Guard: must have valid coordinates
    if (locResult.latitude == null || locResult.longitude == null) {
      state = state.copyWith(
        step: CheckInStep.error,
        errorMessage: 'إحداثيات الموقع غير متوفرة.',
      );
      return;
    }

    state = state.copyWith(step: CheckInStep.checkingGeofence);

    final zone = state.activeZone;
    final distanceMeters = DistanceCalculator.calculateDistanceMeters(
      locResult.latitude!,
      locResult.longitude!,
      zone.latitude,
      zone.longitude,
    );

    final isInside = distanceMeters <= zone.radiusMeters;
    final geofenceResult = GeofenceResult(
      isInside: isInside,
      distanceMeters: distanceMeters,
      allowedRadiusMeters: zone.radiusMeters,
    );

    state = state.copyWith(geofenceResult: geofenceResult);

    if (!isInside) {
      state = state.copyWith(
        step: CheckInStep.outsideZone,
        errorMessage:
            'أنت خارج نطاق المستشفى المسموح (${distanceMeters.toStringAsFixed(0)} متر، المسموح: ${zone.radiusMeters.toStringAsFixed(0)} متر).',
      );
      return;
    }

    state = state.copyWith(step: CheckInStep.awaitingBiometric);
  }

  /// Convenience alias called from the UI screen — delegates to [submitBiometricAndFinalize].
  Future<void> confirmWithBiometric({
    required String studentId,
    required String studentName,
    required String departmentName,
  }) =>
      submitBiometricAndFinalize(
        studentId: studentId,
        studentName: studentName,
        departmentName: departmentName,
        isBiometricEnabled: true,
      );

  Future<void> submitBiometricAndFinalize({
    required String studentId,
    required String studentName,
    required String departmentName,
    required bool isBiometricEnabled,
  }) async {
    state = state.copyWith(step: CheckInStep.biometricInProgress);

    final bioService = PlatformService.biometric;
    String verifiedMethod = 'web_session';

    if (isBiometricEnabled) {
      final bioResult = await bioService.authenticate(
        reason: 'تأكيد الحضور عبر البصمة الحيوية',
      );

      if (!bioResult.success) {
        state = state.copyWith(
          step: CheckInStep.error,
          errorMessage: bioResult.errorMessage ?? 'فشل التحقق الحيوي. يرجى المحاولة ثانية.',
        );
        return;
      }
      verifiedMethod = bioResult.method;
    }

    final loc = state.lastLocation!;
    final geo = state.geofenceResult!;

    final newRecord = AttendanceRecord(
      id: 'att-${DateTime.now().millisecondsSinceEpoch}',
      studentId: studentId,
      studentName: studentName,
      departmentName: departmentName,
      checkInTime: DateTime.now(),
      checkInLat: loc.latitude!,
      checkInLon: loc.longitude!,
      checkInGpsAccuracy: loc.accuracyMeters,
      geofenceDistanceMeters: geo.distanceMeters,
      isGeofenceVerified: true,
      isBiometricVerified: isBiometricEnabled,
      biometricMethod: verifiedMethod,
      status: AttendanceStatus.present,
    );

    state = state.copyWith(
      activeRecord: newRecord,
      history: [newRecord, ...state.history],
      step: CheckInStep.success,
      clearError: true,
    );
  }

  Future<void> checkOut() async {
    if (state.activeRecord == null) return;

    final locResult = await LocationService.getCurrentLocation();
    final location = locResult.isSuccess
        ? locResult
        : const LocationResult(error: LocationError.unknown);

    final updatedRecord = state.activeRecord!.copyWith(
      checkOutTime: DateTime.now(),
      checkOutLat: location.isSuccess ? location.latitude : null,
      checkOutLon: location.isSuccess ? location.longitude : null,
    );

    state = state.copyWith(
      history: [
        for (final item in state.history)
          if (item.id == updatedRecord.id) updatedRecord else item,
      ],
      clearActive: true,
      step: CheckInStep.idle,
      clearError: true,
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final attendanceProvider =
    StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
  return AttendanceNotifier();
});
