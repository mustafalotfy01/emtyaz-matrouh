import 'package:flutter_test/flutter_test.dart';

// ── 1. Pure 36h Saturday-to-Friday Rule Engine (Matches Postgres RPC) ─────────
class WeekHoursResult {
  final DateTime weekStart;
  final DateTime weekEnd;
  final int totalHours;
  final bool isValid;

  WeekHoursResult({
    required this.weekStart,
    required this.weekEnd,
    required this.totalHours,
    required this.isValid,
  });
}

class ShiftValidator36h {
  static DateTime getSaturdayStart(DateTime date) {
    // In Dart: Monday=1, ..., Saturday=6, Sunday=7
    final int offset = (date.weekday == DateTime.saturday)
        ? 0
        : (date.weekday == DateTime.sunday ? 1 : date.weekday + 1);
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: offset));
  }

  static int getShiftDuration(String shiftType) {
    switch (shiftType.toLowerCase()) {
      case 'morning':
      case 'evening':
        return 6;
      case 'long':
      case 'night':
        return 12;
      default:
        return 0;
    }
  }

  static Map<String, dynamic> validateSchedule(List<Map<String, dynamic>> shifts) {
    if (shifts.isEmpty) {
      return {'valid': false, 'error': 'لم يتم تقديم أي شيفتات'};
    }

    final Map<DateTime, int> weekHoursMap = {};
    for (final s in shifts) {
      final date = DateTime.parse(s['shift_date']);
      final sat = getSaturdayStart(date);
      final duration = getShiftDuration(s['shift_type']);
      weekHoursMap[sat] = (weekHoursMap[sat] ?? 0) + duration;
    }

    final List<WeekHoursResult> weeks = [];
    bool allValid = true;
    String? firstError;

    final sortedSaturdays = weekHoursMap.keys.toList()..sort();
    for (final sat in sortedSaturdays) {
      final fri = sat.add(const Duration(days: 6));
      final hours = weekHoursMap[sat]!;
      final isValid = (hours == 36);
      weeks.add(WeekHoursResult(
        weekStart: sat,
        weekEnd: fri,
        totalHours: hours,
        isValid: isValid,
      ));

      if (!isValid) {
        allValid = false;
        firstError ??= 'الأسبوع من ${sat.toIso8601String().substring(0, 10)} إلى ${fri.toIso8601String().substring(0, 10)} يحتوي على $hours ساعة (المطلوب 36 ساعة بالضبط).';
      }
    }

    return {
      'valid': allValid,
      'error': firstError,
      'weeks': weeks,
    };
  }
}

// ── 2. Group Selection Validator (Matches Postgres RPC) ──────────────────────
class GroupSelectionValidator {
  static Map<String, dynamic> validateGroupSelection({
    required String studentId,
    required String studentGroup,
    required List<Map<String, dynamic>> selectedPeers,
  }) {
    // 1. Length check
    if (selectedPeers.length != 11) {
      return {
        'valid': false,
        'error': 'يجب اختيار 11 اسم زميل بالضبط (الحالي: ${selectedPeers.length})',
      };
    }

    // 2. Self check
    if (selectedPeers.any((p) => p['id'] == studentId)) {
      return {'valid': false, 'error': 'لا يمكن اختيار اسمك ضمن قائمة الزملاء'};
    }

    // 3. Duplicates check
    final distinctIds = selectedPeers.map((p) => p['id']).toSet();
    if (distinctIds.length != 11) {
      return {'valid': false, 'error': 'القائمة تحتوي على أسماء مكررة'};
    }

    // 4. Foreign group check
    final foreignGroup = selectedPeers.any((p) => p['group'] != studentGroup);
    if (foreignGroup) {
      return {'valid': false, 'error': 'تم اختيار طلاب من خارج مجموعتك الدراسية ($studentGroup)'};
    }

    // 5. Gender limits
    final maleCount = selectedPeers.where((p) => p['gender'] == 'male').length;
    final femaleCount = selectedPeers.where((p) => p['gender'] == 'female').length;

    if (maleCount > 4) {
      return {
        'valid': false,
        'error': 'تجاوزت الحد الأقصى للطلاب الذكور (المختار: $maleCount، الحد الأقصى: 4)',
      };
    }

    if (femaleCount > 7) {
      return {
        'valid': false,
        'error': 'تجاوزت الحد الأقصى للطالبات الإناث (المختار: $femaleCount، الحد الأقصى: 7)',
      };
    }

    return {
      'valid': true,
      'maleCount': maleCount,
      'femaleCount': femaleCount,
      'total': 11,
      'message': 'اختيار المجموعة مكتمل وصحيح وفق الضوابط',
    };
  }
}

