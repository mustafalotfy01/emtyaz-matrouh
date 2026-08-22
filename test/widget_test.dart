import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nurse_matrouh/main.dart';

void main() {
  testWidgets('Nurse Matrouh App smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: NurseMatrouhApp(),
      ),
    );

    expect(find.byType(NurseMatrouhApp), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
