import '../../../core/utils/app_date_utils.dart';

/// نوع شيفت التفضيل للطالب (Morning / Long / Night)
enum PreferenceShiftType {
  morning,   // صباحي
  longShift, // طويل
  night;     // ليلي

  String get code {
    switch (this) {
      case PreferenceShiftType.morning: return 'M';
      case PreferenceShiftType.longShift: return 'L';
      case PreferenceShiftType.night: return 'N';
    }
  }

  String get displayNameAr {
    switch (this) {
      case PreferenceShiftType.morning: return 'صباحي (Morning)';
      case PreferenceShiftType.longShift: return 'طويل (Long)';
      case PreferenceShiftType.night: return 'ليلي (Night)';
    }
  }

  String get shortNameAr {
    switch (this) {
      case PreferenceShiftType.morning: return 'ص';
      case PreferenceShiftType.longShift: return 'ط';
      case PreferenceShiftType.night: return 'ل';
    }
  }

  int get hours {
    switch (this) {
      case PreferenceShiftType.morning:
        return 6;
      case PreferenceShiftType.longShift:
      case PreferenceShiftType.night:
        return 12;
    }
  }

  static PreferenceShiftType fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'L':
      case 'LONG':
        return PreferenceShiftType.longShift;
      case 'N':
      case 'NIGHT':
        return PreferenceShiftType.night;
      case 'M':
      case 'MORNING':
      default:
        return PreferenceShiftType.morning;
    }
  }
}

/// تمثيل الأسبوع السريري من السبت إلى الجمعة
class WeeklyHoursSummary {
  final int weekNumber;
  final DateTime weekStart;
  final DateTime weekEnd;
  final int totalHours;
  final int requiredHours;

  const WeeklyHoursSummary({
    required this.weekNumber,
    required this.weekStart,
    required this.weekEnd,
    required this.totalHours,
    this.requiredHours = 36,
  });

  bool get isValid => totalHours == requiredHours;
}

/// قواعد الروستر وحساب 36 ساعة لكل أسبوع (السبت -> الجمعة)
class ShiftRulesHelper {
  static const int baseRequiredDays = 12;
  static const int requiredDays = 12;
  static const int minNightIfNoNight = 4;
  static const int requiredWeeklyHours = 36;

  /// حساب إجمالي الأيام المطلوبة بناءً على عدد الصباحي:
  static int requiredDaysForMorning(int morningCount) {
    return baseRequiredDays + (morningCount ~/ 2);
  }

  /// توافر اليوم للمجموعة (جميع أيام الشهر متاحة حالياً)
  static bool isDayAvailableForGroup({
    required int day,
    required bool isGroupA,
    required int daysInMonth,
  }) {
    return day >= 1 && day <= daysInMonth;
  }

  /// التحقق من أن عدد الصباحي زوجي
  static bool isMorningEven(int morningCount) => morningCount % 2 == 0;

  /// تقسيم أيام الشهر إلى أسابيع (السبت -> الجمعة) وحساب ساعات كل أسبوع
  static List<WeeklyHoursSummary> calculateWeeklySummaries({
    required int month,
    required int year,
    required List<RosterPreference> preferences,
  }) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final List<WeeklyHoursSummary> summaries = [];

    // Group dates by their Saturday start date
    DateTime currentDate = DateTime(year, month, 1);
    int weekNum = 1;

    // Find the first Saturday on or before day 1
    int offsetToSaturday = (currentDate.weekday + 1) % 7; // Saturday = 0
    DateTime currentWeekStart = currentDate.subtract(Duration(days: offsetToSaturday));

    while (currentWeekStart.isBefore(DateTime(year, month, daysInMonth).add(const Duration(days: 1)))) {
      DateTime currentWeekEnd = currentWeekStart.add(const Duration(days: 6));

      int weekHours = 0;
      for (final p in preferences) {
        if (p.preferenceDate.isAfter(currentWeekStart.subtract(const Duration(days: 1))) &&
            p.preferenceDate.isBefore(currentWeekEnd.add(const Duration(days: 1)))) {
          weekHours += p.preferenceShiftType.hours;
        }
      }

      summaries.add(WeeklyHoursSummary(
        weekNumber: weekNum++,
        weekStart: currentWeekStart,
        weekEnd: currentWeekEnd,
        totalHours: weekHours,
        requiredHours: requiredWeeklyHours,
      ));

      currentWeekStart = currentWeekStart.add(const Duration(days: 7));
    }

