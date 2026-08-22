import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_matrouh/features/auth/models/user_profile.dart';
import 'package:nurse_matrouh/features/roster/models/roster_month.dart';
import 'package:nurse_matrouh/features/roster/models/roster_preference.dart';
import 'package:nurse_matrouh/features/roster/services/roster_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await RosterService.clearAllPreferencesAndCache();
  });

  test('Full Test: Student Submits Preferences -> Leader Loads and Finds Student on Selected Day', () async {
    final currentMonth = RosterMonth.nextMonthDefault();
    final studentId = 'student-test-01';
    final studentName = 'عمار ياسر مصطفى محمود';

    // 1. Student selects 12 shifts in September (Group A: Days 1 to 12)
    // 6 Long shifts (Sept 1 - Sept 6) + 6 Night shifts (Sept 7 - Sept 12)
    final List<RosterPreference> studentPrefs = [];
    for (int day = 1; day <= 6; day++) {
      studentPrefs.add(RosterPreference(
        id: 'pref-$day',
        rosterId: currentMonth.id,
        studentId: studentId,
        preferenceDate: DateTime(currentMonth.year, currentMonth.month, day),
        preferenceType: PreferenceType.optionA,
        preferenceShiftType: PreferenceShiftType.longShift,
      ));
    }
    for (int day = 7; day <= 12; day++) {
      studentPrefs.add(RosterPreference(
        id: 'pref-$day',
        rosterId: currentMonth.id,
        studentId: studentId,
        preferenceDate: DateTime(currentMonth.year, currentMonth.month, day),
        preferenceType: PreferenceType.optionB,
        preferenceShiftType: PreferenceShiftType.night,
      ));
    }

    // 2. Student Submits Preferences
    final submitRes = await RosterService.submitPreferences(
      studentId: studentId,
      rosterId: currentMonth.id,
      studentGroup: StudentGroup.groupA,
      preferences: studentPrefs,
    );

    expect(submitRes['success'], isTrue, reason: 'Preferences submission should succeed with 6 Long + 6 Night');

    // 3. Leader Loads Summaries
    final mockRegisteredStudent = UserProfile(
      id: studentId,
      email: 'ammar@nurse.edu.eg',
      fullName: studentName,
      nationalId: '30101010101010',
      universityCode: '2026001',
      phoneNumber: '01000000000',
      gender: 'male',
      maritalStatus: 'single',
      childrenCount: 0,
      isMatrouhResident: true,
      emergencyContact: '01000000000',
      residenceAddress: 'مطروح',
      role: UserRole.student,
      studentGroup: StudentGroup.groupA,
      registrationStatus: RegistrationStatus.approved,
      createdAt: DateTime.now(),
    );

    final summaries = await RosterService.loadLeaderSummaries(
      rosterId: currentMonth.id,
      month: currentMonth.month,
      year: currentMonth.year,
      registeredStudents: [mockRegisteredStudent],
    );

    expect(summaries.isNotEmpty, isTrue);
    final ammarSummary = summaries.firstWhere((s) => s.studentId == studentId);
    expect(ammarSummary.preferences.length, equals(12));
    expect(ammarSummary.submissionStatus, equals(PreferenceStatus.submitted));

    // 4. Test Day Assignment Filter: Day 3 (Selected Long)
    final day3Date = DateTime(currentMonth.year, currentMonth.month, 3);
    final day3Pref = ammarSummary.preferences.firstWhere(
      (p) =>
          p.preferenceDate.year == day3Date.year &&
          p.preferenceDate.month == day3Date.month &&
          p.preferenceDate.day == day3Date.day,
    );
    expect(day3Pref.preferenceShiftType, equals(PreferenceShiftType.longShift));

    // 5. Test Day Assignment Filter: Day 10 (Selected Night)
    final day10Date = DateTime(currentMonth.year, currentMonth.month, 10);
    final day10Pref = ammarSummary.preferences.firstWhere(
      (p) =>
          p.preferenceDate.year == day10Date.year &&
          p.preferenceDate.month == day10Date.month &&
          p.preferenceDate.day == day10Date.day,
    );
    expect(day10Pref.preferenceShiftType, equals(PreferenceShiftType.night));

    // 6. Test Reset / Clear Preferences Button
    await RosterService.clearAllPreferencesAndCache();
    final summariesAfterClear = await RosterService.loadLeaderSummaries(
      rosterId: currentMonth.id,
      month: currentMonth.month,
      year: currentMonth.year,
      registeredStudents: [mockRegisteredStudent],
    );
    final clearedStudent = summariesAfterClear.firstWhere((s) => s.studentId == studentId);
    expect(clearedStudent.preferences.isEmpty, isTrue, reason: 'Preferences should be completely empty after reset');
  });
}
