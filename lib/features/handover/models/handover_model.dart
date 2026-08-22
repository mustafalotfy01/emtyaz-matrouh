enum HandoverStatus {
  pending,
  accepted,
  rejected;

  String get displayNameAr {
    switch (this) {
      case HandoverStatus.pending:
        return 'بانتظار قبول المستلم ⏳';
      case HandoverStatus.accepted:
        return 'تم قبول الاستلام ✅';
      case HandoverStatus.rejected:
        return 'تم رفض الاستلام ❌';
    }
  }

  static HandoverStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'accepted':
      case 'completed':
        return HandoverStatus.accepted;
      case 'rejected':
        return HandoverStatus.rejected;
      case 'pending':
      default:
        return HandoverStatus.pending;
    }
  }

  String toDbString() {
    switch (this) {
      case HandoverStatus.accepted:
        return 'accepted';
      case HandoverStatus.rejected:
        return 'rejected';
      case HandoverStatus.pending:
        return 'pending';
    }
  }
}

class HandoverModel {
  final String id;
  final String fromStudentId;
  final String fromStudentName;
  final String? fromStudentAvatar;
  final String toStudentId;
  final String toStudentName;
  final String? toStudentAvatar;
  final String departmentName;
  final String caseTitle;
  final String shiftName;
  final String currentCondition;
  final String proceduresDone;
  final String pendingTasks;
  final String criticalNotes;
  final HandoverStatus status;
  final DateTime? acceptedAt;
  final DateTime? rejectedAt;
  final String? rejectionReason;
  final List<String> imageUrls;
  final double? doctorScore;
  final String? doctorComment;
  final String? evaluatedBy;
  final String? evaluatorDoctorName;
  final DateTime? evaluatedAt;
  final DateTime createdAt;

  HandoverModel({
    required this.id,
    required this.fromStudentId,
    required this.fromStudentName,
    this.fromStudentAvatar,
    required this.toStudentId,
    required this.toStudentName,
    this.toStudentAvatar,
    required this.departmentName,
    required this.caseTitle,
    this.shiftName = 'شيفت سريري',
    required this.currentCondition,
    this.proceduresDone = '',
    required this.pendingTasks,
    required this.criticalNotes,
    this.status = HandoverStatus.pending,
    this.acceptedAt,
    this.rejectedAt,
    this.rejectionReason,
    this.imageUrls = const [],
    this.doctorScore,
    this.doctorComment,
    this.evaluatedBy,
    this.evaluatorDoctorName,
    this.evaluatedAt,
    required this.createdAt,
  });

  factory HandoverModel.fromJson(Map<String, dynamic> json) {
    String fromName = 'طالب امتياز (المسلم)';
    String? fromAvatar;
    if (json['from_profile'] != null) {
      fromName = json['from_profile']['full_name']?.toString() ?? fromName;
      fromAvatar = json['from_profile']['avatar_url']?.toString();
    }

    String toName = 'طالب امتياز (المستلم)';
    String? toAvatar;
    if (json['to_profile'] != null) {
      toName = json['to_profile']['full_name']?.toString() ?? toName;
      toAvatar = json['to_profile']['avatar_url']?.toString();
    }

    String? docName;
    if (json['evaluator_profile'] != null) {
      docName = json['evaluator_profile']['full_name']?.toString();
    }

    List<String> images = [];
    if (json['image_urls'] is List) {
      images = (json['image_urls'] as List).map((e) => e.toString()).toList();
    }

    return HandoverModel(
      id: json['id']?.toString() ?? '',
      fromStudentId: json['from_student_id']?.toString() ?? '',
      fromStudentName: fromName,
      fromStudentAvatar: fromAvatar,
      toStudentId: json['to_student_id']?.toString() ?? '',
      toStudentName: toName,
      toStudentAvatar: toAvatar,
      departmentName: json['department_name']?.toString() ?? 'قسم الطوارئ والعناية',
      caseTitle: json['case_title']?.toString() ?? 'حالة سريرية',
      shiftName: json['shift_name']?.toString() ?? 'شيفت سريري',
      currentCondition: json['handover_notes']?.toString() ?? '',
      proceduresDone: json['procedures_done']?.toString() ?? '',
      pendingTasks: json['pending_tasks']?.toString() ?? '',
      criticalNotes: json['critical_notes']?.toString() ?? '',
      status: HandoverStatus.fromString(json['status']?.toString() ?? json['handover_status']?.toString()),
      acceptedAt: json['accepted_at'] != null ? DateTime.parse(json['accepted_at'].toString()) : null,
      rejectedAt: json['rejected_at'] != null ? DateTime.parse(json['rejected_at'].toString()) : null,
      rejectionReason: json['rejection_reason']?.toString(),
      imageUrls: images,
      doctorScore: (json['doctor_score'] as num?)?.toDouble(),
      doctorComment: json['doctor_comment']?.toString(),
      evaluatedBy: json['evaluated_by']?.toString(),
      evaluatorDoctorName: docName,
      evaluatedAt: json['evaluated_at'] != null ? DateTime.parse(json['evaluated_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabasePayload() {
    return {
      'from_student_id': fromStudentId,
      'to_student_id': toStudentId,
      'department_name': departmentName,
      'case_title': caseTitle,
      'shift_name': shiftName,
      'handover_notes': currentCondition,
      'critical_notes': criticalNotes,
      'pending_tasks': pendingTasks,
      'status': status.toDbString(),
      if (imageUrls.isNotEmpty) 'image_urls': imageUrls,
    };
  }
}
