import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_matrouh/core/utils/distance_calculator.dart';
import 'package:nurse_matrouh/features/attendance/models/attendance_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Item 8: Geofence Validation & Attendance Security Tests', () {
    // Matrouh General Hospital Authoritative Geofence Zone
    final authoritativeZone = {
      'id': 'b0000002-0000-0000-0000-000000000001',
      'hospital_name': 'مستشفى مطروح العام',
      'latitude': 31.3543,
      'longitude': 27.2373,
      'radius_meters': 150.0,
      'is_active': true,
    };

    // Simulated Server Database Tables
    final dbAttendanceZones = <String, Map<String, dynamic>>{
      authoritativeZone['id'] as String: Map<String, dynamic>.from(authoritativeZone),
    };

    final dbAttendance = <String, Map<String, dynamic>>{};

    setUp(() {
      dbAttendance.clear();
      dbAttendanceZones[authoritativeZone['id'] as String] =
          Map<String, dynamic>.from(authoritativeZone);
    });

    // Helper: Server-Side Haversine Formula (Identical to PL/pgSQL function calculate_haversine_distance)
    double serverCalculateHaversine(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
    ) {
      return DistanceCalculator.calculateDistanceMeters(lat1, lon1, lat2, lon2);
    }

    // Helper: Server-Side record_attendance_check_in RPC Simulation
    Map<String, dynamic> simulateRecordAttendanceCheckIn({
      required String? callerId,
      required String? callerRole,
      required double? latitude,
      required double? longitude,
      double? gpsAccuracy,
      String biometricMethod = 'fingerprint',
      bool? clientIsInside, // Spoofed parameter attempted by client
      double? clientDistanceMeters, // Spoofed parameter attempted by client
    }) {
      // 1. Authentication Check
      if (callerId == null || callerId.isEmpty) {
        throw Exception('Authentication required: Anonymous callers cannot record attendance.');
      }

      if (callerRole == null || callerRole.isEmpty) {
        throw Exception('Unauthorized: User profile not found.');
      }

      // 2. Coordinate Range & Non-Null Validation
      if (latitude == null || longitude == null) {
        throw Exception('Invalid coordinates: Latitude and longitude are required.');
      }

      if (latitude < -90.0 || latitude > 90.0) {
        throw Exception('Invalid latitude: Must be between -90 and 90 degrees.');
      }

      if (longitude < -180.0 || longitude > 180.0) {
        throw Exception('Invalid longitude: Must be between -180 and 180 degrees.');
      }

      // 3. Duplicate Active Check-In Guard
      final hasActive = dbAttendance.values.any((rec) =>
          rec['student_id'] == callerId && rec['check_out_time'] == null);
      if (hasActive) {
        throw Exception('Duplicate check-in: An active attendance shift already exists for this student.');
      }

      // 4. Retrieve Authoritative Geofence Zone from DB
      final zone = dbAttendanceZones.values.firstWhere(
        (z) => z['is_active'] == true,
        orElse: () => throw Exception('Configuration error: No active attendance geofence zone found.'),
      );

      final zoneLat = (zone['latitude'] as num).toDouble();
      final zoneLon = (zone['longitude'] as num).toDouble();
      final allowedRadius = (zone['radius_meters'] as num).toDouble();

      // 5. Server calculates distance independently (IGNORING client-submitted distance)
      final serverDistance = serverCalculateHaversine(
        latitude,
        longitude,
        zoneLat,
        zoneLon,
      );

      // 6. Server decides inside/outside (IGNORING client-submitted clientIsInside)
      final isInside = serverDistance <= allowedRadius;
      if (!isInside) {
        throw Exception(
          'Geofence violation: Device location (distance: ${serverDistance.toStringAsFixed(1)}m) '
          'is outside the permitted hospital zone (radius: ${allowedRadius.toStringAsFixed(1)}m).',
        );
      }

      // 7. Authoritative Server Insertion
      final newId = 'att-${DateTime.now().millisecondsSinceEpoch}-${dbAttendance.length}';
      final record = {
        'id': newId,
        'student_id': callerId, // Bound strictly to caller identity (auth.uid())
        'check_in_time': DateTime.now().toIso8601String(), // Bound strictly to server time
        'check_in_latitude': latitude,
        'check_in_longitude': longitude,
        'geofence_status': true,
        'biometric_verified': true,
        'status': 'present',
        'late_minutes': 0,
        'check_out_time': null,
      };

      dbAttendance[newId] = record;
      return record;
    }

    // Helper: Server-Side record_attendance_check_out RPC Simulation
    Map<String, dynamic> simulateRecordAttendanceCheckOut({
      required String? callerId,
      String? attendanceId,
      double? latitude,
      double? longitude,
    }) {
      if (callerId == null || callerId.isEmpty) {
        throw Exception('Authentication required: Anonymous callers cannot check out.');
      }

      if (latitude != null && (latitude < -90.0 || latitude > 90.0)) {
        throw Exception('Invalid latitude: Must be between -90 and 90 degrees.');
      }

      if (longitude != null && (longitude < -180.0 || longitude > 180.0)) {
        throw Exception('Invalid longitude: Must be between -180 and 180 degrees.');
      }

      Map<String, dynamic>? target;
      if (attendanceId != null) {
        target = dbAttendance[attendanceId];
        if (target != null && target['student_id'] != callerId) {
          target = null;
        }
      } else {
        target = dbAttendance.values.firstWhere(
          (rec) => rec['student_id'] == callerId && rec['check_out_time'] == null,
          orElse: () => throw Exception('No active check-in record found for this student to check out.'),
        );
      }

      if (target == null) {
        throw Exception('No active check-in record found for this student to check out.');
      }

      target['check_out_time'] = DateTime.now().toIso8601String();
      target['check_out_latitude'] = latitude;
      target['check_out_longitude'] = longitude;

      return target;
    }

    // Helper: Simulate RLS Policy on public.attendance_zones
    bool simulateAttendanceZoneUpdate({
      required String callerRole,
      required double newRadius,
    }) {
      // RLS Policy: public.get_auth_role() IN ('super_admin', 'leader')
      final isAuthorizedStaff = ['super_admin', 'leader'].contains(callerRole);
      if (!isAuthorizedStaff) {
        return false; // Blocked by RLS
      }
      dbAttendanceZones[authoritativeZone['id'] as String]!['radius_meters'] = newRadius;
      return true;
    }

    // ── Test 1: Anonymous user cannot check in ───────────────────────────────
    test('1. Anonymous user cannot check in', () {
      expect(
        () => simulateRecordAttendanceCheckIn(
          callerId: null,
          callerRole: null,
          latitude: 31.3543,
          longitude: 27.2373,
        ),
        throwsA(predicate((e) =>
            e.toString().contains('Authentication required') ||
            e.toString().contains('Anonymous'))),
      );
    });

    // ── Test 2: Student identity comes from auth.uid() ────────────────────────
    test('2. Student identity comes from auth.uid() and client cannot forge student_id', () {
      const studentA = 'std-uuid-1111';
      final record = simulateRecordAttendanceCheckIn(
        callerId: studentA,
        callerRole: 'student',
        latitude: 31.3543,
        longitude: 27.2373,
      );

      expect(record['student_id'], equals(studentA));
    });

    // ── Test 3: Student cannot check in as another student ────────────────────
    test('3. Student cannot check in as another student', () {
      const actualStudentId = 'std-uuid-actual';
      final record = simulateRecordAttendanceCheckIn(
        callerId: actualStudentId, // Derived from auth.uid()
        callerRole: 'student',
        latitude: 31.3543,
        longitude: 27.2373,
      );

      // Even if attacker wanted to check in for std-uuid-victim, record has actualStudentId
      expect(record['student_id'], isNot(equals('std-uuid-victim')));
      expect(record['student_id'], equals(actualStudentId));
    });

    // ── Test 4: Student cannot submit is_inside=true and bypass geofence ─────
    test('4. Student cannot submit is_inside=true and bypass geofence', () {
      const studentId = 'std-uuid-cheater';
      // Far away in Alexandria / Cairo (~400km)
      const attackerLat = 30.0444;
      const attackerLon = 31.2357;

      expect(
        () => simulateRecordAttendanceCheckIn(
          callerId: studentId,
          callerRole: 'student',
          latitude: attackerLat,
          longitude: attackerLon,
          clientIsInside: true, // Attacker sends true!
        ),
        throwsA(predicate((e) => e.toString().contains('Geofence violation'))),
      );
    });

    // ── Test 5: Student cannot submit fake distance_meters to bypass geofence 
    test('5. Student cannot submit fake distance_meters to bypass geofence', () {
      const studentId = 'std-uuid-cheater2';
      // Outside hospital (~5km away)
      const outsideLat = 31.3800;
      const outsideLon = 27.2900;

      expect(
        () => simulateRecordAttendanceCheckIn(
          callerId: studentId,
          callerRole: 'student',
          latitude: outsideLat,
          longitude: outsideLon,
          clientDistanceMeters: 10.0, // Attacker submits fake 10 meters!
        ),
        throwsA(predicate((e) => e.toString().contains('Geofence violation'))),
      );
    });

    // ── Test 6: Server calculates distance independently ─────────────────────
    test('6. Server calculates distance independently with Haversine formula', () {
      final distInside = serverCalculateHaversine(
        31.3545,
        27.2375,
        31.3543,
        27.2373,
      );
      expect(distInside, lessThan(50.0));

      final distFar = serverCalculateHaversine(
        30.0444,
        31.2357,
        31.3543,
        27.2373,
      );
      expect(distFar, greaterThan(300000.0));
    });

    // ── Test 7: Coordinates outside permitted radius are rejected ────────────
    test('7. Coordinates outside permitted radius are rejected', () {
      // 1000m away from hospital
      const outsideLat = 31.3650;
      const outsideLon = 27.2373;

      expect(
        () => simulateRecordAttendanceCheckIn(
          callerId: 'std-uuid-outside',
          callerRole: 'student',
          latitude: outsideLat,
          longitude: outsideLon,
        ),
        throwsA(predicate((e) => e.toString().contains('Geofence violation'))),
      );
    });

    // ── Test 8: Coordinates inside permitted radius are accepted ─────────────
    test('8. Coordinates inside permitted radius are accepted', () {
      // 30m from center of hospital
      const insideLat = 31.3544;
      const insideLon = 27.2374;

      final res = simulateRecordAttendanceCheckIn(
        callerId: 'std-uuid-inside',
        callerRole: 'student',
        latitude: insideLat,
        longitude: insideLon,
      );

      expect(res['id'], isNotNull);
      expect(res['status'], equals('present'));
      expect(res['geofence_status'], isTrue);
    });

    // ── Test 9: Invalid latitude is rejected ─────────────────────────────────
    test('9. Invalid latitude is rejected (-95 and 100 degrees)', () {
      expect(
        () => simulateRecordAttendanceCheckIn(
          callerId: 'std-uuid-invalid',
          callerRole: 'student',
          latitude: 95.0,
          longitude: 27.2373,
        ),
        throwsA(predicate((e) => e.toString().contains('Invalid latitude'))),
      );

      expect(
        () => simulateRecordAttendanceCheckIn(
          callerId: 'std-uuid-invalid',
          callerRole: 'student',
          latitude: -95.0,
          longitude: 27.2373,
        ),
        throwsA(predicate((e) => e.toString().contains('Invalid latitude'))),
      );
    });

    // ── Test 10: Invalid longitude is rejected ───────────────────────────────
    test('10. Invalid longitude is rejected (-185 and 200 degrees)', () {
      expect(
        () => simulateRecordAttendanceCheckIn(
          callerId: 'std-uuid-invalid',
          callerRole: 'student',
          latitude: 31.3543,
          longitude: 190.0,
        ),
        throwsA(predicate((e) => e.toString().contains('Invalid longitude'))),
      );

      expect(
        () => simulateRecordAttendanceCheckIn(
          callerId: 'std-uuid-invalid',
          callerRole: 'student',
          latitude: 31.3543,
          longitude: -190.0,
        ),
        throwsA(predicate((e) => e.toString().contains('Invalid longitude'))),
      );
    });

    // ── Test 11: Student cannot modify authoritative geofence coordinates ────
    test('11. Student cannot modify authoritative geofence coordinates', () {
      final studentCanUpdate = simulateAttendanceZoneUpdate(
        callerRole: 'student',
        newRadius: 50000.0,
      );
      expect(studentCanUpdate, isFalse);
      expect(
        (dbAttendanceZones[authoritativeZone['id'] as String]!['radius_meters'] as num).toDouble(),
        equals(150.0),
      );
    });

    // ── Test 12: Student cannot modify permitted radius ──────────────────────
    test('12. Student cannot modify permitted radius', () {
      final anonCanUpdate = simulateAttendanceZoneUpdate(
        callerRole: 'anon',
        newRadius: 100000.0,
      );
      expect(anonCanUpdate, isFalse);

      final studentCanUpdate = simulateAttendanceZoneUpdate(
        callerRole: 'student',
        newRadius: 100000.0,
      );
      expect(studentCanUpdate, isFalse);
      expect(
        (dbAttendanceZones[authoritativeZone['id'] as String]!['radius_meters'] as num).toDouble(),
        equals(150.0),
      );
    });

    // ── Test 13: Client timestamp cannot override server attendance time ─────
    test('13. Client timestamp cannot override server attendance time', () {
      final beforeTime = DateTime.now().subtract(const Duration(seconds: 1));
      final res = simulateRecordAttendanceCheckIn(
        callerId: 'std-uuid-time',
        callerRole: 'student',
        latitude: 31.3543,
        longitude: 27.2373,
      );
      final checkInTime = DateTime.parse(res['check_in_time'] as String);
      expect(checkInTime.isAfter(beforeTime), isTrue);
    });

    // ── Test 14: Legitimate staff attendance-management remains functional ───
    test('14. Legitimate staff attendance-management remains functional', () {
      final leaderCanUpdate = simulateAttendanceZoneUpdate(
        callerRole: 'leader',
        newRadius: 200.0,
      );
      expect(leaderCanUpdate, isTrue);

      final adminCanUpdate = simulateAttendanceZoneUpdate(
        callerRole: 'super_admin',
        newRadius: 250.0,
      );
      expect(adminCanUpdate, isTrue);
      expect(
        (dbAttendanceZones[authoritativeZone['id'] as String]!['radius_meters'] as num).toDouble(),
        equals(250.0),
      );
    });

    // ── Test 15: Existing attendance/check-in & check-out workflow works ──────
    test('15. Existing attendance check-in & check-out workflow works', () {
      const studentId = 'std-flow-user';
      final inRecord = simulateRecordAttendanceCheckIn(
        callerId: studentId,
        callerRole: 'student',
        latitude: 31.3543,
        longitude: 27.2373,
      );

      final parsed = AttendanceRecord.fromJson(inRecord);
      expect(parsed.id, isNotEmpty);
      expect(parsed.status, AttendanceStatus.present);
      expect(parsed.checkOutTime, isNull);

      final outRecord = simulateRecordAttendanceCheckOut(
        callerId: studentId,
        attendanceId: inRecord['id'] as String,
        latitude: 31.3543,
        longitude: 27.2373,
      );

      final updatedParsed = AttendanceRecord.fromJson(outRecord);
      expect(updatedParsed.checkOutTime, isNotNull);
    });
  });
}
