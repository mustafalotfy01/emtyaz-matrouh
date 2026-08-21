class Department {
  final String id;
  final String nameAr;
  final String nameEn;
  final String description;
  final int capacity;

  Department({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.description,
    this.capacity = 20,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id']?.toString() ?? '',
      nameAr: json['name_ar'] ?? '',
      nameEn: json['name_en'] ?? '',
      description: json['description'] ?? '',
      capacity: json['capacity'] is int ? json['capacity'] : 20,
    );
  }

  static List<Department> defaultDepartments() {
    return [
      Department(
        id: 'a0000001-0000-0000-0000-000000000001',
        nameAr: 'قسم الطوارئ',
        nameEn: 'Emergency Department',
        description: 'استقبال وحالات الطوارئ الحرجة والرعاية السريعة',
        capacity: 30,
      ),
      Department(
        id: 'a0000001-0000-0000-0000-000000000002',
        nameAr: 'عناية جراحة',
        nameEn: 'Surgical ICU',
        description: 'رعاية ما بعد الجراحات الحرجة',
        capacity: 15,
      ),
      Department(
        id: 'a0000001-0000-0000-0000-000000000003',
        nameAr: 'عناية باطنة',
        nameEn: 'Medical ICU',
        description: 'عناية فائقة للأمراض الباطنية الحرجة',
        capacity: 15,
      ),
      Department(
        id: 'a0000001-0000-0000-0000-000000000004',
        nameAr: 'حضانة الأطفال (NICU)',
        nameEn: 'Neonatal ICU',
        description: 'رعاية حديثي الولادة والمبتسرين',
        capacity: 20,
      ),
      Department(
        id: 'a0000001-0000-0000-0000-000000000005',
        nameAr: 'عناية القلب (CCU)',
        nameEn: 'Cardiac Care Unit',
        description: 'متابعة مرضي الأزمات القلبية والقسطرة',
        capacity: 15,
      ),
      Department(
        id: 'a0000001-0000-0000-0000-000000000006',
        nameAr: 'قسم الغسيل الكلوي',
        nameEn: 'Dialysis Unit',
        description: 'جلسات الغسيل الكلوي الدوري والمستمر',
        capacity: 25,
      ),
    ];
  }
}
