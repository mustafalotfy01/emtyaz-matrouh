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

  static PreferenceShiftType fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'L': return PreferenceShiftType.longShift;
      case 'N': return PreferenceShiftType.night;
      case 'M':
      default: return PreferenceShiftType.morning;
    }
  }
}

/// قواعد الروستر وحساب التوازن بين الشيفتات
class ShiftRulesHelper {
  static const int baseRequiredDays = 12;
  static const int requiredDays = baseRequiredDays;
  static const int minNightIfNoNight = 2;
  static const int minLongIfAllNight = 2;
  static const int minMorningEquivIfAllNight = 4;

  /// حساب إجمالي الأيام المطلوبة بناءً على عدد الصباحي:
  /// الأساس 12 يوم. كل يومين صباحي يعادلان شيفت طويل واحد، وبالتالي:
  /// - 0 صباحي = 12 يوم
  /// - 2 صباحي = 13 يوم (2 صباحي + 11 شيفت آخر)
  /// - 4 صباحي = 14 يوم (4 صباحي + 10 شيفت آخر)
  /// - 6 صباحي = 15 يوم
  static int requiredDaysForMorning(int morningCount) {
    return baseRequiredDays + (morningCount ~/ 2);
  }

  /// التحقق من أن عدد الصباحي زوجي
  static bool isMorningEven(int morningCount) => morningCount % 2 == 0;

  /// التحقق من توافر اليوم للمجموعة:
  /// - المجموعة A: دائماً الأيام 1 إلى 15 (ثابتة بدون فتح أيام إضافية).
  /// - المجموعة B: دائماً الأيام 16 إلى نهاية الشهر (ثابتة بدون فتح أيام إضافية).
  static bool isDayAvailableForGroup({
    required int day,
    required bool isGroupA,
    required int daysInMonth,
  }) {
    if (isGroupA) {
      return day >= 1 && day <= 15;
    } else {
      return day >= 16 && day <= daysInMonth;
    }
  }

  /// التحقق الشامل من التفضيلات
  static ShiftValidationResult validate({
    required int morningCount,
    required int longCount,
    required int nightCount,
  }) {
    final total = morningCount + longCount + nightCount;
    final requiredTotal = requiredDaysForMorning(morningCount);

    // التحقق من أن عدد الصباحي زوجي
    if (!isMorningEven(morningCount)) {
      return ShiftValidationResult(
        isValid: false,
        canSubmit: false,
        message: 'اخترت $morningCount صباحي. يجب اختيار يوم صباحي إضافي ليكونا زوجيين (كل يومين صباحي = شيفت كامل).',
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

    if (nightCount == 0) {
      return ShiftValidationResult(
        isValid: false,
        canSubmit: false,
        message: 'يجب اختيار $minNightIfNoNight يوم ليلي (Night) على الأقل',
        ruleViolation: ShiftRuleViolation.noNight,
      );
    }

    if (nightCount < minNightIfNoNight) {
      return ShiftValidationResult(
        isValid: false,
        canSubmit: false,
        message: 'يجب اختيار $minNightIfNoNight أيام ليلية على الأقل (عندك $nightCount فقط)',
        ruleViolation: ShiftRuleViolation.insufficientNight,
      );
    }

    // لو كل الأيام ليلي
    if (morningCount == 0 && longCount == 0) {
      return ShiftValidationResult(
        isValid: false,
        canSubmit: false,
        message: 'لو كل أيامك ليلي، أضف $minLongIfAllNight طويل أو $minMorningEquivIfAllNight صباحي على الأقل',
        ruleViolation: ShiftRuleViolation.allNightNoLong,
      );
    }

    return ShiftValidationResult(
      isValid: true,
      canSubmit: true,
      message: 'اختياراتك مكتملة ومتوازنة ($total يوم) ✓',
    );
  }

  static String get rulesText =>
      'القواعد: الأساس ١٢ يوم • اليومين الصباحي = يوم طويل (يصبح الإجمالي ١٣ أو ١٤...) • الجروب A (١-١٥) و B (١٦-نهاية الشهر)';
}

enum ShiftRuleViolation {
  noNight,
  insufficientNight,
  allNightNoLong,
  morningNotEven,
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
    // Map shift_type or fallback from preference_type
    final shiftTypeStr = json['shift_type']?.toString();
    final prefTypeStr = json['preference_type']?.toString() ?? 'L';

    PreferenceShiftType shiftType;
    if (shiftTypeStr != null && shiftTypeStr.isNotEmpty) {
      shiftType = PreferenceShiftType.fromString(shiftTypeStr);
    } else {
      // Map 'L' or 'A' or 'B' or 'N' or 'M'
      final p = prefTypeStr.toUpperCase();
      if (p == 'B' || p == 'N') {
        shiftType = PreferenceShiftType.night;
      } else if (p == 'M') {
        shiftType = PreferenceShiftType.morning;
      } else {
        shiftType = PreferenceShiftType.longShift;
      }
    }

    return RosterPreference(
      id: json['id']?.toString() ?? '',
      rosterId: json['roster_id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      preferenceDate: DateTime.parse(json['preference_date']),
      preferenceType: PreferenceType.fromString(prefTypeStr),
      preferenceShiftType: shiftType,
      status: PreferenceStatus.fromString(json['status'] ?? 'draft'),
      submittedAt: json['submitted_at'] != null ? DateTime.tryParse(json['submitted_at']) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roster_id': rosterId,
      'student_id': studentId,
      'preference_date': '${preferenceDate.year.toString().padLeft(4, '0')}-${preferenceDate.month.toString().padLeft(2, '0')}-${preferenceDate.day.toString().padLeft(2, '0')}',
      'preference_type': preferenceShiftType == PreferenceShiftType.night
          ? 'B'
          : preferenceShiftType == PreferenceShiftType.morning
              ? 'M'
              : 'A',
      'shift_type': preferenceShiftType.code,
      'status': status.name,
      'submitted_at': submittedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toSupabasePayload() {
    return {
      'student_id': studentId,
      'roster_id': rosterId,
      'preference_date': '${preferenceDate.year.toString().padLeft(4, '0')}-${preferenceDate.month.toString().padLeft(2, '0')}-${preferenceDate.day.toString().padLeft(2, '0')}',
      'preference_type': preferenceShiftType == PreferenceShiftType.night ? 'B' : 'A',
      'status': status.name,
    };
  }

  RosterPreference copyWith({
    PreferenceType? preferenceType,
    PreferenceShiftType? preferenceShiftType,
    PreferenceStatus? status,
    DateTime? submittedAt,
  }) {
    return RosterPreference(
      id: id,
      rosterId: rosterId,
      studentId: studentId,
      preferenceDate: preferenceDate,
      preferenceType: preferenceType ?? this.preferenceType,
      preferenceShiftType: preferenceShiftType ?? this.preferenceShiftType,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      createdAt: createdAt,
    );
  }
}
