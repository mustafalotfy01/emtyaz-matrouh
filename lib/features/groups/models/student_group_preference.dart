class StudentGroupPreference {
  final String id;
  final String studentId;
  final String preferredStudentId;
  final String preferredStudentName;
  final String? preferredStudentUniversityCode;
  final String? preferredStudentAvatarUrl;
  final int priority;
  final String? notes;
  final DateTime? createdAt;

  StudentGroupPreference({
    required this.id,
    required this.studentId,
    required this.preferredStudentId,
    required this.preferredStudentName,
    this.preferredStudentUniversityCode,
    this.preferredStudentAvatarUrl,
    required this.priority,
    this.notes,
    this.createdAt,
  });

  factory StudentGroupPreference.fromJson(Map<String, dynamic> json) {
    String studentName = 'زميل امتياز';
    String? uniCode;
    String? avatar;

    if (json['preferred_profile'] != null) {
      studentName = json['preferred_profile']['full_name']?.toString() ?? studentName;
      uniCode = json['preferred_profile']['university_code']?.toString();
      avatar = json['preferred_profile']['avatar_url']?.toString();
    } else if (json['profiles'] != null) {
      studentName = json['profiles']['full_name']?.toString() ?? studentName;
      uniCode = json['profiles']['university_code']?.toString();
      avatar = json['profiles']['avatar_url']?.toString();
    }

    return StudentGroupPreference(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      preferredStudentId: json['preferred_student_id']?.toString() ?? '',
      preferredStudentName: studentName,
      preferredStudentUniversityCode: uniCode,
      preferredStudentAvatarUrl: avatar,
      priority: (json['priority'] as num?)?.toInt() ?? 1,
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toSupabasePayload() => {
    'student_id': studentId,
    'preferred_student_id': preferredStudentId,
    'priority': priority,
    if (notes != null) 'notes': notes,
  };
}
