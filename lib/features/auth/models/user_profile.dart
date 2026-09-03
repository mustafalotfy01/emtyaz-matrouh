enum UserRole {
  superAdmin,
  leader,
  evaluatingDoctor,
  student;

  String get displayNameAr {
    switch (this) {
      case UserRole.superAdmin:
        return 'الإدارة العليا';
      case UserRole.leader:
        return 'ليدر';
      case UserRole.evaluatingDoctor:
        return 'دكتور مشرف';
      case UserRole.student:
        return 'طالب امتياز';
    }
  }

  String get displayNameEn {
    switch (this) {
      case UserRole.superAdmin:
        return 'Senior Management';
      case UserRole.leader:
        return 'Leader';
      case UserRole.evaluatingDoctor:
        return 'Supervisor Doctor';
      case UserRole.student:
        return 'Intern Student';
    }
  }

  static UserRole fromString(String roleStr) {
    switch (roleStr) {
      case 'super_admin':
      case 'admin':
        return UserRole.superAdmin;
      case 'leader':
        return UserRole.leader;
      case 'evaluating_doctor':
      case 'doctor':
        return UserRole.evaluatingDoctor;
      case 'student':
      default:
        return UserRole.student;
    }
  }

  String toDbString() {
    switch (this) {
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.leader:
        return 'leader';
      case UserRole.evaluatingDoctor:
        return 'evaluating_doctor';
      case UserRole.student:
        return 'student';
    }
  }
}

enum StudentClassification {
  practicalStrong,
  theoreticalStrong,
  weak;

  String get displayNameAr {
    switch (this) {
      case StudentClassification.practicalStrong:
        return 'شاطر عملي 🩺';
      case StudentClassification.theoreticalStrong:
        return 'دحيح نظري 📚';
      case StudentClassification.weak:
        return 'ضعيف ⚠️';
    }
  }

  String get code {
    switch (this) {
      case StudentClassification.practicalStrong:
        return 'practical_strong';
      case StudentClassification.theoreticalStrong:
        return 'theoretical_strong';
      case StudentClassification.weak:
        return 'weak';
    }
  }

  static StudentClassification? fromString(String? val) {
    if (val == null) return null;
    final cleaned = val.toLowerCase().trim();
    if (cleaned == 'practical_strong' || cleaned == 'practicalstrong') {
      return StudentClassification.practicalStrong;
    }
    if (cleaned == 'theoretical_strong' || cleaned == 'theoreticalstrong') {
      return StudentClassification.theoreticalStrong;
    }
    if (cleaned == 'weak') {
      return StudentClassification.weak;
    }
    return null;
  }

  String toDbString() => code;
}

enum StudentGroup {
  unassigned;

  String get displayNameAr => 'بدون جروب';
  String get code => '';

  static StudentGroup fromString(String? val) => StudentGroup.unassigned;
}

enum RegistrationStatus {
  pending,
  approved,
  rejected,
  suspended;

  String get displayNameAr {
    switch (this) {
      case RegistrationStatus.pending:
        return 'قيد المراجعة ⏳';
      case RegistrationStatus.approved:
        return 'معتمد رسميًا ✅';
      case RegistrationStatus.rejected:
        return 'مرفوض ❌';
      case RegistrationStatus.suspended:
        return 'موقوف مؤقتًا 🚫';
    }
  }

  static RegistrationStatus fromString(String statusStr) {
    switch (statusStr) {
      case 'approved':
        return RegistrationStatus.approved;
      case 'rejected':
        return RegistrationStatus.rejected;
      case 'suspended':
        return RegistrationStatus.suspended;
      case 'pending':
      default:
        return RegistrationStatus.pending;
    }
  }

  String toDbString() {
    return name;
  }
}

