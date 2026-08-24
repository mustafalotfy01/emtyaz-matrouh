import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum ShiftStatusCategory {
  currentShift,
  upcomingToday,
  completedToday,
  off,
  noAssignment,
}

@immutable
class StudentShiftStatus {
  final ShiftStatusCategory category;
  final String shiftType; // 'morning', 'long', 'night', 'off', or ''
  final String? departmentName;
  final DateTime? startDateTime;
  final DateTime? endDateTime;
  final DateTime? shiftDate;

  const StudentShiftStatus({
    required this.category,
    this.shiftType = '',
    this.departmentName,
    this.startDateTime,
    this.endDateTime,
    this.shiftDate,
  });

  /// Factory resolving current/today assignment considering overnight night shifts
  factory StudentShiftStatus.resolve({
    required DateTime currentDateTime,
    Map<String, dynamic>? todayEntry,
    Map<String, dynamic>? yesterdayEntry,
  }) {
    final now = currentDateTime;
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // 1. Check Yesterday Overnight Night Shift
    if (yesterdayEntry != null) {
      final yShiftType = (yesterdayEntry['shift_type'] as String? ?? '').toLowerCase();
      if (yShiftType == 'night' || yShiftType == 'ليلي') {
        final yStart = DateTime(yesterday.year, yesterday.month, yesterday.day, 20, 0);
        final yEnd = DateTime(today.year, today.month, today.day, 8, 0);

        if (now.isAfter(yStart) && now.isBefore(yEnd)) {
          final deptName = yesterdayEntry['department_name'] as String? ??
              yesterdayEntry['departments']?['name_ar'] as String? ??
              'القسم المحدد';

          return StudentShiftStatus(
            category: ShiftStatusCategory.currentShift,
            shiftType: 'night',
            departmentName: deptName,
            startDateTime: yStart,
            endDateTime: yEnd,
            shiftDate: yesterday,
          );
        }
      }
    }

    // 2. Check Today's Entry
    if (todayEntry != null) {
      final tShiftType = (todayEntry['shift_type'] as String? ?? '').toLowerCase();
      final deptName = todayEntry['department_name'] as String? ??
          todayEntry['departments']?['name_ar'] as String? ??
          'القسم المحدد';

      if (tShiftType == 'off' || tShiftType == 'راحة') {
        return StudentShiftStatus(
          category: ShiftStatusCategory.off,
          shiftType: 'off',
          departmentName: deptName,
          shiftDate: today,
        );
      }

      if (tShiftType == 'morning' || tShiftType == 'صباحي') {
        final start = DateTime(today.year, today.month, today.day, 8, 0);
        final end = DateTime(today.year, today.month, today.day, 14, 0);

        if (now.isBefore(start)) {
          return StudentShiftStatus(
            category: ShiftStatusCategory.upcomingToday,
            shiftType: 'morning',
            departmentName: deptName,
            startDateTime: start,
            endDateTime: end,
            shiftDate: today,
          );
        } else if (now.isBefore(end)) {
          return StudentShiftStatus(
            category: ShiftStatusCategory.currentShift,
            shiftType: 'morning',
            departmentName: deptName,
            startDateTime: start,
            endDateTime: end,
            shiftDate: today,
          );
        } else {
          return StudentShiftStatus(
            category: ShiftStatusCategory.completedToday,
            shiftType: 'morning',
            departmentName: deptName,
            startDateTime: start,
            endDateTime: end,
            shiftDate: today,
          );
        }
      }

      if (tShiftType == 'long' || tShiftType == 'طويل') {
        final start = DateTime(today.year, today.month, today.day, 8, 0);
        final end = DateTime(today.year, today.month, today.day, 20, 0);

        if (now.isBefore(start)) {
          return StudentShiftStatus(
            category: ShiftStatusCategory.upcomingToday,
            shiftType: 'long',
            departmentName: deptName,
            startDateTime: start,
            endDateTime: end,
            shiftDate: today,
          );
        } else if (now.isBefore(end)) {
          return StudentShiftStatus(
            category: ShiftStatusCategory.currentShift,
            shiftType: 'long',
            departmentName: deptName,
            startDateTime: start,
            endDateTime: end,
            shiftDate: today,
          );
        } else {
          return StudentShiftStatus(
            category: ShiftStatusCategory.completedToday,
            shiftType: 'long',
            departmentName: deptName,
            startDateTime: start,
            endDateTime: end,
            shiftDate: today,
          );
        }
      }

      if (tShiftType == 'night' || tShiftType == 'ليلي') {
        final start = DateTime(today.year, today.month, today.day, 20, 0);
        final tomorrow = today.add(const Duration(days: 1));
        final end = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8, 0);

        if (now.isBefore(start)) {
          return StudentShiftStatus(
            category: ShiftStatusCategory.upcomingToday,
            shiftType: 'night',
            departmentName: deptName,
            startDateTime: start,
            endDateTime: end,
            shiftDate: today,
          );
        } else if (now.isBefore(end)) {
          return StudentShiftStatus(
            category: ShiftStatusCategory.currentShift,
            shiftType: 'night',
            departmentName: deptName,
            startDateTime: start,
            endDateTime: end,
            shiftDate: today,
          );
        }
      }
    }

    // 3. No assignment found
    return const StudentShiftStatus(category: ShiftStatusCategory.noAssignment);
  }

  String get categoryTitleArabic {
    switch (category) {
      case ShiftStatusCategory.currentShift:
        return 'الشفت الحالي (جاري الآن)';
      case ShiftStatusCategory.upcomingToday:
        return 'شفت اليوم القادم';
      case ShiftStatusCategory.completedToday:
        return 'شفت اليوم (مكتمل)';
      case ShiftStatusCategory.off:
        return 'راحة أسبوعية';
      case ShiftStatusCategory.noAssignment:
        return 'توزيعة اليوم';
    }
  }

  String get shiftDisplayNameArabic {
    switch (shiftType.toLowerCase()) {
      case 'morning':
      case 'صباحي':
        return 'صباحي (Morning)';
      case 'long':
      case 'طويل':
        return 'طويل (Long Shift)';
      case 'night':
      case 'ليلي':
        return 'ليلي (Night Shift)';
      case 'off':
      case 'راحة':
        return 'Off — راحة';
      default:
        return category == ShiftStatusCategory.noAssignment
            ? 'لا توجد توزيعة مسجلة اليوم'
            : shiftType;
    }
  }

  String get formattedTimeInterval {
    if (startDateTime == null || endDateTime == null) {
      if (category == ShiftStatusCategory.off) return 'راحة طوال اليوم';
      return '';
    }
    final timeFmt = DateFormat('hh:mm a', 'ar');
    return '${timeFmt.format(startDateTime!)} ← ${timeFmt.format(endDateTime!)}';
  }

  Color get statusBadgeColor {
    switch (category) {
      case ShiftStatusCategory.currentShift:
        return const Color(0xFF10B981); // Emerald Green
      case ShiftStatusCategory.upcomingToday:
        return const Color(0xFF0EA5E9); // Sky Blue
      case ShiftStatusCategory.completedToday:
        return const Color(0xFF64748B); // Slate Muted
      case ShiftStatusCategory.off:
        return const Color(0xFF8B5CF6); // Violet
      case ShiftStatusCategory.noAssignment:
        return const Color(0xFF94A3B8); // Gray
    }
  }
}
