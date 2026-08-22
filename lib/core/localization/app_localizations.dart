import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Centralized Medical & Nursing Application Localizations for Arabic & English
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('ar'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  bool get isArabic => locale.languageCode == 'ar';

  // ── App Brand & Header ───────────────────────────────────────────────────
  String get appName => 'MANU';
  String get appSubtitle => isArabic
      ? 'منظومة إدارة ومتابعة تدريب الامتياز التمريضي'
      : 'Nursing Internship Clinical Management System';

  // ── Navigation Tabs ──────────────────────────────────────────────────────
  String get navHome => isArabic ? 'الرئيسية' : 'Home';
  String get navRoster => isArabic ? 'الروستر' : 'Roster';
  String get navAttendance => isArabic ? 'الحضور' : 'Attendance';
  String get navQuizzes => isArabic ? 'الكويزات' : 'Quizzes';
  String get navLibrary => isArabic ? 'المكتبة' : 'Library';
  String get navProfile => isArabic ? 'الملف الشخصي' : 'Profile';
  String get navNotifications => isArabic ? 'الإشعارات' : 'Notifications';
  String get navSettings => isArabic ? 'الإعدادات' : 'Settings';

  // ── Roles ────────────────────────────────────────────────────────────────
  String get roleStudent => isArabic ? 'طالب امتياز' : 'Intern Student';
  String get roleLeader => isArabic ? 'منسق الامتياز والجدولة' : 'Internship Coordinator';
  String get roleDoctor => isArabic ? 'الدكتور المشرف' : 'Clinical Supervisor';
  String get roleAdmin => isArabic ? 'الإدارة العليا' : 'Super Admin';

  // ── Student Groups ───────────────────────────────────────────────────────
  String get groupA => isArabic ? 'المجموعة A' : 'Group A';
  String get groupB => isArabic ? 'المجموعة B' : 'Group B';
  String get groupARange => isArabic ? 'المجموعة A (الأيام 1 - 15)' : 'Group A (Days 1 - 15)';
  String get groupBRange => isArabic ? 'المجموعة B (الأيام 16 - نهاية الشهر)' : 'Group B (Days 16 - End of Month)';

  // ── Shift Types (Display Translations - DB values stay stable) ───────────
  String get shiftMorning => isArabic ? 'صباحي (Morning)' : 'Morning Shift';
  String get shiftMorningShort => isArabic ? 'صباحي' : 'Morning';
  String get shiftMorningLetter => isArabic ? 'ص' : 'M';
  String get shiftMorningTiming => isArabic ? '08:00 ص — 02:00 م (6 ساعات)' : '08:00 AM — 02:00 PM (6 hrs)';

  String get shiftLong => isArabic ? 'طويل (Long Shift)' : 'Long Shift';
  String get shiftLongShort => isArabic ? 'طويل' : 'Long';
  String get shiftLongLetter => isArabic ? 'ط' : 'L';
  String get shiftLongTiming => isArabic ? '08:00 ص — 08:00 م (12 ساعة)' : '08:00 AM — 08:00 PM (12 hrs)';

  String get shiftNight => isArabic ? 'سهر (Night Shift)' : 'Night Shift';
  String get shiftNightShort => isArabic ? 'سهر' : 'Night';
  String get shiftNightLetter => isArabic ? 'ل' : 'N';
  String get shiftNightTiming => isArabic ? '08:00 م — 08:00 ص (12 ساعة)' : '08:00 PM — 08:00 AM (12 hrs)';

  String get shiftRest => isArabic ? 'راحة' : 'Off / Rest';
  String get shiftLeave => isArabic ? 'إجازة رسمية' : 'Official Leave';
  String get shiftAbsence => isArabic ? 'غياب' : 'Absent';

  // ── Departments ──────────────────────────────────────────────────────────
  String get hospitalName => isArabic ? 'مستشفى مطروح العام' : 'Matrouh General Hospital';
  String get deptEmergency => isArabic ? 'قسم الطوارئ والعناية الحرجة' : 'Emergency & Critical Care Dept';
  String get deptEmergencyShort => isArabic ? 'قسم الطوارئ' : 'Emergency Dept';
  String get deptSurgicalIcu => isArabic ? 'عناية الجراحة' : 'Surgical ICU';
  String get deptInternalIcu => isArabic ? 'عناية الباطنة' : 'Medical ICU';
  String get deptNicu => isArabic ? 'حضانة الأطفال (NICU)' : 'Neonatal ICU (NICU)';
  String get deptCardiacIcu => isArabic ? 'عناية القلب (CCU)' : 'Coronary Care Unit (CCU)';
  String get deptDialysis => isArabic ? 'قسم الغسيل الكلوي' : 'Hemodialysis Unit';

  // ── General Statuses ─────────────────────────────────────────────────────
  String get statusApproved => isArabic ? 'معتمد ومثبت رسمياً 🟢' : 'Approved & Fixed 🟢';
  String get statusApprovedShort => isArabic ? 'معتمد' : 'Approved';
  String get statusPending => isArabic ? 'قيد المراجعة' : 'Pending Review';
  String get statusSubmitted => isArabic ? 'تم التقديم' : 'Submitted';
  String get statusDraft => isArabic ? 'مسودة' : 'Draft';
  String get statusRejected => isArabic ? 'مرفوض' : 'Rejected';
  String get statusPresent => isArabic ? 'حاضر' : 'Present';
  String get statusLate => isArabic ? 'متأخر' : 'Late';
  String get statusAbsent => isArabic ? 'غائب' : 'Absent';
  String get statusCompleted => isArabic ? 'مكتمل' : 'Completed';
  String get statusInProgress => isArabic ? 'قيد التنفيذ' : 'In Progress';
  String get statusReopened => isArabic ? 'معاد فتحه للتعديل' : 'Reopened for Edit';

  // ── Student Dashboard ────────────────────────────────────────────────────
  String greetingMorning(String name) => isArabic ? 'صباح الخير، $name 👋' : 'Good morning, $name 👋';
  String greetingEvening(String name) => isArabic ? 'مساء الخير، $name 👋' : 'Good evening, $name 👋';
  String get universityCodeLabel => isArabic ? 'كود الامتياز:' : 'ID:';
  String get todayShiftTitle => isArabic ? 'شيفت اليوم' : "Today's Shift";
  String get checkInNow => isArabic ? 'تسجيل الحضور الآن' : 'Check In Now';
  String get viewCheckInDetails => isArabic ? 'عرض تفاصيل الحضور' : 'View Attendance';
  String get checkedInStatus => isArabic ? 'تم الحضور' : 'Checked In';
  String get monthlyRosterSummary => isArabic ? 'الروستر الشهري' : 'Monthly Roster';
  String daysCount(int count, int total) => isArabic ? '$count / $total يوماً' : '$count / $total Days';
  String shiftCount(int count) => isArabic ? '$count شيفت' : '$count Shifts';
  String get viewFullApprovedRoster => isArabic ? 'عرض الروستر المعتمد الكامل' : 'View Full Approved Roster';
  String get quickAccessTitle => isArabic ? 'الوصول السريع' : 'Quick Actions';
  String get quickAccessSubtitle => isArabic ? 'أهم الأدوات اليومية للتدريب' : 'Core daily clinical tools';
  String get quickActionCheckIn => isArabic ? 'تسجيل الحضور' : 'Check In';
  String get quickActionCheckInSub => isArabic ? 'GPS والبصمة' : 'GPS & Biometrics';
  String get quickActionRoster => isArabic ? 'الروستر المعتمد' : 'Approved Roster';
  String get quickActionRosterSub => isArabic ? 'جدول الشيفتات' : 'Monthly Schedule';
  String get quickActionQuizzes => isArabic ? 'الكويزات' : 'Quizzes';
  String get quickActionQuizzesSub => isArabic ? 'بنك الأسئلة' : 'Question Bank';
  String get quickActionLogbook => isArabic ? 'سجل الحالات' : 'Clinical Logbook';
  String get quickActionLogbookSub => isArabic ? 'توثيق الإجراءات' : 'Procedure Records';
  String get dailyQuizBannerTitle => isArabic ? 'اختبر معلوماتك اليوم 🩺' : "Daily Clinical Challenge 🩺";
  String get dailyQuizBannerSubtitle => isArabic ? '5 أسئلة سريرية سريعة • حوالي 5 دقائق' : '5 quick clinical questions • ~5 mins';
  String get startDailyQuiz => isArabic ? 'ابدأ الكويز الآن' : 'Start Daily Quiz';
  String get whatToLearnTitle => isArabic ? 'ماذا تريد أن تتعلم اليوم؟' : 'Clinical Procedures Guide';
  String get whatToLearnSubtitle => isArabic ? 'إجراءات ومهارات سريرية معتمدة' : 'Verified clinical nursing skills';
  String get libraryViewAll => isArabic ? 'المكتبة' : 'Library';
  String get recentActivityTitle => isArabic ? 'النشاط الأخير' : 'Recent Activity';
  String get recentActivitySubtitle => isArabic ? 'سجل الحضور والتقييمات الأخيرة' : 'Recent check-ins & evaluations';

  // ── Roster Feature ───────────────────────────────────────────────────────
  String get approvedRosterTitle => isArabic ? 'الروستر المعتمد' : 'Approved Roster';
  String get approvedRosterBannerTitle => isArabic ? 'الروستر الرسمي المعتمد للشهر' : 'Official Approved Monthly Roster';
  String get approvedRosterBannerSubtitle => isArabic
      ? 'هذا هو الروستر المعتمد رسمياً والملزم لشيفتات التدريب بمستشفى مطروح العام.'
      : 'This is the officially published schedule for clinical shifts at Matrouh General Hospital.';
  String get notApprovedYet => isArabic ? 'لم يتم اعتماد الروستر لهذا الشهر بعد' : 'Roster has not been published yet';
  String get notApprovedSub => isArabic
      ? 'يمكنك مراجعة أو تعديل تفضيلاتك المقترحة عبر شاشة اقتراح الروستر.'
      : 'You can review or edit your shift proposals in the Preferences screen.';
  String get goToPreferences => isArabic ? 'الانتقال إلى اقتراح الروستر' : 'Go to Shift Preferences';
  String get yourApprovedShiftsSummary => isArabic ? 'ملخص شيفتاتك المعتمدة' : 'Your Approved Shifts';
  String get studentAttendanceConfirmed => isArabic ? '🟢 شيفت معتمد ومثبت رسمياً في الروستر النهائي' : '🟢 Officially assigned in approved roster';
  String get close => isArabic ? 'إغلاق' : 'Close';

  // ── Preferences Feature ──────────────────────────────────────────────────
  String get preferencesTitle => isArabic ? 'اقتراح الروستر' : 'Shift Preferences';
  String get studentPreferencesTitle => isArabic ? 'تفضيلات الطالب' : 'Student Preferences';
  String get submitPreferences => isArabic ? 'إرسال التفضيلات' : 'Submit Preferences';
  String get editPreferences => isArabic ? 'تعديل التفضيلات' : 'Edit Preferences';
  String get reopenProposal => isArabic ? 'إعادة فتح الاقتراح' : 'Reopen Proposal';
  String get preferencesSubmittedSuccess => isArabic ? 'تم إرسال تفضيلاتك بنجاح!' : 'Preferences submitted successfully!';
  String get preferencesInstructions => isArabic
      ? 'حدد 12 يوماً تدريبياً تتضمن الشيفتات المفضلة وفقاً لقواعد مجموعتك.'
      : 'Select 12 training days with preferred shifts matching your group guidelines.';

  // ── Leader Roster Dashboard ──────────────────────────────────────────────
  String get leaderRosterManagementTitle => isArabic ? 'إدارة الجدولة والروستر الشهري' : 'Monthly Schedule & Roster Management';
  String get leaderCalendarSub => isArabic ? 'تقويم الجدولة والتوزيع السريع' : 'Quick Distribution & Schedule Calendar';
  String get studentListFairnessTitle => isArabic ? 'قائمة الطلاب ومؤشرات العدالة' : 'Student List & Fairness Metrics';
  String get approveAndPublishRoster => isArabic ? 'اعتماد ونشر الروستر' : 'Approve & Publish Roster';
  String get viewCombinedRoster => isArabic ? 'عرض الروستر المجمع' : 'View Combined Roster';
  String get exportExcel => isArabic ? 'تصدير كشف Excel' : 'Export Excel Sheet';
  String get reviewPreferences => isArabic ? 'مراجعة تفضيلات الطلاب' : 'Review Student Preferences';
  String get fairnessIndex => isArabic ? 'مؤشر عدالة التوزيع' : 'Fairness Index';
  String get assignedShiftsTotal => isArabic ? 'إجمالي الشيفتات الموزعة' : 'Total Assigned Shifts';
  String get studentsCount => isArabic ? 'عدد الطلاب' : 'Students Count';
  String get editApprovedRoster => isArabic ? 'تعديل المعتمد' : 'Edit Approved';
  String get cancelEditMode => isArabic ? 'إلغاء التعديل' : 'Cancel Edit';
  String get saveApprovedRoster => isArabic ? 'حفظ وإعادة اعتماد' : 'Save & Re-approve';

  // ── Attendance Feature ───────────────────────────────────────────────────
  String get attendanceScreenTitle => isArabic ? 'تسجيل الحضور والانصراف' : 'Attendance & Check-in';
  String get insideHospitalGeofence => isArabic ? 'أنت داخل نطاق مستشفى مطروح العام' : 'You are inside hospital zone';
  String get outsideHospitalGeofence => isArabic ? 'أنت خارج نطاق المستشفى' : 'You are outside hospital zone';
  String get gpsAccuracyGood => isArabic ? 'دقة الـ GPS: عالية (±5 أمتار) • البصمة الجغرافية جاهزة' : 'GPS Accuracy: High (±5m) • Geofence Ready';
  String get checkInBtn => isArabic ? 'تسجيل الحضور الآن (Check In)' : 'Check In Now';
  String get checkOutBtn => isArabic ? 'تسجيل الانصراف (Check Out)' : 'Check Out Now';
  String get attendanceHistoryTitle => isArabic ? 'سجل الحضور الأخير' : 'Recent Attendance Log';
  String get attendanceHistorySub => isArabic ? 'التوثيق الزمني والجيومكاني للشيفتات' : 'Timestamped geolocation shift records';

  // ── Quizzes Feature ──────────────────────────────────────────────────────
  String get quizzesScreenTitle => isArabic ? 'بنك الكويزات التقييمية' : 'Clinical Quiz Bank';
  String get startQuizBtn => isArabic ? 'بدء الاختبار' : 'Start Quiz';
  String get remainingTime => isArabic ? 'الوقت المتبقي' : 'Time Remaining';
  String get nextQuestion => isArabic ? 'السؤال التالي' : 'Next Question';
  String get submitQuiz => isArabic ? 'إنهاء الاختبار وتسليم الإجابات' : 'Submit Quiz';
  String get quizPassedTitle => isArabic ? 'تهانينا! لقد اجتزت الاختبار بنجاح 🎉' : 'Congratulations! You passed 🎉';
  String get quizFailedTitle => isArabic ? 'للأسف لم تجتز درجة النجاح' : 'Did not meet passing score';

  // ── Library Feature ──────────────────────────────────────────────────────
  String get libraryScreenTitle => isArabic ? 'المكتبة السريرية المرجعية' : 'Clinical Knowledge Library';
  String get searchLibraryPlaceholder => isArabic ? 'ابحث عن إجراء، مرض، أو مهارة سريرية...' : 'Search procedures, diseases, skills...';
  String get categoryAll => isArabic ? 'الكل' : 'All';
  String get categoryProcedures => isArabic ? 'الإجراءات' : 'Procedures';
  String get categoryEmergency => isArabic ? 'الطوارئ' : 'Emergency';
  String get categoryMedications => isArabic ? 'الأدوية' : 'Medications';
  String get categorySkills => isArabic ? 'مهارات التمريض' : 'Nursing Skills';
  String get categoryDiseases => isArabic ? 'الأمراض' : 'Diseases';

  // ── Profile & Settings ───────────────────────────────────────────────────
  String get profileAndSettingsTitle => isArabic ? 'الملف الشخصي والإعدادات' : 'Profile & Settings';
  String get appearanceSection => isArabic ? 'المظهر والسمة' : 'Appearance';
  String get themeSystem => isArabic ? 'تلقائي (حسب النظام)' : 'System';
  String get themeLight => isArabic ? 'فاتح' : 'Light';
  String get themeDark => isArabic ? 'داكن' : 'Dark';
  String get languageSection => isArabic ? 'اللغة' : 'Language';
  String get languageArabic => isArabic ? 'العربية' : 'Arabic';
  String get languageEnglish => isArabic ? 'English' : 'English';
  String get accountSection => isArabic ? 'بيانات الطالب الرسمية' : 'Official Student Information';
  String get emailLabel => isArabic ? 'البريد الإلكتروني:' : 'Email:';
  String get phoneLabel => isArabic ? 'رقم المحمول:' : 'Phone:';
  String get nationalIdLabel => isArabic ? 'الرقم القومي:' : 'National ID:';
  String get residenceLabel => isArabic ? 'السكن والمحافظة:' : 'Residence:';
  String get residentMatrouh => isArabic ? 'من أبناء مطروح' : 'Matrouh Resident';
  String get residentExpatriate => isArabic ? 'مغترب (سكن طلابي)' : 'Non-resident (Dormitory)';
  String get securitySection => isArabic ? 'الأمان والتوثيق الحيوي' : 'Security & Biometrics';
  String get enableBiometrics => isArabic ? 'تفعيل بصمة الأصبع / الوجه (Biometrics)' : 'Enable Face ID / Fingerprint';
  String get enableBiometricsSub => isArabic ? 'استخدام البصمة لتسجيل الحضور السريع' : 'Use biometric sensor for quick check-in';
  String get aboutSection => isArabic ? 'حول التطبيق' : 'About App';
  String get appVersionLabel => isArabic ? 'إصدار التطبيق' : 'App Version';
  String get appVersionValue => '1.0.0 (Build 2026.08)';
  String get privacyPolicy => isArabic ? 'سياسة الخصوصية وحماية البيانات' : 'Privacy Policy';
  String get termsOfService => isArabic ? 'الشروط والأحكام التنظيمية' : 'Terms of Service';
  String get logoutBtn => isArabic ? 'تسجيل الخروج' : 'Log Out';
  String get logoutConfirmTitle => isArabic ? 'تأكيد تسجيل الخروج' : 'Confirm Logout';
  String get logoutConfirmMessage => isArabic ? 'هل تريد بالتأكيد تسجيل الخروج من حسابك؟' : 'Are you sure you want to log out?';
  String get cancel => isArabic ? 'إلغاء' : 'Cancel';
  String get confirm => isArabic ? 'تأكيد' : 'Confirm';

  // ── Weekdays ─────────────────────────────────────────────────────────────
  String get sat => isArabic ? 'السبت' : 'Sat';
  String get sun => isArabic ? 'الأحد' : 'Sun';
  String get mon => isArabic ? 'الاثنين' : 'Mon';
  String get tue => isArabic ? 'الثلاثاء' : 'Tue';
  String get wed => isArabic ? 'الأربعاء' : 'Wed';
  String get thu => isArabic ? 'الخميس' : 'Thu';
  String get fri => isArabic ? 'الجمعة' : 'Fri';

  // ── Student Registration & Approvals ─────────────────────────────────────
  String get studentApprovalsTitle => isArabic ? 'طلبات تسجيل واعتماد الطلاب' : 'Student Registration & Approvals';
  String get pendingApprovalsBanner => isArabic ? 'طلبات تنتظر الاعتماد' : 'Pending Approvals';
  String newRequestsCount(int count) => isArabic ? '$count طلب جديد' : '$count New Requests';
  String filterAllWithCount(int count) => isArabic ? 'الكل ($count)' : 'All ($count)';
  String filterPendingWithCount(int count) => isArabic ? 'قيد المراجعة ($count)' : 'Pending ($count)';
  String filterApprovedWithCount(int count) => isArabic ? 'المعتمدة ($count)' : 'Approved ($count)';
  String filterRejectedWithCount(int count) => isArabic ? 'المرفوضة ($count)' : 'Rejected ($count)';
  String get noRequestsMatchingFilter => isArabic ? 'لا توجد طلبات تسجيل مطابقة للفلتر المحدد' : 'No registration requests match the selected filter';
  String get labelUniversityCode => isArabic ? 'الكود الجامعي' : 'University Code';
  String get labelEmail => isArabic ? 'البريد الإلكتروني' : 'Email Address';
  String get labelPhone => isArabic ? 'رقم الهاتف' : 'Phone Number';
  String get labelResidenceStatus => isArabic ? 'حالة الإقامة' : 'Residence Status';
  String get residenceMatrouhResident => isArabic ? 'مقيم بمطروح ✅' : 'Matrouh Resident ✅';
  String get residenceExpatriate => isArabic ? 'مغترب 🏠' : 'Expatriate 🏠';
  String get labelResidenceAddress => isArabic ? 'عنوان السكن' : 'Residence Address';
  String get labelEmergencyContact => isArabic ? 'جهة الطوارئ' : 'Emergency Contact';
  String get labelRegistrationDate => isArabic ? 'تاريخ التسجيل' : 'Registration Date';
  String get oversightAuditTitle => isArabic ? '📋 سجل المراجعة والتفتيش (Oversight Audit):' : '📋 Oversight & Audit Log:';
  String reviewedByLabel(String reviewer) => isArabic ? 'تمت المراجعة بواسطة: $reviewer' : 'Reviewed by: $reviewer';
  String reviewDateLabel(String date) => isArabic ? 'التاريخ: $date' : 'Date: $date';
  String rejectionReasonLabel(String reason) => isArabic ? 'سبب الرفض: $reason' : 'Rejection Reason: $reason';
  String get approveAccountAction => isArabic ? 'اعتماد الحساب (Approve)' : 'Approve Account';
  String get rejectRequestAction => isArabic ? 'رفض الطلب' : 'Reject Request';
  String rejectDialogTitle(String name) => isArabic ? 'رفض طلب تسجيل: $name' : 'Reject Registration: $name';
  String get rejectReasonPrompt => isArabic ? 'يرجى كتابة سبب رفض الطلب للتسجيل في السجل التفتيشي وإرساله للطالب:' : 'Please enter reason for rejection for audit records:';
  String get rejectReasonHint => isArabic ? 'مثال: الكود الجامعي غير مطابق لبيانات الدفعة الرسمية...' : 'e.g. University code does not match official batch records...';
  String get confirmReject => isArabic ? 'تأكيد الرفض' : 'Confirm Rejection';
  String get provideRejectReasonWarning => isArabic ? 'يرجى كتابة سبب الرفض' : 'Please provide a rejection reason';
  String get searchStudentsPlaceholder => isArabic ? 'ابحث باسم الطالب أو الكود الجامعي أو البريد...' : 'Search by student name, code or email...';
  String get returnToReviewAction => isArabic ? 'إعادة للمراجعة' : 'Return to Review';
  String get returnToReviewDialogTitle => isArabic ? 'إعادة الطلب للمراجعة؟' : 'Return Request to Review?';
  String get returnToReviewDialogMessage => isArabic ? 'سيتم تحويل حالة الطالب إلى قيد المراجعة، ويمكن للقائد مراجعته واعتماده مرة أخرى.' : 'Student will be changed to pending approval and can be reviewed again.';
  String get confirmReturnToReview => isArabic ? 'إعادة للمراجعة' : 'Return to Review';
  String get returnToReviewSuccessMsg => isArabic ? 'تمت إعادة الطلب إلى قيد المراجعة بنجاح ✅' : 'Request returned to pending review ✅';
  String get deleteStudentAction => isArabic ? 'حذف الطالب نهائياً' : 'Delete Student Permanently';
  String get deleteStudentDialogTitle => isArabic ? 'حذف الطالب نهائياً؟' : 'Permanently Delete Student?';
  String get deleteStudentDialogMessage => isArabic ? 'سيتم حذف حساب الطالب وبياناته المرتبطة نهائياً من قاعدة البيانات. لا يمكن التراجع عن هذا الإجراء.' : 'This will permanently remove the student account and all linked records. This action cannot be undone.';
  String get confirmDelete => isArabic ? 'حذف نهائي' : 'Permanent Delete';
  String get deleteSuccessMsg => isArabic ? 'تم حذف حساب الطالب وبياناته بنجاح ✅' : 'Student deleted successfully ✅';
  String get showAuditHistory => isArabic ? 'عرض سجل المراجعة والتفتيش ▾' : 'Show Audit History ▾';
  String get hideAuditHistory => isArabic ? 'إخفاء سجل المراجعة والتفتيش ▲' : 'Hide Audit History ▲';
  String get moreOptions => isArabic ? 'المزيد' : 'More';
  String get labelGpa => isArabic ? 'المعدل التراكمي (GPA)' : 'GPA';
  String get labelGroup => isArabic ? 'المجموعة' : 'Group';
  String get systemAdminFallback => isArabic ? 'مسؤول النظام' : 'System Administrator';
  String get auditOperationApproved => isArabic ? 'اعتماد الطالب رسمياً' : 'Student Officially Approved';
  String get auditOperationRejected => isArabic ? 'رفض طلب التسجيل' : 'Registration Rejected';
  String get auditOperationReturned => isArabic ? 'إعادة الطلب للمراجعة' : 'Returned to Review';
  String get approveSuccessMsg => isArabic ? 'تم اعتماد حساب الطالب بنجاح وتوثيق القرار ✅' : 'Student account approved and decision logged ✅';
  String get rejectSuccessMsg => isArabic ? 'تم رفض طلب التسجيل وسجل بالتدقيق ✅' : 'Registration request rejected and logged ✅';
  String get actionErrorMsg => isArabic ? 'حدث خطأ أثناء حفظ القرار' : 'An error occurred while saving decision';
  String errorLoadingRequests(String err) => isArabic ? 'حدث خطأ في تحميل الطلبات: $err' : 'Error loading requests: $err';

  // ── Error & General Messages ─────────────────────────────────────────────
  String get generalError => isArabic
      ? 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.'
      : 'An unexpected error occurred. Please try again.';
  String get saveSuccess => isArabic ? 'تم حفظ التعديلات بنجاح.' : 'Changes saved successfully.';
  String get noDataFound => isArabic ? 'لا توجد بيانات متاحة حالياً.' : 'No data available.';
  String get retry => isArabic ? 'إعادة المحاولة' : 'Retry';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['ar', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension BuildContextLocalizations on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
