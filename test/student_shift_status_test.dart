import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nurse_matrouh/core/models/student_shift_status_model.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  group('StudentShiftStatus Resolution Tests (Overnight & Day Shifts)', () {
    test('NIGHT SHIFT OVERNIGHT RESOLUTION: At 02:00 AM on 25 Aug, student who started Night at 20:00 on 24 Aug is ACTIVE', () {
      // 25 Aug 02:00 AM
      final currentDateTime = DateTime(2026, 8, 25, 2, 0);

      final yesterdayEntry = {
        'shift_date': '2026-08-24',
        'shift_type': 'night',
        'department_name': 'قسم الطوارئ والعناية المركزة',
      };

      final status = StudentShiftStatus.resolve(
        currentDateTime: currentDateTime,
        yesterdayEntry: yesterdayEntry,
        todayEntry: null,
      );

      expect(status.category, equals(ShiftStatusCategory.currentShift));
      expect(status.shiftType, equals('night'));
      expect(status.departmentName, equals('قسم الطوارئ والعناية المركزة'));
      expect(status.categoryTitleArabic, equals('الشفت الحالي (جاري الآن)'));
      expect(status.startDateTime, equals(DateTime(2026, 8, 24, 20, 0)));
      expect(status.endDateTime, equals(DateTime(2026, 8, 25, 8, 0)));
    });

    test('MORNING SHIFT: Before 08:00 AM is upcomingToday', () {
      final currentDateTime = DateTime(2026, 8, 24, 7, 15);

      final todayEntry = {
        'shift_date': '2026-08-24',
        'shift_type': 'morning',
        'department_name': 'قسم الباطنة',
      };

      final status = StudentShiftStatus.resolve(
        currentDateTime: currentDateTime,
        todayEntry: todayEntry,
      );

      expect(status.category, equals(ShiftStatusCategory.upcomingToday));
      expect(status.shiftType, equals('morning'));
      expect(status.categoryTitleArabic, equals('شفت اليوم القادم'));
    });

    test('MORNING SHIFT: At 10:30 AM is currentShift', () {
      final currentDateTime = DateTime(2026, 8, 24, 10, 30);

      final todayEntry = {
        'shift_date': '2026-08-24',
        'shift_type': 'morning',
        'department_name': 'قسم الباطنة',
      };

      final status = StudentShiftStatus.resolve(
        currentDateTime: currentDateTime,
        todayEntry: todayEntry,
      );

      expect(status.category, equals(ShiftStatusCategory.currentShift));
      expect(status.shiftType, equals('morning'));
    });

    test('MORNING SHIFT: At 15:00 PM is completedToday', () {
      final currentDateTime = DateTime(2026, 8, 24, 15, 0);

      final todayEntry = {
        'shift_date': '2026-08-24',
        'shift_type': 'morning',
        'department_name': 'قسم الباطنة',
      };

      final status = StudentShiftStatus.resolve(
        currentDateTime: currentDateTime,
        todayEntry: todayEntry,
      );

      expect(status.category, equals(ShiftStatusCategory.completedToday));
      expect(status.shiftType, equals('morning'));
      expect(status.categoryTitleArabic, equals('شفت اليوم (مكتمل)'));
    });

    test('OFF SHIFT: Resolves to Off correctly', () {
      final currentDateTime = DateTime(2026, 8, 24, 12, 0);

      final todayEntry = {
        'shift_date': '2026-08-24',
        'shift_type': 'off',
      };

      final status = StudentShiftStatus.resolve(
        currentDateTime: currentDateTime,
        todayEntry: todayEntry,
      );

      expect(status.category, equals(ShiftStatusCategory.off));
      expect(status.shiftDisplayNameArabic, equals('Off — راحة'));
    });

    test('NO ASSIGNMENT: Resolves to noAssignment when no entries exist', () {
      final currentDateTime = DateTime(2026, 8, 24, 12, 0);

      final status = StudentShiftStatus.resolve(
        currentDateTime: currentDateTime,
        todayEntry: null,
        yesterdayEntry: null,
      );

      expect(status.category, equals(ShiftStatusCategory.noAssignment));
      expect(status.shiftDisplayNameArabic, equals('لا توجد توزيعة مسجلة اليوم'));
    });
  });
}
