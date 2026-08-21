enum CaseStatus {
  active,
  pendingHandover,
  transferred,
  closed;

  String get displayNameAr {
    switch (this) {
      case CaseStatus.active:
        return 'حالة نشطة';
      case CaseStatus.pendingHandover:
        return 'قيد الاستلام والتسليم';
      case CaseStatus.transferred:
        return 'تم التسليم بنجاح';
      case CaseStatus.closed:
        return 'مغلقة';
    }
  }
}

class ClinicalCase {
  final String id;
  final String caseCode; // Anonymized Case ID e.g. "CASE-2026-0891"
  final String departmentName;
  final String currentStudentId;
  final String currentStudentName;
  final String supervisorDoctorName;
  final String chiefComplaint;
  final String currentCondition;
  final String importantFindings;
  final String proceduresDone;
  final String pendingTasks;
  final CaseStatus status;

  ClinicalCase({
    required this.id,
    required this.caseCode,
    required this.departmentName,
    required this.currentStudentId,
    required this.currentStudentName,
    required this.supervisorDoctorName,
    required this.chiefComplaint,
    required this.currentCondition,
    required this.importantFindings,
    required this.proceduresDone,
    required this.pendingTasks,
    this.status = CaseStatus.active,
  });

  static List<ClinicalCase> defaultCases() {
    return [];
  }
}
