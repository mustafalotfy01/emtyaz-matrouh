enum DisciplinaryActionType {
  warning, // تنبيه
  finalWarning, // إنذار
  officialViolation, // مخالفة رسمية
  deduction, // خصم
  absence, // غياب
  unexcusedAbsence, // غياب بدون إذن
  lateCheckin, // تأخير
  earlyLeave, // انصراف مبكر
  attendanceViolation, // مخالفة حضور
  behavioralViolation, // مخالفة سلوكية
  reward; // مكافأة

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

  bool get isReward => this == DisciplinaryActionType.reward;

  static DisciplinaryActionType fromString(String val) {
    switch (val) {
      case 'warning':
        return DisciplinaryActionType.warning;
      case 'final_warning':
        return DisciplinaryActionType.finalWarning;
      case 'official_violation':
        return DisciplinaryActionType.officialViolation;
      case 'deduction':
        return DisciplinaryActionType.deduction;
      case 'absence':
        return DisciplinaryActionType.absence;
      case 'unexcused_absence':
        return DisciplinaryActionType.unexcusedAbsence;
      case 'late_checkin':
        return DisciplinaryActionType.lateCheckin;
      case 'early_leave':
        return DisciplinaryActionType.earlyLeave;
      case 'attendance_violation':
        return DisciplinaryActionType.attendanceViolation;
      case 'behavioral_violation':
        return DisciplinaryActionType.behavioralViolation;
      case 'reward':
        return DisciplinaryActionType.reward;
      default:
        return DisciplinaryActionType.warning;
    }
  }

  String toDbString() {
    switch (this) {
      case DisciplinaryActionType.warning:
        return 'warning';
      case DisciplinaryActionType.finalWarning:
        return 'final_warning';
      case DisciplinaryActionType.officialViolation:
        return 'official_violation';
      case DisciplinaryActionType.deduction:
        return 'deduction';
      case DisciplinaryActionType.absence:
        return 'absence';
      case DisciplinaryActionType.unexcusedAbsence:
        return 'unexcused_absence';
      case DisciplinaryActionType.lateCheckin:
        return 'late_checkin';
      case DisciplinaryActionType.earlyLeave:
        return 'early_leave';
      case DisciplinaryActionType.attendanceViolation:
        return 'attendance_violation';
      case DisciplinaryActionType.behavioralViolation:
        return 'behavioral_violation';
      case DisciplinaryActionType.reward:
        return 'reward';
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
        return 'قيد الاعتماد ⏳';
      case ActionStatus.approved:
        return 'معتمد رسميًا ✅';
      case ActionStatus.rejected:
        return 'مرفوض ❌';
      case ActionStatus.cancelled:
        return 'ملغى 🚫';
      case ActionStatus.appealed:
        return 'قيد التظلم ⚖️';
      case ActionStatus.resolved:
        return 'تمت التسوية 🤝';
    }
  }

  static ActionStatus fromString(String val) {
    switch (val) {
      case 'approved':
        return ActionStatus.approved;
      case 'rejected':
        return ActionStatus.rejected;
      case 'cancelled':
        return ActionStatus.cancelled;
      case 'appealed':
        return ActionStatus.appealed;
      case 'resolved':
        return ActionStatus.resolved;
      case 'pending':
      default:
        return ActionStatus.pending;
    }
  }

  String toDbString() => name;
}

class DisciplinaryAction {
  final String id;
  final String studentId;
  final String studentName;
  final String? studentCode;
  final String? studentAvatarUrl;
  final String createdById;
  final String createdByName;
  final String createdByRole;
  final String? approvedById;
  final String? approvedByName;
  final String departmentName;
  final DisciplinaryActionType actionType;
  final int severity;
  final String reason;
  final String description;
  final double deductionValue;
  final String deductionUnit; // 'points', 'marks', 'shifts'
  final ActionStatus status;
  final String? adminNote;
  final String? reviewComment;
  final DateTime actionDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DisciplinaryAction({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.studentCode,
    this.studentAvatarUrl,
    required this.createdById,
    required this.createdByName,
    this.createdByRole = 'evaluating_doctor',
    this.approvedById,
    this.approvedByName,
    required this.departmentName,
    required this.actionType,
    this.severity = 1,
    required this.reason,
    required this.description,
    this.deductionValue = 0.0,
    this.deductionUnit = 'points',
    this.status = ActionStatus.approved,
    this.adminNote,
    this.reviewComment,
    required this.actionDate,
    this.createdAt,
    this.updatedAt,
  });

