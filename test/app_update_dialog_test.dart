import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_matrouh/core/services/app_update_service.dart';
import 'package:nurse_matrouh/features/profile/widgets/app_update_dialog.dart';

void main() {
  testWidgets('TEST 9: Optional update dialog renders version and both action buttons', (tester) async {
    const info = AppVersionInfo(
      currentVersion: '1.0.0',
      currentVersionCode: 1,
      latestVersion: '1.1.0',
      latestVersionCode: 2,
      releaseNotes: '• تحسين استقرار الحضور\n• إصلاح مشكلة الإشعارات',
      downloadUrl: 'https://example.com/app.apk',
      isMandatory: false,
      hasUpdate: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => AppUpdateModal.showUpdateDialog(context, info),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('تحديث جديد متاح 🚀'), findsOneWidget);

    // Verify versions displayed
    expect(find.text('v1.0.0 (#1)'), findsOneWidget);
    expect(find.text('v1.1.0 (#2)'), findsOneWidget);

    // Verify Release notes
    expect(find.text('• تحسين استقرار الحضور\n• إصلاح مشكلة الإشعارات'), findsOneWidget);

    // Verify both action buttons exist
    expect(find.text('تحديث الآن'), findsOneWidget);
    expect(find.text('لاحقاً'), findsOneWidget);

    // Tap "لاحقاً" to dismiss
    await tester.tap(find.text('لاحقاً'));
    await tester.pumpAndSettle();
    expect(find.text('تحديث جديد متاح 🚀'), findsNothing);
  });

  testWidgets('TEST 10: Mandatory update dialog renders Force Update UI and HIDES later button', (tester) async {
    const info = AppVersionInfo(
      currentVersion: '1.0.0',
      currentVersionCode: 1,
      latestVersion: '2.0.0',
      latestVersionCode: 5,
      releaseNotes: '• تحديث أمني إجباري للنظام',
      downloadUrl: 'https://example.com/app-v2.apk',
      isMandatory: true, // Force update
      hasUpdate: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => AppUpdateModal.showUpdateDialog(context, info),
              child: const Text('Open Mandatory Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Mandatory Dialog'));
    await tester.pumpAndSettle();

    // Verify Mandatory Title
    expect(find.text('تحديث إجباري مطلوب'), findsOneWidget);
    expect(find.text('يلزم التحديث للاستمرار في استخدام التطبيق'), findsOneWidget);

    // Verify update button is present
    expect(find.text('تحديث الآن'), findsOneWidget);

    // Verify "لاحقاً" is strictly NOT present
    expect(find.text('لاحقاً'), findsNothing);
  });
}
