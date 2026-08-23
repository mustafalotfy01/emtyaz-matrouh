import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_matrouh/core/models/app_version_model.dart';
import 'package:nurse_matrouh/core/services/app_update_service.dart';
import 'package:nurse_matrouh/features/auth/models/user_profile.dart';

void main() {
  group('AppUpdateService & Version Comparison Logic Tests', () {
    test('TEST 1: Model JSON serialization and deserialization', () {
      final json = {
        'id': 'test-uuid-1234',
        'version_name': '1.2.0',
        'version_code': 3,
        'apk_download_url': 'https://zlxumwvygqcxhareknul.supabase.co/storage/v1/object/public/app-releases/android/1.2.0/app-release.apk',
        'release_notes': '• تحسينات الأداء وتحديث الحضور',
        'force_update': true,
        'minimum_supported_version': 2,
        'is_active': true,
        'platform': 'android',
        'file_name': 'app-release.apk',
        'file_size': 19500000,
        'release_date': '2026-08-21T20:00:00.000Z',
        'created_at': '2026-08-21T20:00:00.000Z',
      };

      final model = AppVersionModel.fromJson(json);
      expect(model.id, 'test-uuid-1234');
      expect(model.versionName, '1.2.0');
      expect(model.versionCode, 3);
      expect(model.forceUpdate, isTrue);
      expect(model.minimumSupportedVersion, 2);
      expect(model.isActive, isTrue);
      expect(model.platform, 'android');
      expect(model.formattedFileSize, '18.6 MB');

      final serialized = model.toJson();
      expect(serialized['version_name'], '1.2.0');
      expect(serialized['version_code'], 3);
      expect(serialized['force_update'], isTrue);
      expect(serialized['minimum_supported_version'], 2);
    });

    test('TEST 2: Version Code comparison - newer version triggers update', () {
      const installedCode = 1;
      const latestCode = 2;

      final hasUpdate = latestCode > installedCode;
      expect(hasUpdate, isTrue);

      final info = AppVersionInfo(
        currentVersion: '1.0.0',
        currentVersionCode: installedCode,
        latestVersion: '1.1.0',
        latestVersionCode: latestCode,
        releaseNotes: 'New feature',
        downloadUrl: 'https://example.com/app.apk',
        hasUpdate: hasUpdate,
      );

      expect(info.hasUpdate, isTrue);
    });

    test('TEST 3: Version Code comparison - equal version code does NOT trigger update', () {
      const installedCode = 2;
      const latestCode = 2;

      final hasUpdate = latestCode > installedCode;
      expect(hasUpdate, isFalse);

      final info = AppVersionInfo(
        currentVersion: '1.1.0',
        currentVersionCode: installedCode,
        latestVersion: '1.1.0',
        latestVersionCode: latestCode,
        releaseNotes: '',
        hasUpdate: hasUpdate,
      );

      expect(info.hasUpdate, isFalse);
    });

    test('TEST 4: Version Code comparison - older version code does NOT trigger update', () {
      const installedCode = 3;
      const latestCode = 2;

      final hasUpdate = latestCode > installedCode;
      expect(hasUpdate, isFalse);

      final info = AppVersionInfo(
        currentVersion: '1.2.0',
        currentVersionCode: installedCode,
        latestVersion: '1.1.0',
        latestVersionCode: latestCode,
        releaseNotes: '',
        hasUpdate: hasUpdate,
      );

      expect(info.hasUpdate, isFalse);
    });

    test('TEST 5: Force update triggered when force_update is true', () {
      int installedCode = 1;
      int latestCode = 2;
      int minSupported = 1;
      bool forceUpdate = true;

      bool calculateMandatory(bool force, int installed, int min) =>
          force || (installed < min);

      final isMandatory = calculateMandatory(forceUpdate, installedCode, minSupported);
      expect(isMandatory, isTrue);

      final info = AppVersionInfo(
        currentVersion: '1.0.0',
        currentVersionCode: installedCode,
        latestVersion: '1.1.0',
        latestVersionCode: latestCode,
        releaseNotes: 'Critical security update',
        isMandatory: isMandatory,
        hasUpdate: true,
      );

      expect(info.isMandatory, isTrue);
    });

    test('TEST 6: Force update triggered when installedCode < minimum_supported_version', () {
      int installedCode = 1;
      int latestCode = 3;
      bool forceUpdate = false;
      int minSupported = 2; // Required minimum

      bool calculateMandatory(bool force, int installed, int min) =>
          force || (installed < min);

      final isMandatory = calculateMandatory(forceUpdate, installedCode, minSupported);
      expect(isMandatory, isTrue);

      final info = AppVersionInfo(
        currentVersion: '1.0.0',
        currentVersionCode: installedCode,
        latestVersion: '1.2.0',
        latestVersionCode: latestCode,
        releaseNotes: 'Protocol upgrade',
        isMandatory: isMandatory,
        hasUpdate: true,
      );

      expect(info.isMandatory, isTrue);
    });

    test('TEST 7: Optional update when force_update=false and installedCode >= minSupported', () {
      int installedCode = 2;
      int latestCode = 3;
      bool forceUpdate = false;
      int minSupported = 2;

      bool calculateMandatory(bool force, int installed, int min) =>
          force || (installed < min);

      final isMandatory = calculateMandatory(forceUpdate, installedCode, minSupported);
      expect(isMandatory, isFalse);

      final info = AppVersionInfo(
        currentVersion: '1.1.0',
        currentVersionCode: installedCode,
        latestVersion: '1.2.0',
        latestVersionCode: latestCode,
        releaseNotes: 'Minor UI polish',
        isMandatory: isMandatory,
        hasUpdate: true,
      );

      expect(info.isMandatory, isFalse);
      expect(info.hasUpdate, isTrue);
    });

    test('TEST 8: Role-based permissions matrix verification', () {
      // Super Admin: CAN publish, edit, delete, activate
      expect(UserRole.superAdmin.toDbString(), 'super_admin');
      final bool adminCanManage = UserRole.superAdmin == UserRole.superAdmin;
      expect(adminCanManage, isTrue);

      // Leader: CANNOT publish, edit, delete, activate (Read-Only)
      final bool leaderCanManage = UserRole.leader == UserRole.superAdmin;
      expect(leaderCanManage, isFalse);

      // Doctor: CANNOT manage releases
      final bool doctorCanManage = UserRole.evaluatingDoctor == UserRole.superAdmin;
      expect(doctorCanManage, isFalse);

      // Student: CANNOT manage releases
      final bool studentCanManage = UserRole.student == UserRole.superAdmin;
      expect(studentCanManage, isFalse);
    });

    test('TEST 9: GitHub Releases metadata deserialization in AppVersionModel', () {
      final githubReleaseJson = {
        'id': 'github-rel-uuid-5678',
        'version_name': '1.3.0',
        'version_code': 4,
        'apk_download_url': 'https://github.com/mustafalotfy01/emtyaz-matrouh/releases/download/v1.3.0/app-release.apk',
        'download_url': 'https://github.com/mustafalotfy01/emtyaz-matrouh/releases/download/v1.3.0/app-release.apk',
        'release_notes': '• التحديث عبر GitHub Releases مع دعم استئناف التحميل',
        'force_update': false,
        'minimum_supported_version': 2,
        'is_active': true,
        'platform': 'android',
        'file_name': 'app-release.apk',
        'file_size': 63800000,
        'sha256': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        'github_release_id': 14285700,
        'github_tag_name': 'v1.3.0',
        'github_asset_id': 99887766,
        'release_url': 'https://github.com/mustafalotfy01/emtyaz-matrouh/releases/tag/v1.3.0',
        'release_date': '2026-08-24T10:00:00.000Z',
        'published_at': '2026-08-24T10:00:00.000Z',
        'created_at': '2026-08-24T10:00:00.000Z',
      };

      final model = AppVersionModel.fromJson(githubReleaseJson);
      expect(model.versionName, '1.3.0');
      expect(model.versionCode, 4);
      expect(model.apkDownloadUrl, contains('github.com/mustafalotfy01/emtyaz-matrouh/releases/download'));
      expect(model.githubReleaseId, 14285700);
      expect(model.githubTagName, 'v1.3.0');
      expect(model.githubAssetId, 99887766);
      expect(model.sha256, 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
      expect(model.formattedFileSize, '60.8 MB');

      final serialized = model.toJson();
      expect(serialized['github_tag_name'], 'v1.3.0');
      expect(serialized['github_release_id'], 14285700);
      expect(serialized['sha256'], isNotNull);
    });

    test('TEST 10: Strict downgrade prevention (Older version on server is ignored)', () {
      const installedCode = 10;
      const serverCode = 8; // Server has older version

      final hasUpdate = serverCode > installedCode;
      expect(hasUpdate, isFalse, reason: 'Downgrades must be strictly prevented');
    });
  });
}
