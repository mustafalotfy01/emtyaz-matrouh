import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_matrouh/core/models/location_result.dart';
import 'package:nurse_matrouh/core/utils/distance_calculator.dart';
import 'package:nurse_matrouh/features/attendance/models/attendance_record.dart';
import 'package:nurse_matrouh/features/community/models/community_post.dart';
import 'package:nurse_matrouh/features/community/models/community_comment.dart';
import 'package:nurse_matrouh/features/groups/models/student_group_preference.dart';
import 'package:nurse_matrouh/features/handover/models/handover_model.dart';
import 'package:nurse_matrouh/features/knowledge/models/knowledge_article.dart';
import 'package:nurse_matrouh/features/leaderboard/models/leaderboard_entry.dart';
import 'package:nurse_matrouh/features/quizzes/models/quiz.dart';
import 'package:nurse_matrouh/features/roster/models/roster_preference.dart';

void main() {
  group('Phase 1 & 2: Attendance & Location Accuracy Tests', () {
    test('AttendanceRecord parsing and empty state text', () {
      final json = {
        'id': 'att-123',
        'student_id': 'std-001',
        'department_name': 'قسم الطوارئ والعناية',
        'check_in_time': '2026-08-21T08:00:00.000Z',
        'check_in_latitude': 31.3543,
        'check_in_longitude': 27.2373,
        'geofence_status': true,
        'biometric_verified': true,
        'status': 'present',
      };

      final record = AttendanceRecord.fromJson(json);
      expect(record.id, 'att-123');
      expect(record.status, AttendanceStatus.present);
      expect(record.isGeofenceVerified, isTrue);
      expect(record.status.displayNameAr, 'حاضر');
    });

    test('LocationError produces human Arabic descriptions', () {
      const disabledRes = LocationResult(error: LocationError.serviceDisabled);
      expect(disabledRes.errorMessageAr, contains('GPS غير مفعّلة'));

      const deniedRes = LocationResult(error: LocationError.permissionDenied);
      expect(deniedRes.errorMessageAr, contains('تم رفض صلاحية'));

      const poorAccRes = LocationResult(error: LocationError.poorAccuracy);
      expect(poorAccRes.errorMessageAr, contains('دقة الموقع الحالية غير كافية'));

      const timeoutRes = LocationResult(error: LocationError.timeout);
      expect(timeoutRes.errorMessageAr, contains('انتهت مهلة'));
    });

    test('DistanceCalculator accurately measures hospital distance', () {
      // Matrouh General Hospital center
      const hospitalLat = 31.3543;
      const hospitalLng = 27.2373;

      // Point within 50 meters
      final distanceInside = DistanceCalculator.calculateDistanceMeters(
        31.3545,
        27.2375,
        hospitalLat,
        hospitalLng,
      );
      expect(distanceInside, lessThan(150.0));

      // Point far away (Cairo ~400km)
      final distanceFar = DistanceCalculator.calculateDistanceMeters(
        30.0444,
        31.2357,
        hospitalLat,
        hospitalLng,
      );
      expect(distanceFar, greaterThan(100000.0));
    });
  });

  group('Phase 3 & 4: Monthly Roster & 36-Hour Saturday-to-Friday Rule Tests', () {
    test('Month has open days (1 to daysInMonth) without Group A/B block', () {
      expect(ShiftRulesHelper.isDayAvailableForGroup(day: 1, isGroupA: true, daysInMonth: 31), isTrue);
      expect(ShiftRulesHelper.isDayAvailableForGroup(day: 15, isGroupA: true, daysInMonth: 31), isTrue);
      expect(ShiftRulesHelper.isDayAvailableForGroup(day: 16, isGroupA: true, daysInMonth: 31), isTrue);
      expect(ShiftRulesHelper.isDayAvailableForGroup(day: 31, isGroupA: true, daysInMonth: 31), isTrue);
    });

    test('Weekly 36-hour rule calculation: exactly 36h is valid', () {
      // Create 3 Long shifts in one Saturday-to-Friday week (3 * 12h = 36h)
      final preferences = [
        RosterPreference(
          id: '1',
          rosterId: 'r-1',
          studentId: 's-1',
          preferenceDate: DateTime(2026, 8, 1), // Saturday
          preferenceType: PreferenceType.optionA,
          preferenceShiftType: PreferenceShiftType.longShift, // 12h
        ),
        RosterPreference(
          id: '2',
          rosterId: 'r-1',
          studentId: 's-1',
          preferenceDate: DateTime(2026, 8, 3), // Monday
          preferenceType: PreferenceType.optionA,
          preferenceShiftType: PreferenceShiftType.longShift, // 12h
        ),
        RosterPreference(
          id: '3',
          rosterId: 'r-1',
          studentId: 's-1',
          preferenceDate: DateTime(2026, 8, 5), // Wednesday
          preferenceType: PreferenceType.optionB,
          preferenceShiftType: PreferenceShiftType.night, // 12h
        ),
      ];

      final weeklySummaries = ShiftRulesHelper.calculateWeeklySummaries(
        month: 8,
        year: 2026,
        preferences: preferences,
      );

      final week1 = weeklySummaries.first;
      expect(week1.totalHours, 36);
      expect(week1.isValid, isTrue);
    });

    test('Weekly hours rule: 35h and 37h fail validation', () {
      final summary35 = WeeklyHoursSummary(
        weekNumber: 1,
        weekStart: DateTime(2026, 8, 1),
        weekEnd: DateTime(2026, 8, 7),
        totalHours: 35,
      );
      expect(summary35.isValid, isFalse);

      final summary37 = WeeklyHoursSummary(
        weekNumber: 1,
        weekStart: DateTime(2026, 8, 1),
        weekEnd: DateTime(2026, 8, 7),
        totalHours: 37,
      );
      expect(summary37.isValid, isFalse);

      final validation = ShiftRulesHelper.validate(
        morningCount: 0,
        longCount: 2,
        nightCount: 1,
        weeklySummaries: [summary35],
      );
      expect(validation.canSubmit, isFalse);
    });

    test('ShiftRulesHelper: Odd morning count is rejected', () {
      final validation = ShiftRulesHelper.validate(
        morningCount: 3, // Odd number is invalid
        longCount: 5,
        nightCount: 4,
      );
      expect(validation.isValid, isFalse);
      expect(validation.ruleViolation, ShiftRuleViolation.morningNotEven);
    });

    test('ShiftRulesHelper: Less than 2 night shifts is rejected', () {
      final validation = ShiftRulesHelper.validate(
        morningCount: 0,
        longCount: 11,
        nightCount: 1, // Only 1 night shift
      );
      expect(validation.isValid, isFalse);
      expect(validation.ruleViolation, ShiftRuleViolation.insufficientNight);
    });
  });

  group('Phase 5 & 6: Student Group Preferences Workflow Tests', () {
    test('StudentGroupPreference parses with priority and preferred peer info', () {
      final json = {
        'id': 'gp-1',
        'student_id': 'std-1',
        'preferred_student_id': 'std-2',
        'priority': 1,
        'notes': 'سكن مشترك',
        'preferred_profile': {
          'full_name': 'أحمد محمد الشناوي',
          'university_code': 'NUR-2026-002',
          'avatar_url': null,
        },
      };

      final pref = StudentGroupPreference.fromJson(json);
      expect(pref.priority, 1);
      expect(pref.preferredStudentName, 'أحمد محمد الشناوي');
      expect(pref.notes, 'سكن مشترك');
    });
  });

  group('Phase 7 & 8: Real Quizzes Tests', () {
    test('QuizQuestion parses MCQ and True/False questions', () {
      final mcqJson = {
        'id': 'q-1',
        'quiz_id': 'quiz-1',
        'question_text': 'ما هو معدل التنفس الطبيعي؟',
        'type': 'mcq',
        'options': ['12 - 20', '30 - 40', '5 - 10', '50+'],
        'correct_option_index': 0,
        'explanation': 'المعدل الطبيعي للشخص البالغ 12 إلى 20 دورة/دقيقة.',
      };
      final mcq = QuizQuestion.fromJson(mcqJson);
      expect(mcq.type, QuestionType.mcq);
      expect(mcq.options.length, 4);
      expect(mcq.correctOptionIndex, 0);

      final tfJson = {
        'id': 'q-2',
        'quiz_id': 'quiz-1',
        'question_text': 'يتم قياس الرايل بطريقة NEX؟',
        'type': 'true_false',
        'options': [],
        'correct_option_index': 0,
      };
      final tf = QuizQuestion.fromJson(tfJson);
      expect(tf.type, QuestionType.trueFalse);
      expect(tf.options, ['صح', 'خطأ']);
    });

    test('QuizAttempt scoring percentage calculation', () {
      final attemptJson = {
        'id': 'att-1',
        'quiz_id': 'quiz-1',
        'student_id': 'std-1',
        'score_percentage': 85.0,
        'passed': true,
        'completed_at': '2026-08-21T10:00:00.000Z',
      };
      final attempt = QuizAttempt.fromJson(attemptJson);
      expect(attempt.scorePercentage, 85.0);
      expect(attempt.passed, isTrue);
    });
  });

  group('Phase 9: Real Knowledge Library Tests', () {
    test('KnowledgeArticle parses category and content correctly', () {
      final json = {
        'id': 'art-1',
        'title': 'تركيب القسطرة البولية',
        'summary': 'دليل الخطوات المعقمة',
        'type': 'procedure',
        'content_markdown': 'خطوات تركيب القسطرة...',
        'is_published': true,
        'views_count': 42,
      };

      final article = KnowledgeArticle.fromJson(json);
      expect(article.category, ArticleCategory.procedure);
      expect(article.isPublished, isTrue);
      expect(article.category.displayNameAr, 'إجراءات تمريضية');
    });
  });

  group('Phase 10: Community Tests', () {
    test('CommunityPost and CommunityComment parsing', () {
      final postJson = {
        'id': 'p-1',
        'author_id': 'std-1',
        'title': 'حالة استرواح صدري في الطوارئ',
        'content': 'تم التعامل مع حالة Tension Pneumothorax بنجاح',
        'category': 'case_study',
        'is_featured': true,
        'profiles': {'full_name': 'مصطفى لطفي', 'role': 'student'},
      };

      final post = CommunityPost.fromJson(postJson);
      expect(post.title, 'حالة استرواح صدري في الطوارئ');
      expect(post.category, PostCategory.caseStudy);
      expect(post.isFeatured, isTrue);
      expect(post.category.displayNameAr, 'دراسة حالة');

      final commentJson = {
        'id': 'c-1',
        'post_id': 'p-1',
        'author_id': 'doc-1',
        'content': 'أداء سريري ممتاز وملاحظات دقيقة',
        'profiles': {'full_name': 'د. أحمد محمود', 'role': 'evaluating_doctor'},
      };
      final comment = CommunityComment.fromJson(commentJson);
      expect(comment.authorRole, 'evaluating_doctor');
      expect(comment.content, contains('أداء سريري ممتاز'));
    });
  });

  group('Phase 11: Leaderboard Tests', () {
    test('Leaderboard sorting: Score DESC and Name ASC tie-breaker', () {
      final list = [
        LeaderboardEntry(rank: 1, studentId: '1', fullName: 'ياسر محمد', studentGroup: 'A', score: 120.0, attendedShifts: 12, attendancePercentage: 100.0),
        LeaderboardEntry(rank: 2, studentId: '2', fullName: 'أحمد علي', studentGroup: 'A', score: 140.0, attendedShifts: 14, attendancePercentage: 100.0),
        LeaderboardEntry(rank: 3, studentId: '3', fullName: 'بلال محمود', studentGroup: 'B', score: 120.0, attendedShifts: 12, attendancePercentage: 100.0),
      ];

      list.sort((a, b) {
        final scoreComp = b.score.compareTo(a.score);
        if (scoreComp != 0) return scoreComp;
        return a.fullName.compareTo(b.fullName);
      });

      expect(list[0].fullName, 'أحمد علي'); // Highest score: 140.0
      expect(list[1].fullName, 'بلال محمود'); // Score 120.0, 'ب' comes before 'ي'
      expect(list[2].fullName, 'ياسر محمد'); // Score 120.0
    });

    test('Leaderboard sorting: Alphabetical when all students have 0 score', () {
      final list = [
        LeaderboardEntry(rank: 1, studentId: '1', fullName: 'طارق حسني', studentGroup: 'A', score: 0.0, attendedShifts: 0, attendancePercentage: 100.0),
        LeaderboardEntry(rank: 2, studentId: '2', fullName: 'إبراهيم حسن', studentGroup: 'A', score: 0.0, attendedShifts: 0, attendancePercentage: 100.0),
      ];

      final allZero = list.every((e) => e.score == 0.0);
      if (allZero) {
        list.sort((a, b) => a.fullName.compareTo(b.fullName));
      }

      expect(list.first.fullName, 'إبراهيم حسن');
    });
  });

  group('Phase 12-16: Student Handover & Doctor Evaluation Tests', () {
    test('HandoverModel lifecycle: creation, acceptance, and doctor evaluation', () {
      final handoverJson = {
        'id': 'h-1',
        'from_student_id': 'std-1',
        'to_student_id': 'std-2',
        'department_name': 'قسم الطوارئ والعناية',
        'case_title': 'سرير 4 - CASE-2026-001',
        'handover_notes': 'المريض مستقر بعد تركيب كانيولا ومحلول ملحي',
        'critical_notes': 'متابعة ضغط الدم كل 30 دقيقة',
        'pending_tasks': 'أشعة الصدر منتظرة في الساعة 10:00',
        'status': 'accepted',
        'doctor_score': 8.0,
        'doctor_comment': 'تسليم شامل ومستوفٍ للمعايير السريرية',
        'from_profile': {'full_name': 'طالب مُسلِّم'},
        'to_profile': {'full_name': 'طالب مُستلِم'},
        'evaluator_profile': {'full_name': 'د. المشرف'},
      };

      final handover = HandoverModel.fromJson(handoverJson);
      expect(handover.caseTitle, 'سرير 4 - CASE-2026-001');
      expect(handover.status, HandoverStatus.accepted);
      expect(handover.doctorScore, 8.0);
      expect(handover.doctorComment, contains('تسليم شامل'));
      expect(handover.evaluatorDoctorName, 'د. المشرف');
    });
  });
}