class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String universityCode;
  final String phoneNumber;
  final String? nationalId;
  final double? gpa;
  final String gender;
  final String maritalStatus;
  final int childrenCount;
  final bool isMatrouhResident;
  final String emergencyContact;
  final String residenceAddress;
  final double? latitude;
  final double? longitude;
  final String? avatarUrl;
  final UserRole role;
  final StudentGroup studentGroup;
  final RegistrationStatus registrationStatus;
  final String? reviewedBy;
  final String? rejectionReason;
  final DateTime? reviewedAt;
  final DateTime? createdAt;
  final StudentClassification? classification;
  final String? studentGroupId;
  final String? studentGroupName;
  final String? departmentName;
  final String? supervisorDoctorName;
  final bool previousWorkExperience;
  final String? previousWorkplace;
  final String? previousWorkDepartment;
  final String? previousWorkExperienceDetails;

  UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.universityCode,
    required this.phoneNumber,
    this.nationalId,
    this.gpa,
    required this.gender,
    required this.maritalStatus,
    required this.childrenCount,
    required this.isMatrouhResident,
    required this.emergencyContact,
    required this.residenceAddress,
    this.latitude,
    this.longitude,
    this.avatarUrl,
    required this.role,
    this.studentGroup = StudentGroup.unassigned,
    this.registrationStatus = RegistrationStatus.pending,
    this.reviewedBy,
    this.rejectionReason,
    this.reviewedAt,
    this.createdAt,
    this.classification,
    this.studentGroupId,
    this.studentGroupName,
    this.departmentName,
    this.supervisorDoctorName,
    this.previousWorkExperience = false,
    this.previousWorkplace,
    this.previousWorkDepartment,
    this.previousWorkExperienceDetails,
  });

  bool get isApproved => registrationStatus == RegistrationStatus.approved;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Extract GPA from either top-level, raw_user_meta_data, or user_metadata
    double? parsedGpa;
    if (json['gpa'] != null) {
      parsedGpa = (json['gpa'] as num).toDouble();
    } else if (json['user_metadata'] is Map && json['user_metadata']['gpa'] != null) {
      final g = json['user_metadata']['gpa'];
      parsedGpa = (g is num) ? g.toDouble() : double.tryParse(g.toString());
    } else if (json['raw_user_meta_data'] is Map && json['raw_user_meta_data']['gpa'] != null) {
      final g = json['raw_user_meta_data']['gpa'];
      parsedGpa = (g is num) ? g.toDouble() : double.tryParse(g.toString());
    }

    final rawClass = json['student_classification'] ?? json['classification'];
    final parsedClass = StudentClassification.fromString(rawClass?.toString());

    final prevExp = json['previous_work_experience'] == true ||
        (json['raw_user_meta_data'] is Map && json['raw_user_meta_data']['previous_work_experience'] == true);

    return UserProfile(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? 'مستخدم',
      universityCode: json['university_code'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      nationalId: json['national_id'],
      gpa: parsedGpa,
      gender: json['gender'] ?? 'male',
      maritalStatus: json['marital_status'] ?? 'أعزب/عزباء',
      childrenCount: json['children_count'] ?? 0,
      isMatrouhResident: json['is_matrouh_resident'] ?? true,
      emergencyContact: json['emergency_contact'] ?? '',
      residenceAddress: json['residence_address'] ?? '',
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
      role: UserRole.fromString(json['role'] ?? 'student'),
      studentGroup: StudentGroup.fromString(json['student_group'] ?? json['group']),
      registrationStatus: RegistrationStatus.fromString(json['registration_status'] ?? 'pending'),
      reviewedBy: json['reviewed_by'],
      rejectionReason: json['rejection_reason'],
      reviewedAt: json['reviewed_at'] != null ? DateTime.tryParse(json['reviewed_at']) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      classification: parsedClass,
      studentGroupId: json['student_group_id']?.toString(),
      studentGroupName: () {
        final raw = json['group_name']?.toString() ?? json['student_group_name']?.toString();
        if (raw != null && raw.trim().isNotEmpty && raw != 'A' && raw != 'B' && raw != 'group_a' && raw != 'group_b' && raw != 'Group A' && raw != 'Group B' && raw != 'المجموعة A' && raw != 'المجموعة B') {
          return raw.trim();
        }
        final leg = json['student_group']?.toString();
        if (leg != null && leg.trim().isNotEmpty && leg != 'A' && leg != 'B' && leg != 'group_a' && leg != 'group_b' && leg != 'Group A' && leg != 'Group B' && leg != 'المجموعة A' && leg != 'المجموعة B') {
          return leg.trim();
        }
        return null;
      }(),
      departmentName: json['department_name']?.toString(),
      supervisorDoctorName: json['supervisor_doctor_name']?.toString(),
      previousWorkExperience: prevExp,
      previousWorkplace: json['previous_workplace']?.toString() ??
          (json['raw_user_meta_data'] is Map ? json['raw_user_meta_data']['previous_workplace']?.toString() : null),
      previousWorkDepartment: json['previous_work_department']?.toString() ??
          (json['raw_user_meta_data'] is Map ? json['raw_user_meta_data']['previous_work_department']?.toString() : null),
      previousWorkExperienceDetails: json['previous_work_experience_details']?.toString() ??
          (json['raw_user_meta_data'] is Map ? json['raw_user_meta_data']['previous_work_experience_details']?.toString() : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'university_code': universityCode,
      'phone_number': phoneNumber,
      'national_id': nationalId,
      'gpa': gpa,
      'gender': gender,
      'marital_status': maritalStatus,
      'children_count': childrenCount,
      'is_matrouh_resident': isMatrouhResident,
      'emergency_contact': emergencyContact,
      'residence_address': residenceAddress,
      'latitude': latitude,
      'longitude': longitude,
      'avatar_url': avatarUrl,
      'role': role.toDbString(),
      'student_group': studentGroupName,
      'registration_status': registrationStatus.toDbString(),
      'reviewed_by': reviewedBy,
      'rejection_reason': rejectionReason,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'student_classification': classification?.code,
      'student_group_id': studentGroupId,
      'group_name': studentGroupName,
      'department_name': departmentName,
      'supervisor_doctor_name': supervisorDoctorName,
      'previous_work_experience': previousWorkExperience,
      'previous_workplace': previousWorkplace,
      'previous_work_department': previousWorkDepartment,
      'previous_work_experience_details': previousWorkExperienceDetails,
    };
  }

  Map<String, dynamic> toDbJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'university_code': universityCode,
      'phone_number': phoneNumber,
      'national_id': nationalId,
      'gpa': gpa,
      'latitude': latitude,
      'longitude': longitude,
      'gender': gender,
      'marital_status': maritalStatus,
      'children_count': childrenCount,
      'is_matrouh_resident': isMatrouhResident,
      'emergency_contact': emergencyContact,
      'residence_address': residenceAddress,
      'avatar_url': avatarUrl,
      'role': role.toDbString(),
      'student_group': studentGroupName ?? studentGroup.code,
      'is_approved': isApproved,
      'registration_status': registrationStatus.toDbString(),
      'reviewed_by': reviewedBy,
      'rejection_reason': rejectionReason,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'student_classification': classification?.code,
      'student_group_id': studentGroupId,
      'previous_work_experience': previousWorkExperience,
      'previous_workplace': previousWorkplace,
      'previous_work_department': previousWorkDepartment,
      'previous_work_experience_details': previousWorkExperienceDetails,
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? universityCode,
    String? phoneNumber,
    String? nationalId,
    double? gpa,
    String? gender,
    String? maritalStatus,
    int? childrenCount,
    bool? isMatrouhResident,
    String? emergencyContact,
    String? residenceAddress,
    double? latitude,
    double? longitude,
    String? avatarUrl,
    UserRole? role,
    StudentGroup? studentGroup,
    RegistrationStatus? registrationStatus,
    String? reviewedBy,
    String? rejectionReason,
    DateTime? reviewedAt,
    DateTime? createdAt,
    StudentClassification? classification,
    String? studentGroupId,
    String? studentGroupName,
    String? departmentName,
    String? supervisorDoctorName,
    bool? previousWorkExperience,
    String? previousWorkplace,
    String? previousWorkDepartment,
    String? previousWorkExperienceDetails,
    bool clearGroup = false,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      universityCode: universityCode ?? this.universityCode,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      nationalId: nationalId ?? this.nationalId,
      gpa: gpa ?? this.gpa,
      gender: gender ?? this.gender,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      childrenCount: childrenCount ?? this.childrenCount,
      isMatrouhResident: isMatrouhResident ?? this.isMatrouhResident,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      residenceAddress: residenceAddress ?? this.residenceAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      studentGroup: studentGroup ?? this.studentGroup,
      registrationStatus: registrationStatus ?? this.registrationStatus,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt ?? this.createdAt,
      classification: classification ?? this.classification,
      studentGroupId: clearGroup ? null : (studentGroupId ?? this.studentGroupId),
      studentGroupName: clearGroup ? null : (studentGroupName ?? this.studentGroupName),
      departmentName: departmentName ?? this.departmentName,
      supervisorDoctorName: supervisorDoctorName ?? this.supervisorDoctorName,
      previousWorkExperience: previousWorkExperience ?? this.previousWorkExperience,
      previousWorkplace: (previousWorkExperience == false)
          ? null
          : (previousWorkplace ?? this.previousWorkplace),
      previousWorkDepartment: (previousWorkExperience == false)
          ? null
          : (previousWorkDepartment ?? this.previousWorkDepartment),
      previousWorkExperienceDetails: (previousWorkExperience == false)
          ? null
          : (previousWorkExperienceDetails ?? this.previousWorkExperienceDetails),
    );
  }

  static UserProfile mockStudent() {
    return UserProfile(
      id: 'student-001',
      email: 'ahmed.student@matrouh.edu.eg',
      fullName: 'أحمد محمود العبد',
      universityCode: 'NUR-2026-081',
      phoneNumber: '01012345678',
      nationalId: '30105151201991',
      gender: 'male',
      maritalStatus: 'أعزب',
      childrenCount: 0,
      isMatrouhResident: true,
      emergencyContact: '01099887766 (الأب)',
      residenceAddress: 'مرسى مطروح - شارع اسكندرية',
      latitude: 31.3520,
      longitude: 27.2410,
      role: UserRole.student,
      registrationStatus: RegistrationStatus.approved,
    );
  }

  static UserProfile mockLeader() {
    return UserProfile(
      id: 'leader-001',
      email: 'mona.leader@matrouh.edu.eg',
      fullName: 'د. منى عبد السلام (منسق الجدولة)',
      universityCode: 'COORD-001',
      phoneNumber: '01222334455',
      gender: 'female',
      maritalStatus: 'متزوجة',
      childrenCount: 2,
      isMatrouhResident: true,
      emergencyContact: '01222334456',
      residenceAddress: 'مرسى مطروح',
      latitude: 31.3550,
      longitude: 27.2350,
      role: UserRole.leader,
      registrationStatus: RegistrationStatus.approved,
    );
  }

  static UserProfile mockDoctor() {
    return UserProfile(
      id: 'doctor-001',
      email: 'dr.tarek@matrouh.edu.eg',
      fullName: 'د. طارق السويفي (استشاري العناية)',
      universityCode: 'DOC-044',
      phoneNumber: '01111223344',
      gender: 'male',
      maritalStatus: 'متزوج',
      childrenCount: 3,
      isMatrouhResident: true,
      emergencyContact: '01111223345',
      residenceAddress: 'مستشفى مطروح العام',
      latitude: 31.3543,
      longitude: 27.2373,
      role: UserRole.evaluatingDoctor,
      registrationStatus: RegistrationStatus.approved,
    );
  }

  static UserProfile mockAdmin() {
    return UserProfile(
      id: 'admin-001',
      email: 'admin@matrouh.edu.eg',
      fullName: 'أ.د. عميد الكلية / الإدارة',
      universityCode: 'ADM-001',
      phoneNumber: '01500000000',
      gender: 'male',
      maritalStatus: 'متزوج',
      childrenCount: 2,
      isMatrouhResident: true,
      emergencyContact: '01500000001',
      residenceAddress: 'جامعة مطروح',
      latitude: 31.3580,
      longitude: 27.2320,
      role: UserRole.superAdmin,
      registrationStatus: RegistrationStatus.approved,
    );
  }
}
