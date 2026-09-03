import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nurse_matrouh/core/localization/app_localizations.dart';
import 'package:nurse_matrouh/features/auth/models/user_profile.dart';
import 'package:nurse_matrouh/features/roster/widgets/roster_calendar_grid.dart';
import 'package:nurse_matrouh/features/roster/screens/student_roster_screen.dart';

void main() {
  testWidgets('RosterCalendarGrid renders without any layout exceptions', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          locale: Locale('ar'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: RosterCalendarGrid(
                month: 9,
                year: 2026,
                studentGroup: StudentGroup.unassigned,
                preferences: [],
                publishedShifts: [],
                isPublishedView: false,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('الأسبوع 1 (السبت ← الجمعة)'), findsOneWidget);
  });

  testWidgets('StudentRosterScreen renders fully without any layout exceptions', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          locale: Locale('ar'),
          home: StudentRosterScreen(isEmbeddedInTabs: true),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(StudentRosterScreen), findsOneWidget);
  });
}