    return summaries;
  }

  /// التحقق الشامل من التفضيلات وفق قاعدة 36 ساعة أسبوعياً
  static ShiftValidationResult validate({
    required int morningCount,
    required int longCount,
    required int nightCount,
    List<WeeklyHoursSummary> weeklySummaries = const [],
  }) {
    final total = morningCount + longCount + nightCount;
    final requiredTotal = requiredDaysForMorning(morningCount);

    if (!isMorningEven(morningCount)) {
      return ShiftValidationResult(
        isValid: false,
        canSubmit: false,
        message: 'اخترت $morningCount صباحي. يجب أن يكون عدد الصباحي زوجياً (كل يومين صباحي = شيفت كامل).',
        ruleViolation: ShiftRuleViolation.morningNotEven,
      );
    }

    if (total < requiredTotal) {
      return ShiftValidationResult(
        isValid: false,
        canSubmit: false,
        message: 'المطلوب $requiredTotal يوماً بناءً على اختيارك ($morningCount صباحي). اخترت $total فقط.',
      );
    }

    if (total > requiredTotal) {
      return ShiftValidationResult(
        isValid: false,
        canSubmit: false,
        message: 'اخترت $total يوماً (الحد المطلوب لاختياراتك هو $requiredTotal يوم).',
      );
    }

    if (nightCount < 2) {
      return ShiftValidationResult(
        isValid: false,
        canSubmit: false,
        message: 'يجب اختيار يومين ليليين (Night) على الأقل (اخترت $nightCount).',
        ruleViolation: ShiftRuleViolation.insufficientNight,
      );
    }

    // Check weekly 36h compliance if weeklySummaries provided
    for (final w in weeklySummaries) {
      if (w.totalHours > 0 && w.totalHours != 36) {
        return ShiftValidationResult(
          isValid: false,
          canSubmit: false,
          message: 'الأسبوع ${w.weekNumber} يحتوي على ${w.totalHours} ساعة (المطلوب 36 ساعة بالضبط).',
          ruleViolation: ShiftRuleViolation.weeklyHoursMismatch,
        );
      }
    }

    return ShiftValidationResult(
      isValid: true,
      canSubmit: true,
      message: 'اختياراتك متوافقة مع قاعدة الـ 36 ساعة أسبوعياً ($total يوم) ✓',
    );
  }


  static String get rulesText =>
      'القواعد: إجمالي ٣٦ ساعة لكل أسبوع (السبت -> الجمعة) • صباحي (٦ ساعات) • طويل (١٢ ساعة) • ليلي (١٢ ساعة)';
}

enum ShiftRuleViolation {
  noNight,
  insufficientNight,
  allNightNoLong,
  morningNotEven,
  weeklyHoursMismatch,
}

class ShiftValidationResult {
  final bool isValid;
  final bool canSubmit;
  final String message;
  final ShiftRuleViolation? ruleViolation;

  const ShiftValidationResult({
    required this.isValid,
    required this.canSubmit,
    required this.message,
    this.ruleViolation,
  });
}

// ─── PreferenceType (legacy A/B kept for DB compatibility) ───────────────────
enum PreferenceType {
  optionA,
  optionB;

  String get code => this == PreferenceType.optionA ? 'A' : 'B';
  String get displayNameAr => this == PreferenceType.optionA ? 'A' : 'B';

  static PreferenceType fromString(String val) {
    if (val.toUpperCase() == 'B' || val == 'optionB' || val == 'option_b') {
      return PreferenceType.optionB;
    }
    return PreferenceType.optionA;
  }
}

enum PreferenceStatus {
  draft,
  submitted,
  locked;