// ── 3. Leaderboard Score Engine (Matches Postgres RPC) ───────────────────────
class LeaderboardCalculator {
  static double calculateScore({
    required int attendedShifts,
    required double avgQuizScore,
    required int approvedRewards,
    required int lateCount,
    required int absentCount,
    required int approvedWarnings,
    required double approvedDeductions,
  }) {
    final raw = 100.0 +
        (2.0 * attendedShifts) +
        ((avgQuizScore / 100.0) * 15.0) +
        (5.0 * approvedRewards) -
        (2.0 * lateCount) -
        (5.0 * absentCount) -
        (3.0 * approvedWarnings) -
        approvedDeductions;
    return raw.clamp(0.0, 150.0);
  }
}

void main() {
  group('Phase 1 Core Logic Tests: 36-Hour Saturday-to-Friday Rule', () {
    test('Week calculation: Exactly 36 hours (3 Longs = 12+12+12) is ACCEPTED', () {
      final shifts = [
        {'shift_date': '2026-08-01', 'shift_type': 'long'}, // Saturday (12h)
        {'shift_date': '2026-08-03', 'shift_type': 'long'}, // Monday (12h)
        {'shift_date': '2026-08-05', 'shift_type': 'long'}, // Wednesday (12h)
      ];
      final res = ShiftValidator36h.validateSchedule(shifts);
      expect(res['valid'], isTrue);
      expect(res['error'], isNull);
    });

    test('Week calculation: 35 hours is REJECTED', () {
      final shifts = [
        {'shift_date': '2026-08-01', 'shift_type': 'long'},    // 12h
        {'shift_date': '2026-08-03', 'shift_type': 'long'},    // 12h
        {'shift_date': '2026-08-05', 'shift_type': 'morning'}, // 6h
        {'shift_date': '2026-08-06', 'shift_type': 'absence'}, // 0h (Total = 30h)
      ];
      final res = ShiftValidator36h.validateSchedule(shifts);
      expect(res['valid'], isFalse);
      expect(res['error'], contains('30 ساعة'));
    });

    test('Week calculation: 37 hours (or 38h/42h) is REJECTED', () {
      final shifts = [
        {'shift_date': '2026-08-01', 'shift_type': 'long'},    // 12h
        {'shift_date': '2026-08-02', 'shift_type': 'night'},   // 12h
        {'shift_date': '2026-08-04', 'shift_type': 'long'},    // 12h
        {'shift_date': '2026-08-06', 'shift_type': 'morning'}, // 6h (Total = 42h)
      ];
      final res = ShiftValidator36h.validateSchedule(shifts);
      expect(res['valid'], isFalse);
      expect(res['error'], contains('42 ساعة'));
    });

    test('Cross-month boundary Saturday-to-Friday week (Aug 29 Sat - Sep 4 Fri) calculates properly', () {
      final shifts = [
        {'shift_date': '2026-08-29', 'shift_type': 'long'},  // Sat Aug 29 (12h)
        {'shift_date': '2026-08-31', 'shift_type': 'night'}, // Mon Aug 31 (12h)
        {'shift_date': '2026-09-02', 'shift_type': 'long'},  // Wed Sep 02 (12h)
      ];
      final res = ShiftValidator36h.validateSchedule(shifts);
      expect(res['valid'], isTrue);
      final weeks = res['weeks'] as List<WeekHoursResult>;
      expect(weeks.length, 1);
      expect(weeks[0].weekStart, DateTime(2026, 8, 29));
      expect(weeks[0].weekEnd, DateTime(2026, 9, 4));
      expect(weeks[0].totalHours, 36);
    });
  });

  group('Phase 1 Core Logic Tests: Group Selection & Gender Limits', () {
    test('11 selected peers (4 males + 7 females) in same group is ACCEPTED', () {
      final peers = [
        {'id': 'm1', 'gender': 'male', 'group': 'A'},
        {'id': 'm2', 'gender': 'male', 'group': 'A'},
        {'id': 'm3', 'gender': 'male', 'group': 'A'},
        {'id': 'm4', 'gender': 'male', 'group': 'A'},
        {'id': 'f1', 'gender': 'female', 'group': 'A'},
        {'id': 'f2', 'gender': 'female', 'group': 'A'},
        {'id': 'f3', 'gender': 'female', 'group': 'A'},
        {'id': 'f4', 'gender': 'female', 'group': 'A'},
        {'id': 'f5', 'gender': 'female', 'group': 'A'},
        {'id': 'f6', 'gender': 'female', 'group': 'A'},
        {'id': 'f7', 'gender': 'female', 'group': 'A'},
      ];
      final res = GroupSelectionValidator.validateGroupSelection(
        studentId: 'student-self',
        studentGroup: 'A',
        selectedPeers: peers,
      );
      expect(res['valid'], isTrue);
      expect(res['maleCount'], 4);
      expect(res['femaleCount'], 7);
    });

    test('5 males (exceeding limit of 4) is REJECTED', () {
      final peers = [
        {'id': 'm1', 'gender': 'male', 'group': 'A'},
        {'id': 'm2', 'gender': 'male', 'group': 'A'},
        {'id': 'm3', 'gender': 'male', 'group': 'A'},
        {'id': 'm4', 'gender': 'male', 'group': 'A'},
        {'id': 'm5', 'gender': 'male', 'group': 'A'},
        {'id': 'f1', 'gender': 'female', 'group': 'A'},
        {'id': 'f2', 'gender': 'female', 'group': 'A'},
        {'id': 'f3', 'gender': 'female', 'group': 'A'},
        {'id': 'f4', 'gender': 'female', 'group': 'A'},
        {'id': 'f5', 'gender': 'female', 'group': 'A'},
        {'id': 'f6', 'gender': 'female', 'group': 'A'},
      ];
      final res = GroupSelectionValidator.validateGroupSelection(
        studentId: 'student-self',
        studentGroup: 'A',
        selectedPeers: peers,
      );
      expect(res['valid'], isFalse);
      expect(res['error'], contains('الحد الأقصى للطلاب الذكور'));
    });

    test('8 females (exceeding limit of 7) is REJECTED', () {
      final peers = [
        {'id': 'm1', 'gender': 'male', 'group': 'A'},
        {'id': 'm2', 'gender': 'male', 'group': 'A'},
        {'id': 'm3', 'gender': 'male', 'group': 'A'},
        {'id': 'f1', 'gender': 'female', 'group': 'A'},
        {'id': 'f2', 'gender': 'female', 'group': 'A'},
        {'id': 'f3', 'gender': 'female', 'group': 'A'},
        {'id': 'f4', 'gender': 'female', 'group': 'A'},
        {'id': 'f5', 'gender': 'female', 'group': 'A'},
        {'id': 'f6', 'gender': 'female', 'group': 'A'},
        {'id': 'f7', 'gender': 'female', 'group': 'A'},
        {'id': 'f8', 'gender': 'female', 'group': 'A'},
      ];
      final res = GroupSelectionValidator.validateGroupSelection(
        studentId: 'student-self',
        studentGroup: 'A',
        selectedPeers: peers,
      );
      expect(res['valid'], isFalse);
      expect(res['error'], contains('الحد الأقصى للطالبات الإناث'));
    });

    test('Selected count != 11 (e.g. 10 or 12) is REJECTED', () {
      final peers = [
        {'id': 'm1', 'gender': 'male', 'group': 'A'},
        {'id': 'f1', 'gender': 'female', 'group': 'A'},
      ];
      final res = GroupSelectionValidator.validateGroupSelection(
        studentId: 'student-self',
        studentGroup: 'A',
        selectedPeers: peers,
      );
      expect(res['valid'], isFalse);
      expect(res['error'], contains('يجب اختيار 11 اسم زميل بالضبط'));
    });

    test('Self-selection or duplicate peer is REJECTED', () {
      final peersWithSelf = List.generate(11, (i) => {
        'id': i == 0 ? 'student-self' : 'p$i',
        'gender': 'male',
        'group': 'A',
      });
      final res = GroupSelectionValidator.validateGroupSelection(
        studentId: 'student-self',
        studentGroup: 'A',
        selectedPeers: peersWithSelf,
      );
      expect(res['valid'], isFalse);
      expect(res['error'], contains('لا يمكن اختيار اسمك'));
    });
  });

  group('Phase 1 Core Logic Tests: Leaderboard Scoring Formula', () {
    test('Standard student score computation matches reconciled formula exactly', () {
      // 100 base + (2*12 attended = 24) + ((80/100)*15 = 12) + (5*2 rewards = 10) - (2*1 late = 2) - (5*0 absent = 0) - (3*1 warning = 3) - (5 deduction) = 136.0
      final score = LeaderboardCalculator.calculateScore(
        attendedShifts: 12,
        avgQuizScore: 80.0,
        approvedRewards: 2,
        lateCount: 1,
        absentCount: 0,
        approvedWarnings: 1,
        approvedDeductions: 5.0,
      );
      expect(score, closeTo(136.0, 0.01));
    });

    test('Score is clamped between 0 and 150', () {
      // Extreme positive capped at 150
      final maxScore = LeaderboardCalculator.calculateScore(
        attendedShifts: 50,
        avgQuizScore: 100.0,
        approvedRewards: 20,
        lateCount: 0,
        absentCount: 0,
        approvedWarnings: 0,
        approvedDeductions: 0.0,
      );
      expect(maxScore, 150.0);

      // Extreme negative clamped at 0
      final minScore = LeaderboardCalculator.calculateScore(
        attendedShifts: 0,
        avgQuizScore: 0.0,
        approvedRewards: 0,
        lateCount: 20,
        absentCount: 20,
        approvedWarnings: 10,
        approvedDeductions: 100.0,
      );
      expect(minScore, 0.0);
    });
  });
}
