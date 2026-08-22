class Department {
  final String id;
  final String nameAr;
  final String nameEn;
  final String? description;
  final int maleCapacity;
  final int femaleCapacity;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DepartmentSupervisorInfo? supervisor;
  final int currentMale;
  final int currentFemale;

  Department({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.description,
    this.maleCapacity = 0,
    this.femaleCapacity = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.supervisor,
    this.currentMale = 0,
    this.currentFemale = 0,
  });

  int get totalCapacity => maleCapacity + femaleCapacity;
  int get currentTotal => currentMale + currentFemale;
  int get remainingMale => (maleCapacity - currentMale).clamp(0, 999);
  int get remainingFemale => (femaleCapacity - currentFemale).clamp(0, 999);
  int get remainingTotal => (totalCapacity - currentTotal).clamp(0, 999);

  factory Department.fromJson(Map<String, dynamic> json) {
    DepartmentSupervisorInfo? sup;
    if (json['supervisor'] != null && json['supervisor'] is Map<String, dynamic>) {
      sup = DepartmentSupervisorInfo.fromJson(json['supervisor']);
    }

    return Department(
      id: json['id'] ?? '',
      nameAr: json['name_ar'] ?? '',
      nameEn: json['name_en'] ?? '',
      description: json['description'],
      maleCapacity: json['male_capacity'] ?? 0,
      femaleCapacity: json['female_capacity'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      supervisor: sup,
      currentMale: json['current_male'] ?? 0,
      currentFemale: json['current_female'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_ar': nameAr,
      'name_en': nameEn,
      'description': description,
      'male_capacity': maleCapacity,
      'female_capacity': femaleCapacity,
      'is_active': isActive,
    };
  }

  Department copyWith({
    String? id,
    String? nameAr,
    String? nameEn,
    String? description,
    int? maleCapacity,
    int? femaleCapacity,
    bool? isActive,
    DepartmentSupervisorInfo? supervisor,
    int? currentMale,
    int? currentFemale,
  }) {
    return Department(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      description: description ?? this.description,
      maleCapacity: maleCapacity ?? this.maleCapacity,
      femaleCapacity: femaleCapacity ?? this.femaleCapacity,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      supervisor: supervisor ?? this.supervisor,
      currentMale: currentMale ?? this.currentMale,
      currentFemale: currentFemale ?? this.currentFemale,
    );
  }
}

class DepartmentSupervisorInfo {
  final String id;
  final String doctorId;
  final String doctorName;
  final String? doctorAvatarUrl;
  final String? doctorCode;
  final int maleCapacity;
  final int femaleCapacity;
  final bool isActive;
  final String assignmentStatus;
  final DateTime? assignedAt;

  DepartmentSupervisorInfo({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    this.doctorAvatarUrl,
    this.doctorCode,
    this.maleCapacity = 0,
    this.femaleCapacity = 0,
    this.isActive = true,
    this.assignmentStatus = 'approved',
    this.assignedAt,
  });

  factory DepartmentSupervisorInfo.fromJson(Map<String, dynamic> json) {
    return DepartmentSupervisorInfo(
      id: json['id'] ?? '',
      doctorId: json['doctor_id'] ?? '',
      doctorName: json['doctor_name'] ?? 'دكتور مجهول',
      doctorAvatarUrl: json['doctor_avatar_url'],
      doctorCode: json['doctor_code'],
      maleCapacity: json['male_capacity'] ?? 0,
      femaleCapacity: json['female_capacity'] ?? 0,
      isActive: json['is_active'] ?? true,
      assignmentStatus: json['assignment_status'] ?? 'approved',
      assignedAt: json['assigned_at'] != null ? DateTime.tryParse(json['assigned_at']) : null,
    );
  }
}

class DoctorDepartmentDuty {
  final String departmentId;
  final String nameAr;
  final String nameEn;
  final String? description;
  final String supervisorId;
  final int maleCapacity;
  final int femaleCapacity;
  final int totalCapacity;
  final int currentMale;
  final int currentFemale;
  final int currentTotal;
  final int remainingMale;
  final int remainingFemale;
  final int remainingTotal;
  final int evaluationsCount;
  final int pendingHandoversCount;
  final String assignmentStatus;
  final DateTime? assignedAt;

  DoctorDepartmentDuty({
    required this.departmentId,
    required this.nameAr,
    required this.nameEn,
    this.description,
    required this.supervisorId,
    required this.maleCapacity,
    required this.femaleCapacity,
    required this.totalCapacity,
    required this.currentMale,
    required this.currentFemale,
    required this.currentTotal,
    required this.remainingMale,
    required this.remainingFemale,
    required this.remainingTotal,
    required this.evaluationsCount,
    required this.pendingHandoversCount,
    required this.assignmentStatus,
    this.assignedAt,
  });

  factory DoctorDepartmentDuty.fromJson(Map<String, dynamic> json) {
    return DoctorDepartmentDuty(
      departmentId: json['department_id'] ?? '',
      nameAr: json['name_ar'] ?? '',
      nameEn: json['name_en'] ?? '',
      description: json['description'],
      supervisorId: json['supervisor_id'] ?? '',
      maleCapacity: json['male_capacity'] ?? 0,
      femaleCapacity: json['female_capacity'] ?? 0,
      totalCapacity: json['total_capacity'] ?? 0,
      currentMale: json['current_male'] ?? 0,
      currentFemale: json['current_female'] ?? 0,
      currentTotal: json['current_total'] ?? 0,
      remainingMale: json['remaining_male'] ?? 0,
      remainingFemale: json['remaining_female'] ?? 0,
      remainingTotal: json['remaining_total'] ?? 0,
      evaluationsCount: json['evaluations_count'] ?? 0,
      pendingHandoversCount: json['pending_handovers_count'] ?? 0,
      assignmentStatus: json['assignment_status'] ?? 'approved',
      assignedAt: json['assigned_at'] != null ? DateTime.tryParse(json['assigned_at']) : null,
    );
  }
}

class DistributionMatrixRow {
  final String departmentId;
  final String departmentName;
  final String? doctorId;
  final String doctorName;
  final int maleCapacity;
  final int femaleCapacity;
  final int totalCapacity;
  final int currentMale;
  final int currentFemale;
  final int currentTotal;
  final int remainingMale;
  final int remainingFemale;
  final int remainingTotal;
  final String assignmentStatus;

  DistributionMatrixRow({
    required this.departmentId,
    required this.departmentName,
    this.doctorId,
    required this.doctorName,
    required this.maleCapacity,
    required this.femaleCapacity,
    required this.totalCapacity,
    required this.currentMale,
    required this.currentFemale,
    required this.currentTotal,
    required this.remainingMale,
    required this.remainingFemale,
    required this.remainingTotal,
    required this.assignmentStatus,
  });

  factory DistributionMatrixRow.fromJson(Map<String, dynamic> json) {
    return DistributionMatrixRow(
      departmentId: json['department_id'] ?? '',
      departmentName: json['department_name'] ?? '',
      doctorId: json['doctor_id'],
      doctorName: json['doctor_name'] ?? 'لم يتم التعيين',
      maleCapacity: json['male_capacity'] ?? 0,
      femaleCapacity: json['female_capacity'] ?? 0,
      totalCapacity: json['total_capacity'] ?? 0,
      currentMale: json['current_male'] ?? 0,
      currentFemale: json['current_female'] ?? 0,
      currentTotal: json['current_total'] ?? 0,
      remainingMale: json['remaining_male'] ?? 0,
      remainingFemale: json['remaining_female'] ?? 0,
      remainingTotal: json['remaining_total'] ?? 0,
      assignmentStatus: json['assignment_status'] ?? 'approved',
    );
  }
}
