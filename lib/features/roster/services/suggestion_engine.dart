import '../models/roster_entry.dart';
import '../models/roster_preference.dart';
import '../../auth/models/user_profile.dart';

class SuggestionEngine {
  SuggestionEngine._();

  /// Generates automatic assignment suggestion based on student's exact requested shifts:
  /// - Uses student's chosen dates and shift types (Morning / Long / Night) directly
  /// - Fallback to group default window (1-15 for Group A, 16-end for Group B)
  static List<RosterEntry> generateSuggestion1({
    required String studentId,
    required String studentName,
    required StudentGroup studentGroup,
    required String rosterId,
    required int month,
    required int year,
    required List<RosterPreference> preferences,
    String defaultDeptId = 'a0000001-0000-0000-0000-000000000001',
    String defaultDeptName = 'قسم الطوارئ',
  }) {
    final List<RosterEntry> entries = [];

    // Sort student preferences chronologically
    final sortedPrefs = List<RosterPreference>.from(preferences)
      ..sort((a, b) => a.preferenceDate.compareTo(b.preferenceDate));

    final morningCount = preferences.where((p) => p.preferenceShiftType == PreferenceShiftType.morning).length;
    final totalTarget = ShiftRulesHelper.requiredDaysForMorning(morningCount);

    for (final pref in sortedPrefs.take(totalTarget)) {
      final entryShiftType = pref.preferenceShiftType == PreferenceShiftType.night
          ? ShiftType.night
          : pref.preferenceShiftType == PreferenceShiftType.longShift
              ? ShiftType.long
              : ShiftType.morning;

      entries.add(
        RosterEntry(
          id: 'sug-${DateTime.now().millisecondsSinceEpoch}-${pref.preferenceDate.day}',
          rosterId: rosterId,
          studentId: studentId,
          studentName: studentName,
          shiftDate: pref.preferenceDate,
          shiftType: entryShiftType,
          departmentId: defaultDeptId,
          departmentName: defaultDeptName,
          status: ShiftStatus.approved,
          preferenceType: pref.preferenceShiftType.code,
        ),
      );
    }

    // Fallback if preferences are fewer than required days
    if (entries.length < totalTarget) {
      final daysInMonth = DateTime(year, month + 1, 0).day;
      final startDay = studentGroup == StudentGroup.groupA ? 1 : 16;
      final endDay = studentGroup == StudentGroup.groupA ? 15 : daysInMonth;

      for (int d = startDay; d <= endDay && entries.length < totalTarget; d++) {
        final dt = DateTime(year, month, d);
        if (!entries.any((e) => e.shiftDate.day == d)) {
          entries.add(
            RosterEntry(
              id: 'sug-fb-${DateTime.now().millisecondsSinceEpoch}-$d',
              rosterId: rosterId,
              studentId: studentId,
              studentName: studentName,
              shiftDate: dt,
              shiftType: (entries.length % 2 == 0) ? ShiftType.night : ShiftType.long,
              departmentId: defaultDeptId,
              departmentName: defaultDeptName,
              status: ShiftStatus.approved,
              preferenceType: 'M',
            ),
          );
        }
      }
    }

    return entries;
  }
}