  String get displayNameAr {
    switch (this) {
      case PreferenceStatus.draft:
        return 'مسودة قيد الاختيار';
      case PreferenceStatus.submitted:
        return 'تم الإرسال للمراجعة';
      case PreferenceStatus.locked:
        return 'مغلق ومحفوظ';
    }
  }

  static PreferenceStatus fromString(String val) {
    switch (val.toLowerCase()) {
      case 'submitted':
        return PreferenceStatus.submitted;
      case 'locked':
        return PreferenceStatus.locked;
      case 'draft':
      default:
        return PreferenceStatus.draft;
    }
  }
}

class RosterPreference {
  final String id;
  final String rosterId;
  final String studentId;
  final DateTime preferenceDate;
  final PreferenceType preferenceType;
  final PreferenceShiftType preferenceShiftType;
  final PreferenceStatus status;
  final DateTime? submittedAt;
  final DateTime? createdAt;

  RosterPreference({
    required this.id,
    required this.rosterId,
    required this.studentId,
    required this.preferenceDate,
    required this.preferenceType,
    this.preferenceShiftType = PreferenceShiftType.morning,
    this.status = PreferenceStatus.draft,
    this.submittedAt,
    this.createdAt,
  });

  bool get isOptionA => preferenceType == PreferenceType.optionA;
  bool get isOptionB => preferenceType == PreferenceType.optionB;

  factory RosterPreference.fromJson(Map<String, dynamic> json) {
    final shiftTypeStr = json['shift_type']?.toString();
    final prefTypeStr = json['preference_type']?.toString() ?? 'L';

    PreferenceShiftType shiftType;
    if (shiftTypeStr != null && shiftTypeStr.isNotEmpty) {
      shiftType = PreferenceShiftType.fromString(shiftTypeStr);
    } else {
      shiftType = prefTypeStr == 'B' || prefTypeStr == 'N'
          ? PreferenceShiftType.night
          : (prefTypeStr == 'M' ? PreferenceShiftType.morning : PreferenceShiftType.longShift);
    }

    final rawDate = json['preference_date'];
    final parsedDate = rawDate is DateTime ? rawDate : DateTime.parse(rawDate.toString());

    return RosterPreference(
      id: json['id']?.toString() ?? '',
      rosterId: json['roster_id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      preferenceDate: parsedDate,
      preferenceType: PreferenceType.fromString(json['preference_type']?.toString() ?? 'A'),
      preferenceShiftType: shiftType,
      status: PreferenceStatus.fromString(json['status']?.toString() ?? 'draft'),
      submittedAt: json['submitted_at'] != null ? DateTime.parse(json['submitted_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'roster_id': rosterId,
    'student_id': studentId,
    'preference_date': AppDateUtils.toIsoDate(preferenceDate),
    'preference_type': preferenceType.code,
    'shift_type': preferenceShiftType.code,
    'status': status.name,
    if (submittedAt != null) 'submitted_at': submittedAt!.toIso8601String(),
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };

  Map<String, dynamic> toSupabasePayload() => {
    'roster_id': rosterId,
    'student_id': studentId,
    'preference_date': AppDateUtils.toIsoDate(preferenceDate),
    'preference_type': preferenceType.code,
    'shift_type': preferenceShiftType.code,
    'status': status.name,
    'submitted_at': submittedAt?.toIso8601String(),
  };

  RosterPreference copyWith({
    String? id,
    String? rosterId,
    String? studentId,
    DateTime? preferenceDate,
    PreferenceType? preferenceType,
    PreferenceShiftType? preferenceShiftType,
    PreferenceStatus? status,
    DateTime? submittedAt,
    DateTime? createdAt,
  }) {
    return RosterPreference(
      id: id ?? this.id,
      rosterId: rosterId ?? this.rosterId,
      studentId: studentId ?? this.studentId,
      preferenceDate: preferenceDate ?? this.preferenceDate,
      preferenceType: preferenceType ?? this.preferenceType,
      preferenceShiftType: preferenceShiftType ?? this.preferenceShiftType,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
