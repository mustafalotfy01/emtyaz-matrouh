enum DisciplinaryActionType {
  warning,           // تنبيه
  finalWarning,      // إنذار
  officialViolation, // مخالفة رسمية
  deduction,         // خصم
  absence,           // غياب
  unexcusedAbsence,  // غياب بدون إذن
  lateCheckin,       // تأخير
  earlyLeave,        // انصراف مبكر
  attendanceViolation,// مخالفة حضور
  behavioralViolation,// مخالفة سلوكية
  reward;            // مكافأة

  String get displayNameAr {
    switch (this) {
      case DisciplinaryActionType.warning:
        return 'تنبيه شفهي ⚠️';
      case DisciplinaryActionType.finalWarning:
        return 'إنذار رسمي 🚨';
      case DisciplinaryActionType.officialViolation:
        return 'مخالفة رسمية 📜';
      case DisciplinaryActionType.deduction:
        return 'خصم شيفت/نقاط ❌';
      case DisciplinaryActionType.absence:
        return 'تسجيل غياب 🔴';
      case DisciplinaryActionType.unexcusedAbsence:
        return 'غياب بدون إذن 🔴';
      case DisciplinaryActionType.lateCheckin:
        return 'تأخير حضور 🟠';
      case DisciplinaryActionType.earlyLeave:
        return 'انصراف مبكر 🟠';
      case DisciplinaryActionType.attendanceViolation:
        return 'مخالفة حضور 📍';
      case DisciplinaryActionType.behavioralViolation:
        return 'مخالفة سلوكية 🚫';
      case DisciplinaryActionType.reward:
        return 'مكافأة تميز 🌟';
    }
  }
}

enum ActionStatus {
  pending,
  approved,
  rejected,
  cancelled,
  appealed,
  resolved;

  String get displayNameAr {
    switch (this) {
      case ActionStatus.pending:
        return 'قيد الاعتماد';
      case ActionStatus.approved:
        return 'معتمد رسميًا';
      case ActionStatus.rejected:
        return 'مرفوض';
      case ActionStatus.cancelled:
        return 'ملغى';
      case ActionStatus.appealed:
        return 'قيد التظلم';
      case ActionStatus.resolved:
        return 'تمت التسوية';
    }
  }
}

class DisciplinaryAction {
  final String id;
  final String studentId;
  final String studentName;
  final String createdByName;
  final String departmentName;
  final DisciplinaryActionType actionType;
  final int severity;
  final String reason;
  final String description;
  final double deductionValue;
  final String deductionUnit; // 'points', 'marks', 'shifts'
  final ActionStatus status;
  final DateTime actionDate;

  DisciplinaryAction({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.createdByName,
    required this.departmentName,
    required this.actionType,
    this.severity = 1,
    required this.reason,
    required this.description,
    this.deductionValue = 0.0,
    this.deductionUnit = 'points',
    this.status = ActionStatus.approved,
    required this.actionDate,
  });

  DisciplinaryAction copyWith({
    ActionStatus? status,
  }) {
    return DisciplinaryAction(
      id: id,
      studentId: studentId,
      studentName: studentName,
      createdByName: createdByName,
      departmentName: departmentName,
      actionType: actionType,
      severity: severity,
      reason: reason,
      description: description,
      deductionValue: deductionValue,
      deductionUnit: deductionUnit,
      status: status ?? this.status,
      actionDate: actionDate,
    );
  }

  static List<DisciplinaryAction> sampleActions() {
    return [];
  }
}
