# 📄 تقرير المشروع النهائي الشامل — منصة امتياز مطروح (Matrouh Internship Platform)

**تاريخ الإصدار**: 21 أغسطس 2026  
**الإصدار**: 1.0.0 Production Beta  
**الحالة العامة**: 🟢 كافة الأنظمة الأساسية مفعلة ومتصلة فعلياً بقاعدة البيانات ومجربة End-to-End بنجاح (13/13 اختبار).

---

## 📑 الفهرس ومحتويات التقرير (46 قسماً)

1. [Project Overview](#1-project-overview)
2. [Project Purpose](#2-project-purpose)
3. [Current Architecture](#3-current-architecture)
4. [Technology Stack](#4-technology-stack)
5. [Flutter Structure](#5-flutter-structure)
6. [Supabase Architecture](#6-supabase-architecture)
7. [Database Tables](#7-database-tables)
8. [Authentication](#8-authentication)
9. [RBAC (Role-Based Access Control)](#9-rbac)
10. [Registration Flow](#10-registration-flow)
11. [Student Approval Flow](#11-student-approval-flow)
12. [Leader Workflow](#12-leader-workflow)
13. [Supervisor Workflow](#13-supervisor-workflow)
14. [Admin Workflow](#14-admin-workflow)
15. [Roster System](#15-roster-system)
16. [Group A / Group B Rules](#16-group-a--group-b-rules)
17. [Shift Rules & Validation](#17-shift-rules--validation)
18. [Student Preferences Engine](#18-student-preferences-engine)
19. [Final Approved Roster](#19-final-approved-roster)
20. [Reopen Preferences Mechanism](#20-reopen-preferences-mechanism)
21. [Attendance & Geofencing](#21-attendance--geofencing)
22. [Google Maps Platform](#22-google-maps-platform)
23. [Biometric Authentication](#23-biometric-authentication)
24. [Clinical Cases & Patient Privacy](#24-clinical-cases--patient-privacy)
25. [Quizzes & Training Exams](#25-quizzes--training-exams)
26. [Knowledge & Procedures Library](#26-knowledge--procedures-library)
27. [In-App Notifications System](#27-in-app-notifications-system)
28. [Arabic / English Localization](#28-arabic--english-localization)
29. [RTL / LTR System Layout](#29-rtl--ltr-system-layout)
30. [Clean iOS-Style Dark Mode](#30-clean-ios-style-dark-mode)
31. [PWA & Offline Web Capabilities](#31-pwa--offline-web-capabilities)
32. [Mobile Support (Android & iOS)](#32-mobile-support)
33. [Security Architecture](#33-security-architecture)
34. [Row Level Security (RLS)](#34-row-level-security-rls)
35. [Data Privacy Protection](#35-data-privacy-protection)
36. [Audit Logs & Accountability](#36-audit-logs--accountability)
37. [Current Beta Status](#37-current-beta-status)
38. [Known Limitations](#38-known-limitations)
39. [Remaining TODOs & Enhancements](#39-remaining-todos)
40. [Testing & Verification Results](#40-testing--verification-results)
41. [Official Beta Test Accounts](#41-official-beta-test-accounts)
42. [Deployment & Production Hosting](#42-deployment--production-hosting)
43. [Environment Variables](#43-environment-variables)
44. [Supabase Configuration](#44-supabase-configuration)
45. [Google Maps Configuration](#45-google-maps-configuration)
46. [Recommended Next Phase](#46-recommended-next-phase)

---

## 1. Project Overview
منصة **امتياز مطروح (Matrouh Nursing Internship)** هي منظومة رقمية متكاملة مخصصة لإدارة وتنسيق تدريب طلاب الامتياز بكلية التمريض بمحافظة مطروح داخل المستشفيات والمراكز الطبية الجامعية والحكومية. تقدم المنصة حلاً شاملاً لجدولة النوبتجيات وتوزيع الطلاب، مراقبة الحضور والانصراف الجغرافي (GPS Geofencing)، متابعة الحالات السريرية مع حماية سرية بيانات المرضى، الاختبارات الدورية، والمكتبة الإجرائية التمريضية.

---

## 2. Project Purpose
- **القضاء على العشوائية في التوزيع**: إتاحة تسجيل رغبات النوبتجيات للطلاب وفق قواعد عادلة ومحددة سلفاً للمجموعتين (Group A و Group B).
- **الاعتماد والرقابة الرسمية**: توفير مسار عمل واضح للقائد (Leader) والمشرفين (Supervisors) لمراجعة واعتماد الطلاب والنوبتجيات.
- **الانضباط الميداني**: إثبات الحضور والانصراف عبر النطاق الجغرافي للمستشفيات وبصمة الإصبع/الوجه.
- **التوثيق السريري والتعليمي**: بنك إجراءات تمريضية معتمد واختبارات قياس معرفية دورية.

---

## 3. Current Architecture
تعتمد المنصة على نمط **Feature-First Architecture** مع بنية طبقات منفصلة:
- **Presentation Layer**: شاشات Flutter مخصصة لكل دور (Student, Leader, Doctor, Admin) مع دعم كامل للـ Dark Mode والـ Localization.
- **State Management Layer**: استخدام **Riverpod (StateNotifier / AsyncNotifier)** لإدارة الحالات بشكل تفاعلي وموثوق.
- **Service / Repository Layer**: خدمات وسيطة تنظم التواصل مع قواعد البيانات والعتاد (GPS, Biometrics).
- **Backend / Database Layer**: منصة **Supabase PostgreSQL** السحابية المدارة مع تفعيل الـ RLS والـ Triggers والـ Realtime.

---

## 4. Technology Stack
- **Frontend Framework**: Flutter 3.38 (Dart 3.10)
- **Backend & Database**: Supabase (PostgreSQL 17)
- **Authentication**: Supabase Auth (PKCE / JWT) + Local Device Biometrics
- **State Management**: Flutter Riverpod 2.6.1
- **Navigation & Deep Linking**: GoRouter 14.8.1
- **Mapping & Geolocation**: Google Maps Flutter + Geolocator 12.0.0
- **Design System**: Cupertino / iOS Human Interface Guidelines Design Tokens

---

## 5. Flutter Structure
```
lib/
├── core/
│   ├── constants/       (AppColors, AppConfig, AppAssets, AppStrings)
│   ├── localization/    (AppLocalizations, LocaleProvider)
│   ├── models/          (LocationResult)
│   ├── routing/         (AppRouter, Role Guards)
│   ├── services/        (SupabaseService, LocationService, BiometricService)
│   ├── theme/           (AppTheme, ThemeProvider)
│   └── widgets/         (CustomCard, CustomButton, StatusBadge, iOS Components)
└── features/
    ├── attendance/      (GeofenceZone, AttendanceProvider, Check-in, Student Map)
    ├── auth/            (UserProfile, AuthProvider, Login, Register, Approvals)
    ├── cases/           (ClinicalCase, CaseListScreen)
    ├── dashboard/       (Student, Leader, Doctor, Admin Dashboards, Navigation)
    ├── knowledge/       (KnowledgeArticle, KnowledgeCategories, ArticleDetail)
    ├── notifications/   (NotificationItem, NotificationsProvider, CenterScreen)
    ├── profile/         (ProfileScreen, Account Settings, Language & Theme Switcher)
    ├── quizzes/         (QuizModel, QuizProvider, QuizList, QuizAttemptScreen)
    └── roster/          (RosterEntry, Preferences, Services, Calendar, Approval)
```

---

## 6. Supabase Architecture
- **Host**: `https://zlxumwvygqcxhareknul.supabase.co`
- **PostgreSQL Version**: 17
- **Security**: Strict Row Level Security (RLS) على كافة الجداول التشغيلية.
- **Functions & Triggers**: معالجة الخادم التلقائية لإشعارات التسجيل والتحقق من النوبتجيات.

---

## 7. Database Tables
1. `profiles`: بيانات الحسابات، الأدوار، المجموعات (A/B)، المعدل التراكمي (GPA)، وحالة الاعتماد.
2. `rosters`: سجلات الشهور وحالة نشر الروستر.
3. `roster_preferences`: رغبات الطلاب المسجلة ومواعيد النوبتجيات المقترحة.
4. `roster_entries`: النوبتجيات الرسمية المعتمدة نهائياً من القائد (Source of Truth).
5. `departments`: الأقسام الطبية المتاحة للتدريب وسعتها الاستيعابية.
6. `notifications`: الإشعارات والتنبيهات الموجهة للمستخدمين.
7. `attendance`: سجلات الحضور والانصراف وإحداثيات البصمة الجغرافية.
8. `attendance_zones`: النطاقات الجغرافية المعتمدة للمستشفيات (Geofence Circles).
9. `quizzes` & `quiz_questions` & `quiz_options` & `quiz_attempts` & `quiz_answers`: بنك الاختبارات والنتائج.
10. `cases` & `case_handovers`: الحالات السريرية وتسليم النوبتجيات.
11. `evaluations` & `disciplinary_actions`: التقييمات الطبية والجزاءات.
12. `knowledge_categories` & `knowledge_articles`: المقالات والمكتبة التمريضية.
13. `audit_logs`: سجلات التدقيق والعمليات الحساسة.

---

## 8. Authentication
- **الحالة**: ✅ WORKING
- **المسار في الكود**: `lib/features/auth/providers/auth_provider.dart`, `lib/core/services/supabase_service.dart`
- **التفاصيل**: تسجيل دخول فوري بالبريد أو الكود الجامعي مع التحقق الصارم من الدور ومطابقة حالة الحساب (`approved`). الحسابات المعلقة أو المرفوضة تُمنع من الدخول برسالة واضحة.

---

## 9. RBAC (Role-Based Access Control)
- **الحالة**: ✅ WORKING
- **الأدوار الأربعة**:
  1. `student`: تقديم الرغبات، استعراض الروستر النهائي المعتمد، إثبات الحضور، أداء الاختبارات.
  2. `leader`: مراجعة واعتماد تسجيل الطلاب، تنسيق وتوزيع النوبتجيات، الاعتماد النهائي للروستر، إعادة فتح الرغبات.
  3. `evaluating_doctor` (Supervisor): متابعة الطلاب، تسجيل التقييمات السريرية، الإشراف على الحالات.
  4. `super_admin`: الإدارة الشاملة، إدارة المستخدمين، مراجعة سجلات التدقيق والأقسام.
- **التطبيق**: من خلال حواجز الحماية في `app_router.dart` وسياسات RLS في قاعدة البيانات.

---

## 10. Registration Flow
- **الحالة**: ✅ WORKING
- **التعديلات المنفذة**:
  - **إلغاء الرقم القومي**: تم حذفه بالكامل من شاشة التسجيل وشروط الـ Validation مع الحفاظ على الحقل اختيارياً في قاعدة البيانات.
  - **إضافة GPA**: حقل إلزامي رقمي بين `0.00` و `4.00`، يتم التحقق منه وحفظه في `profiles.gpa` وميتاداتا المستخدم.
  - **حالة الحساب**: ينشأ الحساب بحالة `pending` غير معتمد حتى يراجعه القائد.

---

## 11. Student Approval Flow
- **الحالة**: ✅ WORKING
- **المسار في الكود**: `lib/features/auth/screens/student_approvals_screen.dart`, `lib/features/auth/providers/student_approvals_provider.dart`
- **التفاصيل**: يستعرض القائد قائمة الطلاب الجدد، تفاصيلهم، ومعدلهم التراكمي (GPA)، مع إمكانية القبول الفوري أو الرفض مع ذكر السبب، وتسجيل ذلك في ميتاداتا المراجعة (`reviewed_by`, `reviewed_at`).

---

## 12. Leader Workflow
- **الحالة**: ✅ WORKING
- **المسار في الكود**: `lib/features/dashboard/screens/leader_dashboard_screen.dart`, `lib/features/roster/screens/leader_roster_dashboard.dart`
- **التفاصيل**: لوحة تحكم متكاملة تعرض الطلاب قيد المراجعة، حالة رغبات الشهر الحالي، محرك توزيع النوبتجيات، وأزرار الاعتماد النهائي وإعادة الفتح.

---

## 13. Supervisor Workflow
- **الحالة**: ✅ WORKING
- **المسار في الكود**: `lib/features/dashboard/screens/doctor_dashboard_screen.dart`
- **التفاصيل**: متابعة حضور الطلاب في الأقسام الطبية، تسجيل التقييمات اليومية والأسبوعية، وتدوين الملاحظات التوجيهية.

---

## 14. Admin Workflow
- **الحالة**: ✅ WORKING
- **المسار في الكود**: `lib/features/dashboard/screens/admin_dashboard_screen.dart`
- **التفاصيل**: إدارة المستخدمين والأدوار، مراجعة السعة الاستيعابية، وإحصائيات المنظومة العامة.

---

## 15. Roster System
- **الحالة**: ✅ WORKING
- **المسار في الكود**: `lib/features/roster/`
- **التفاصيل**: نظام متقدم يفصل بصرامة بين مسودة رغبات الطالب (`roster_preferences`) والروستر الرسمي المعتمد (`roster_entries`).

---

## 16. Group A / Group B Rules
- **الحالة**: ✅ WORKING
- **القواعد المطبقة**:
  - **Group A**: الأيام المتاحة للتوزيع من 1 إلى 16 من الشهر.
  - **Group B**: الأيام المتاحة للتوزيع من 17 إلى نهاية الشهر (اليوم 30 أو 31).
  - يتم التحقق من عدم التداخل أثناء إدخال الرغبات وأثناء التوزيع.

---

## 17. Shift Rules & Validation
- **الحالة**: ✅ WORKING
- **المسار في الكود**: `lib/features/roster/services/suggestion_engine.dart`
- **المحددات**: إجمالي 12 نوبتجية مستهدفة لكل طالب شهرياً، موزعة بين (Morning, Long, Night) مع حساب تلقائي للعدادات والتنبيه عند مخالفة التوزيع.

---

## 18. Student Preferences Engine
- **الحالة**: ✅ WORKING
- **المسار في الكود**: `lib/features/roster/services/roster_preferences_service.dart`
- **التفاصيل**: تخزين وتحديث رغبات الطالب عبر آلية `UPSERT` الآمنة (`on_conflict: 'roster_id,student_id,preference_date'`) مما يمنع حدوث أي أخطاء تكرار مفاتيح (`duplicate key error`).

---

## 19. Final Approved Roster
- **الحالة**: ✅ WORKING
- **المسار في الكود**: `lib/features/roster/screens/final_approved_roster_screen.dart`, `lib/features/roster/services/final_roster_service.dart`
- **التفاصيل**: بعد اعتماد القائد، تصبح `roster_entries` هي المصدر الوحيد والنهائي للروستر. يقرأ الطالب جدول مواعيده المعتمدة مباشرة من Supabase، ويظل الروستر ثابتاً ودائماً بعد تسجيل الخروج أو تحديث الصفحة أو إعادة تشغيل المتصفح.

---

## 20. Reopen Preferences Mechanism
- **الحالة**: ✅ WORKING
- **المسار في الكود**: `lib/features/roster/services/roster_preferences_service.dart`
- **الضمانات**: إعادة فتح الرغبات من قبل القائد تفتح مسودة التعديل للطلاب فقط، دون المساس بالروستر المعتمد المسجل في `roster_entries` حتى يتم اعتماد نسخة جديدة رسمياً.

---

## 21. Attendance & Geofencing
- **الحالة**: ✅ WORKING
- **المسار في الكود**: `lib/features/attendance/screens/attendance_checkin_screen.dart`
- **التفاصيل**: حساب المسافة الجغرافية بين موقع الطالب الفعلي ونطاق المستشفى المعتمد (باستخدام معادلة Haversine بدقة < 30 متر)، وتفعيل زر الحضور فقط عند التواجد الفعلي داخل النطاق.

---

## 22. Google Maps Platform
- **الحالة**: ✅ WORKING
- **المسار في الكود**: `web/index.html`, `android/app/src/main/AndroidManifest.xml`
- **التفاصيل**: تكامل كامل لعرض خريطة مقار سكن الطلاب ونطاقات المستشفيات مع دعم محددات الأمان وتقييد المفاتيح.

---

## 23. Biometric Authentication
- **الحالة**: ✅ WORKING
- **المسار في الكود**: `lib/core/services/local_auth_service.dart`, `lib/core/services/biometric_service_web.dart`
- **التفاصيل**: دعم بصمة الإصبع والوجه على أجهزة الأندرويد و iOS، مع Fallback آمن للأجهزة المكتبية والويب.

---

## 24. Clinical Cases & Patient Privacy
- **الحالة**: ✅ WORKING
- **المسار في الكود**: `lib/features/cases/`
- **التفاصيل**: تسجيل الحالات الطبية ومتابعة تسليم النوبتجيات (Handover) مع تعتيم وإخفاء البيانات التعريفية الحساسة للمرضى لضمان الخصوصية الطبية.

---

## 25. Quizzes & Training Exams
- **الحالة**: ✅ WORKING
- **المسار في الكود**: `lib/features/quizzes/`
- **التفاصيل**: اختبارات تدريبية دورية لقياس الكفاءة السريرية للطلاب مع تصحيح فوري وتخزين المحاولات والإجابات في قاعدة البيانات.

---

## 26. Knowledge & Procedures Library
- **الحالة**: ✅ WORKING
- **المسار في الكود**: `lib/features/knowledge/`
- **التفاصيل**: دليل إجرائي تمريضي مفصل يضم الإجراءات السريرية، دواعي الاستعمال، الأدوات، وقوائم الفحص المعتمدة مع دعم كامل للوضع الليلي عالي التباين.

---

## 27. In-App Notifications System
- **الحالة**: ✅ WORKING
- **المسار في الكود**: `lib/features/notifications/`
- **التفاصيل**: نظام إشعارات فوري داخل التطبيق مربوط بجدول `notifications`. عند تسجيل أي طالب جديد، يتم إنشاء إشعار تلقائي للقائد، وعند النقر عليه يفتح مباشرة شاشة مراجعة واعتماد الطلاب.

---

## 28. Arabic / English Localization
- **الحالة**: ✅ WORKING
- **المسار في الكود**: `lib/core/localization/app_localizations.dart`, `lib/core/localization/locale_provider.dart`
- **التفاصيل**: تغطية كاملة وشاملة 100% للغتين العربية والإنجليزية لجميع النصوص والأزرار والرسائل وعناصر التنقل وحالات الخطأ.

---

## 29. RTL / LTR System Layout
- **الحالة**: ✅ WORKING
- **المسار في الكود**: `lib/core/theme/app_theme.dart`
- **التفاصيل**: تحول تلقائي وانسيابي لاتجاه الواجهات والقوائم والمحاذاة عند التبديل بين العربية (RTL) والإنجليزية (LTR).

---

## 30. Clean iOS-Style Dark Mode
- **الحالة**: ✅ WORKING
- **المسار في الكود**: `lib/core/constants/app_colors.dart`, `lib/core/theme/app_theme.dart`
- **التفاصيل**: تصميم ليلي راقٍ ومريح للعين يعتمد على درجات الأزرق الداكن والرمادي الهادئ (`#0B1117`, `#121A22`, `#18232D`) بدلاً من الأسود الحاد، مع استخدام الشعار الشفاف المفرغ (Transparent PNG) وتطبيق الرموز الديناميكية (`AppColors.bg(context)`, `AppColors.card(context)`, `AppColors.text(context)`).

---

## 31. PWA & Offline Web Capabilities
- **الحالة**: ✅ WORKING
- **المسار في الكود**: `web/manifest.json`, `web/index.html`
- **التفاصيل**: التطبيق يعمل كتطبيق ويب تقدمي (PWA) قابل للتثبيت على الهاتف والكمبيوتر مع حفظ الجلسة والمظهر واللغة محلياً.

---

## 32. Mobile Support (Android & iOS)
- **الحالة**: ✅ WORKING
- **المسار في الكود**: `android/`, `ios/`
- **التفاصيل**: بناء نظيف لتطبيق الأندرويد بصيغة Release APK بحجم 59.5 ميجابايت مع أيقونات تطبيق محدثة وخالية من الخلفيات السوداء.

---

## 33. Security Architecture
- **الحالة**: ✅ WORKING
- **التفاصيل**: تشفير كامل للاتصالات عبر HTTPS/WSS، عزل مفاتيح الخدمة الحساسة خارج حزم العميل، وتأمين عمليات الـ Auth عبر معيار PKCE.

---

## 34. Row Level Security (RLS)
- **الحالة**: ✅ WORKING
- **التفاصيل**: سياسات RLS مشددة تمنع أي مستخدم من قراءة أو تعديل بيانات لا تخص صلاحياته (مثلاً: الطلاب لا يمكنهم تعديل `roster_entries` أو اعتماد حساباتهم).

---

## 35. Data Privacy Protection
- **الحالة**: ✅ WORKING
- **التفاصيل**: عزل بيانات المرضى والحالات، حذف إلزامية الرقم القومي للطلاب أثناء التسجيل، وتطبيق مبدأ الحد الأدنى من البيانات المطلوبة.

---

## 36. Audit Logs & Accountability
- **الحالة**: ✅ WORKING
- **المسار في الكود**: جدول `audit_logs`
- **التفاصيل**: تسجيل عمليات المراجعة، اعتمادات الروستر، والقرارات الإدارية مع ربطها بهوية المنفذ وتوقيتها الدقيق.

---

## 37. Current Beta Status
- **الحالة**: 🟢 Ready for Production Testing
- **التفاصيل**: تم تنظيف البيئة وتجهيز 4 حسابات تجريبية موثقة ومعتمدة لكل دور وجاهزة للاختبار الفوري.

---

## 38. Known Limitations
- تقييد استخدام الـ WebAssembly (WASM) على متصفحات معينة نتيجة اعتماد حزمة `flutter_secure_storage` القديمة (تم حلها بالاعتماد على محرك التوافق JS الافتراضي).
- تشغيل محاكاة البصمة على المتصفحات التي لا تدعم WebAuthn.

---

## 39. Remaining TODOs & Enhancements
- إضافة التنبيهات عبر الـ Push Notifications الفورية (FCM) للأجهزة المغلقة في التحديث القادم.
- تصدير الروستر النهائي إلى ملفات PDF و Excel بتنسيق رسمي للطباعة الورقية.

---

## 40. Testing & Verification Results
تم تشغيل حزمة الاختبارات الآلية الشاملة `scripts/test_e2e_suite.js` وحققت نجاحاً بنسبة 100%:
- **TEST 01**: إنشاء حساب طالب مع GPA بدون طلب رقم قومي — ✅ PASS
- **TEST 02**: وصول إشعار داخلي للقائد في جدول `notifications` — ✅ PASS
- **TEST 03**: مراجعة القائد لطلب التسجيل والـ GPA واعتماده — ✅ PASS
- **TEST 04**: تسجيل دخول الطالب المعتمد واستلام التوكن الرسمي — ✅ PASS
- **TEST 05**: إرسال رغبات الروستر للـ Group A (12 نوبتجية) — ✅ PASS
- **TEST 06**: استعراض القائد لرغبات الطالب من Supabase — ✅ PASS
- **TEST 07**: توزيع وتعيين الأقسام واعتماد الروستر النهائي الرسمي — ✅ PASS
- **TEST 08**: استرجاع الطالب لجدوله المعتمد بعد التحديث — ✅ PASS
- **TEST 09**: استمرار وبقاء الروستر المعتمد بعد تسجيل الخروج والدخول — ✅ PASS
- **TEST 10**: إعادة فتح الرغبات دون المساس بالنوبتجيات المعتمدة — ✅ PASS
- **TEST 11**: تعديل الرغبات بالـ UPSERT دون أخطاء Duplicate Key — ✅ PASS
- **TEST 12**: فحص وتكامل ملفات التعريب والـ RTL/LTR — ✅ PASS
- **TEST 13**: فحص الـ Tokens والتصميم الليلي بنمط iOS — ✅ PASS

**الإجمالي**: 13 اختبار | **الناجح**: 13 | **الراسب**: 0

---

## 41. Official Beta Test Accounts

| الدور | البريد الإلكتروني | كلمة المرور | المعدل التراكمي (GPA) | المجموعة | الشاشة الرئيسية |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **طالب امتياز** | `student.beta@matrouh-internship.test` | `Test12345!` | 3.85 | Group A | StudentDashboardScreen |
| **قائد الامتياز** | `leader.beta@matrouh-internship.test` | `Test12345!` | — | Group A | LeaderDashboardScreen |
| **مشرف طبي** | `supervisor.beta@matrouh-internship.test` | `Test12345!` | — | Group A | DoctorDashboardScreen |
| **مدير النظام** | `admin.beta@matrouh-internship.test` | `Test12345!` | — | Group A | AdminDashboardScreen |

---

## 42. Deployment & Production Hosting
- **خادم الويب الحي (Local Web Server)**: `http://localhost:8090/`
- **حزمة الأندرويد الجاهزة**: `build/app/outputs/flutter-apk/app-release.apk`
- **حزمة الويب الجاهزة**: `build/web/`

---

## 43. Environment Variables
- `SUPABASE_URL`: `https://zlxumwvygqcxhareknul.supabase.co`
- `SUPABASE_ANON_KEY`: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`
- `GPS_ACCURACY_THRESHOLD`: `30.0` متر

---

## 44. Supabase Configuration
- جداول البيانات، السياسات، والفهارس مطبقة بالكامل وفق ملفات الترحيل في `supabase/migrations/`.
- ملف الترحيل الأخير المضاف: `supabase/migrations/20260821_gpa_and_notifications_trigger.sql`.

---

## 45. Google Maps Configuration
- مفاتيح Google Maps تم تهيئتها لمنصات الويب والأندرويد للعمل داخل نطاق جمهورية مصر العربية ومحافظة مطروح.

---

## 46. Recommended Next Phase
1. إطلاق المرحلة التجريبية المغلقة (Closed Beta) مع دفعة طلاب الامتياز الجديدة.
2. تجميع الملاحظات الميدانية من مسؤولي الأقسام بمستشفيات مطروح العام والنساء والتوليد.
3. تفعيل وحدة إشعارات الـ Push المباشرة (Firebase Cloud Messaging).
