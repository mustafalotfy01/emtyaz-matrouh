class AppStrings {
  AppStrings._();

  static const String appName = 'MANU';
  static const String appSubtitle = 'منظومة إدارة ومتابعة تدريب الامتياز التمريضي';
  
  // Roles
  static const String roleStudent = 'طالب امتياز';
  static const String roleLeader = 'منسق الجدولة والامتياز';
  static const String roleDoctor = 'الدكتور المقيّم';
  static const String roleAdmin = 'الإدارة العليا';

  // Navigation
  static const String navHome = 'الرئيسية';
  static const String navRoster = 'الشيفتات والروستر';
  static const String navAttendance = 'الحضور والانصراف';
  static const String navQuizzes = 'الاختبارات';
  static const String navKnowledge = 'المكتبة التعليمية';
  static const String navCases = 'تسليم الحالات';
  static const String navProfile = 'الملف الشخصي';
  static const String navNotifications = 'التنبيهات';

  // Shift Types
  static const String shiftMorning = 'صباحي (Morning)';
  static const String shiftEvening = 'مسائي (Evening)';
  static const String shiftLong = 'طويل (Long)';
  static const String shiftNight = 'سهر (Night)';
  static const String shiftAbsence = 'غياب';
  static const String shiftLeave = 'إجازة';

  // Departments
  static const String deptEmergency = 'قسم الطوارئ';
  static const String deptSurgicalIcu = 'عناية الجراحة';
  static const String deptInternalIcu = 'عناية الباطنة';
  static const String deptNicu = 'حضانة الأطفال (NICU)';
  static const String deptCardiacIcu = 'عناية القلب (CCU)';
  static const String deptDialysis = 'قسم الغسيل الكلوي';

  // General Statuses
  static const String statusPresent = 'حاضر';
  static const String statusLate = 'متأخر';
  static const String statusAbsent = 'غائب';
  static const String statusEarlyLeave = 'انصراف مبكر';
  static const String statusPending = 'قيد المراجعة';
  static const String statusApproved = 'معتمد';
  static const String statusRejected = 'مرفوض';

  // Emergency
  static const String emergencyAlert = 'تنبيه طوارئ نداء عاجل';
  static const String checkInSuccess = 'تم تسجيل الحضور بنجاح';
  static const String checkOutSuccess = 'تم تسجيل الانصراف بنجاح';
}
