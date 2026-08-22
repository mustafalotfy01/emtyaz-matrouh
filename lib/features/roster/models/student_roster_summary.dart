import '../../auth/models/user_profile.dart';
import 'roster_entry.dart';
import 'roster_preference.dart';

enum FairnessLevel {
  fair,
  needsReview,
  unbalanced;

  String get displayNameAr {
    switch (this) {
      case FairnessLevel.fair:
        return 'توزيع متوازن 🟢';
      case FairnessLevel.needsReview:
        return 'يحتاج مراجعة طفيفة 🟡';
      case FairnessLevel.unbalanced:
        return 'غير متوازن 🔴';
    }
  }

  String get badgeLabel {
    switch (this) {
      case FairnessLevel.fair:
        return '🟢 متوازن';
      case FairnessLevel.needsReview:
        return '🟡 مراجعة';
      case FairnessLevel.unbalanced:
        return '🔴 غير متوازن';
    }
  }
}

class StudentHistoricalStats {
  final int prevMonthNightCount;
  final int prevMonthLongCount;
  final int yearlyNightCount;
  final int yearlyLongCount;

  const StudentHistoricalStats({
    this.prevMonthNightCount = 0,
    this.prevMonthLongCount = 0,
    this.yearlyNightCount = 0,
    this.yearlyLongCount = 0,
  });
}

class StudentRosterSummary {
  final String studentId;
  final String studentName;
  final String? avatarUrl;
  final StudentGroup studentGroup;
  final List<RosterPreference> preferences;
  final List<RosterEntry> assignedShifts;
  final PreferenceStatus submissionStatus;
  final StudentHistoricalStats historicalStats;

  StudentRosterSummary({
    required this.studentId,
    required this.studentName,
    this.avatarUrl,
    required this.studentGroup,
    required this.preferences,
    required this.assignedShifts,
    this.submissionStatus = PreferenceStatus.draft,
    this.historicalStats = const StudentHistoricalStats(),
  });

  // Selected Preferences counts
  int get prefMorningCount =>
      preferences.where((p) => p.preferenceShiftType == PreferenceShiftType.morning).length;

  int get prefLongCount =>
      preferences.where((p) => p.preferenceShiftType == PreferenceShiftType.longShift).length;

  int get prefNightCount =>
      preferences.where((p) => p.preferenceShiftType == PreferenceShiftType.night).length;

  int get totalPrefCount => preferences.length;

  bool get isPrefComplete =>
      totalPrefCount == ShiftRulesHelper.requiredDays &&
      ShiftRulesHelper.validate(
        morningCount: prefMorningCount,
        longCount: prefLongCount,
        nightCount: prefNightCount,
      ).canSubmit;

  // Final Assigned Shifts counts
  int get finalNightCount =>
      assignedShifts.where((s) => s.shiftType == ShiftType.night).length;

  int get finalLongCount =>
      assignedShifts.where((s) => s.shiftType == ShiftType.long).length;

  int get finalMorningCount =>
      assignedShifts.where((s) => s.shiftType == ShiftType.morning).length;

  int get finalEveningCount =>
      assignedShifts.where((s) => s.shiftType == ShiftType.evening).length;

  int get totalFinalShifts => assignedShifts.length;

  bool get isSubmitted => submissionStatus == PreferenceStatus.submitted || submissionStatus == PreferenceStatus.locked;
  bool get isDraft => submissionStatus == PreferenceStatus.draft;

  bool get isFinalQuotaComplete => totalFinalShifts == ShiftRulesHelper.requiredDays;
  bool get meetsMinNight => finalNightCount >= ShiftRulesHelper.minNightIfNoNight;

  bool get isReadyForApproval => isFinalQuotaComplete && meetsMinNight;

  // Fairness Evaluation
  FairnessLevel get fairnessLevel {
    if (totalFinalShifts == 0) return FairnessLevel.fair;

    // Check if meets minimum night shifts
    if (totalFinalShifts >= ShiftRulesHelper.requiredDays && !meetsMinNight) {
      return FairnessLevel.needsReview;
    }

    // Heavy night load
    if (finalNightCount > 6) {
      return FairnessLevel.unbalanced;
    }

    return FairnessLevel.fair;
  }

  String get fairnessExplanation {
    switch (fairnessLevel) {
      case FairnessLevel.fair:
        return 'التوزيع مكتمل ومتوازن (سهر: $finalNightCount، طويل: $finalLongCount، صباحي: $finalMorningCount).';
      case FairnessLevel.needsReview:
        return 'يحتاج إضافة شيفتات ليلية لتلبية الحد الأدنى (المعين حالياً: $finalNightCount ليلي).';
      case FairnessLevel.unbalanced:
        return 'عبء شيفتات ليلية ثقيلة ($finalNightCount سهر). يفضل إعادة موازنتها مع باقي الطلاب.';
    }
  }
}
