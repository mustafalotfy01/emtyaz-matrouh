import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_matrouh/core/models/user_app_version_model.dart';
import 'package:nurse_matrouh/features/admin/models/admin_student_overview_model.dart';

void main() {
  group('Admin Student Management & Version Tracking Tests', () {
    final baseServerNow = DateTime.utc(2026, 8, 24, 20, 0, 0);

    test('Platform-Aware App Update Status Parsing', () {
      expect(AppUpdateStatus.fromString('up_to_date'), AppUpdateStatus.upToDate);
      expect(AppUpdateStatus.fromString('outdated'), AppUpdateStatus.outdated);
      expect(AppUpdateStatus.fromString('force_update_required'), AppUpdateStatus.forceUpdateRequired);
      expect(AppUpdateStatus.fromString('unknown'), AppUpdateStatus.unknown);
      expect(AppUpdateStatus.fromString(null), AppUpdateStatus.unknown);

      expect(AppUpdateStatus.upToDate.displayNameAr, 'محدث');
      expect(AppUpdateStatus.outdated.displayNameAr, 'يحتاج تحديث');
    });

    test('AdminStudentOverviewModel: Online / Last Seen Stale Timeout Calculation (2 min rule)', () {
      // 1. Fresh heartbeat 30 seconds ago -> Online
      final freshStudent = AdminStudentOverviewModel(
        studentId: 'st-01',
        fullName: 'مصطفى محمود',
        universityCode: '12345',
        email: 'mostafa@test.com',
        phoneNumber: '01012345678',
        studentGroup: 'A',
        registrationStatus: 'approved',
        isApproved: true,
        avatarUrl: '',
        isOnline: true,
        effectiveIsOnline: true,
        lastSeenAt: baseServerNow.subtract(const Duration(seconds: 30)),
        appPlatform: 'android',
        installedVersionName: '1.3.0',
        installedVersionCode: 4,
        deviceInfo: 'Android 14',
        latestPlatformVersionName: '1.3.0',
        latestPlatformVersionCode: 4,
        updateStatus: AppUpdateStatus.upToDate,
        serverNow: baseServerNow,
      );

      expect(freshStudent.isEffectivelyOnlineAt(baseServerNow), isTrue);
      expect(freshStudent.formattedPresenceArabic(baseServerNow), 'متصل الآن');

      // 2. Stale heartbeat 150 seconds ago (> 2 minutes) -> Automatically Offline
      final staleStudent = freshStudent.copyWithPresence(
        lastSeenAt: baseServerNow.subtract(const Duration(seconds: 150)),
      );

      expect(staleStudent.isEffectivelyOnlineAt(baseServerNow), isFalse);
      expect(staleStudent.formattedPresenceArabic(baseServerNow), contains('منذ'));
    });

    test('Platform and Version formatted display text', () {
      final model = AdminStudentOverviewModel(
        studentId: 'st-02',
        fullName: 'أحمد محمد',
        universityCode: '67890',
        email: 'ahmed@test.com',
        phoneNumber: '01098765432',
        studentGroup: 'B',
        registrationStatus: 'approved',
        isApproved: true,
        avatarUrl: '',
        isOnline: false,
        effectiveIsOnline: false,
        lastSeenAt: baseServerNow.subtract(const Duration(minutes: 15)),
        appPlatform: 'android',
        installedVersionName: '1.2.1',
        installedVersionCode: 3,
        deviceInfo: '',
        latestPlatformVersionName: '1.3.0',
        latestPlatformVersionCode: 4,
        updateStatus: AppUpdateStatus.outdated,
        serverNow: baseServerNow,
      );

      expect(model.formattedPlatformAndVersion, 'Android • 1.2.1 (#3)');
      expect(model.updateStatus, AppUpdateStatus.outdated);
    });
  });
}
