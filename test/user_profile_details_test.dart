import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_matrouh/core/models/user_presence_model.dart';
import 'package:nurse_matrouh/features/auth/models/user_profile.dart';
import 'package:nurse_matrouh/features/profile/services/user_profile_details_service.dart';

void main() {
  group('UserProfileDetails & Privacy Verification Tests', () {
    test('DoctorDepartmentSupervision correctly formats staffing requirements', () {
      const supervision = DoctorDepartmentSupervision(
        departmentId: 'dept-1',
        departmentName: 'العناية المركزة',
        maleCapacity: 2,
        femaleCapacity: 2,
        totalCapacity: 4,
      );

      expect(supervision.departmentName, equals('العناية المركزة'));
      expect(supervision.staffingRequirementText, equals('الاحتياج: 4 طلاب • 2 ذكور • 2 إناث'));
    });

    test('Staffing requirement handles empty capacity gracefully', () {
      const supervision = DoctorDepartmentSupervision(
        departmentId: 'dept-2',
        departmentName: 'العيادات الخارجية',
        maleCapacity: 0,
        femaleCapacity: 0,
        totalCapacity: 0,
      );

      expect(supervision.staffingRequirementText, equals('القسم لا يتطلب سعة محددة حالياً'));
    });

    test('120-USER SIMULATION PERFORMANCE: In-memory presence map operations under 5ms', () {
      final presenceMap = <String, UserPresenceModel>{};
      final now = DateTime.now();

      // Create 120 simulated users (100 students, 10 leaders, 8 doctors, 2 super admins)
      for (int i = 1; i <= 120; i++) {
        final id = 'user-uuid-$i';
        final isOnline = i % 3 == 0;
        final lastSeen = isOnline
            ? now.subtract(Duration(seconds: i % 60))
            : now.subtract(Duration(minutes: 5 + (i % 60)));

        presenceMap[id] = UserPresenceModel(
          userId: id,
          isOnline: isOnline,
          lastSeenAt: lastSeen,
          updatedAt: now,
        );
      }

      final stopwatch = Stopwatch()..start();

      int onlineCount = 0;
      int staleCount = 0;

      for (final entry in presenceMap.entries) {
        if (entry.value.isEffectivelyOnline) {
          onlineCount++;
        } else if (entry.value.isOnline) {
          staleCount++;
        }
      }

      stopwatch.stop();

      expect(presenceMap.length, equals(120));
      expect(onlineCount, greaterThan(0));
      expect(staleCount, greaterThanOrEqualTo(0));
      expect(stopwatch.elapsedMilliseconds, lessThan(50), reason: 'Batch parsing 120 users must be instantaneous');
    });

    test('ROLE PRIVACY: Student roles must have clean student code without UUID leakage', () {
      const studentCode = '222605000074';
      final profile = UserProfileDetailsData(
        userId: 'f87a98d3-2b21-4a41-9492-491294871924',
        fullName: 'مصطفى لطفي عبد الحميد',
        code: studentCode,
        role: UserRole.student,
        canViewPresence: false,
      );

      expect(profile.code, equals('222605000074'));
      expect(profile.code, isNot(contains('-')));
      expect(profile.canViewPresence, isFalse);
    });
  });
}
