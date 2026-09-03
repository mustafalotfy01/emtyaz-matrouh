// group_monthly_department.dart
// Model for monthly department assignment for student groups

class GroupMonthlyDepartmentModel {
  final String id;
  final String groupId;
  final String departmentId;
  final String departmentName;
  final int year;
  final int month;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const GroupMonthlyDepartmentModel({
    required this.id,
    required this.groupId,
    required this.departmentId,
    required this.departmentName,
    required this.year,
    required this.month,
    this.createdAt,
    this.updatedAt,
  });

  static const List<String> arabicMonths = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  String get monthNameAr {
    if (month >= 1 && month <= 12) {
      return arabicMonths[month - 1];
    }
    return '$month';
  }

  String get formattedMonthYearAr => '$monthNameAr $year';

  factory GroupMonthlyDepartmentModel.fromJson(Map<String, dynamic> json) {
    return GroupMonthlyDepartmentModel(
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      departmentId: json['department_id']?.toString() ?? '',
      departmentName: json['department_name']?.toString() ?? json['departments']?['name_ar']?.toString() ?? 'غير مخصص',
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      month: (json['month'] as num?)?.toInt() ?? DateTime.now().month,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'group_id': groupId,
      'department_id': departmentId,
      'year': year,
      'month': month,
    };
  }
}