  bool get isDirectAdminAction => createdByRole == 'super_admin';

  factory DisciplinaryAction.fromJson(Map<String, dynamic> json) {
    // Extract nested profiles if joined
    String sName = 'طالب';
    String? sCode;
    String? sAvatar;
    if (json['student'] != null && json['student'] is Map<String, dynamic>) {
      sName = json['student']['full_name'] ?? 'طالب';
      sCode = json['student']['university_code'];
      sAvatar = json['student']['avatar_url'];
    }

    String cName = 'دكتور مقيّم';
    if (json['creator'] != null && json['creator'] is Map<String, dynamic>) {
      cName = json['creator']['full_name'] ?? 'دكتور مقيّم';
    }

    String? aName;
    if (json['approver'] != null && json['approver'] is Map<String, dynamic>) {
      aName = json['approver']['full_name'];
    }

    String deptName = 'مستشفى مطروح العام';
    if (json['department'] != null && json['department'] is Map<String, dynamic>) {
      deptName = json['department']['name_ar'] ?? deptName;
    }

    return DisciplinaryAction(
      id: json['id'] ?? '',
      studentId: json['student_id'] ?? '',
      studentName: json['student_name'] ?? sName,
      studentCode: json['student_code'] ?? sCode,
      studentAvatarUrl: json['student_avatar_url'] ?? sAvatar,
      createdById: json['created_by'] ?? '',
      createdByName: json['created_by_name'] ?? cName,
      createdByRole: json['created_by_role'] ?? 'evaluating_doctor',
      approvedById: json['approved_by'],
      approvedByName: json['approved_by_name'] ?? aName,
      departmentName: json['department_name'] ?? deptName,
      actionType: DisciplinaryActionType.fromString(json['action_type'] ?? 'warning'),
      severity: json['severity'] ?? 1,
      reason: json['reason'] ?? '',
      description: json['description'] ?? '',
      deductionValue: (json['deduction_value'] as num?)?.toDouble() ?? 0.0,
      deductionUnit: json['deduction_unit'] ?? 'points',
      status: ActionStatus.fromString(json['status'] ?? 'pending'),
      adminNote: json['admin_note'],
      reviewComment: json['review_comment'],
      actionDate: json['action_date'] != null
          ? DateTime.tryParse(json['action_date']) ?? DateTime.now()
          : DateTime.now(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'created_by': createdById,
      'created_by_role': createdByRole,
      'approved_by': approvedById,
      'action_type': actionType.toDbString(),
      'severity': severity,
      'reason': reason,
      'description': description,
      'deduction_value': deductionValue,
      'deduction_unit': deductionUnit,
      'status': status.toDbString(),
      'admin_note': adminNote,
      'review_comment': reviewComment,
      'action_date': actionDate.toIso8601String().split('T')[0],
    };
  }

  DisciplinaryAction copyWith({
    ActionStatus? status,
    String? approvedById,
    String? approvedByName,
    String? adminNote,
    String? reviewComment,
  }) {
    return DisciplinaryAction(
      id: id,
      studentId: studentId,
      studentName: studentName,
      studentCode: studentCode,
      studentAvatarUrl: studentAvatarUrl,
      createdById: createdById,
      createdByName: createdByName,
      createdByRole: createdByRole,
      approvedById: approvedById ?? this.approvedById,
      approvedByName: approvedByName ?? this.approvedByName,
      departmentName: departmentName,
      actionType: actionType,
      severity: severity,
      reason: reason,
      description: description,
      deductionValue: deductionValue,
      deductionUnit: deductionUnit,
      status: status ?? this.status,
      adminNote: adminNote ?? this.adminNote,
      reviewComment: reviewComment ?? this.reviewComment,
      actionDate: actionDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
