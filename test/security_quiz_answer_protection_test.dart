import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_matrouh/features/quizzes/models/quiz.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Item 7: Quiz Answer Key Protection & Server-Side Grading Tests', () {
    // Simulated PostgreSQL Tables
    final dbQuizzes = <String, Map<String, dynamic>>{
      'quiz-001': {
        'id': 'quiz-001',
        'title': 'اختبار أساسيات الطوارئ والتمريض الحرج',
        'description': 'اختبار تقييمي',
        'department_id': 'dept-icu',
        'time_limit_minutes': 10,
        'passing_score': 70,
        'is_active': true,
      }
    };

    final dbQuestions = <String, Map<String, dynamic>>{
      'q-001': {
        'id': 'q-001',
        'quiz_id': 'quiz-001',
        'question_text': 'ما هو المعدل الطبيعي لضغط الدم لدى البالغين؟',
        'type': 'mcq',
        'options': ['120/80 mmHg', '140/90 mmHg', '90/60 mmHg', '160/100 mmHg'],
        'correct_option_index': 0,
        'explanation': 'المعدل المثالي لضغط الدم هو 120/80 مم زئبق وفق معايير منظمة الصحة العالمية.',
        'duration_seconds': 30,
        'order_index': 0,
      },
      'q-002': {
        'id': 'q-002',
        'quiz_id': 'quiz-001',
        'question_text': 'يتم قياس معدل النبض الطبيعي عند الشريان الكعبري (Radial Artery).',
        'type': 'true_false',
        'options': ['صح', 'خطأ'],
        'correct_option_index': 0,
        'explanation': 'الشريان الكعبري هو الموقع الأكثر شيوعاً لقياس النبض المحيطي.',
        'duration_seconds': 30,
        'order_index': 1,
      },
      'q-003': {
        'id': 'q-003',
        'quiz_id': 'quiz-001',
        'question_text': 'في حالات الصدمة التحسسية (Anaphylaxis)، ما هو العقار الأولي؟',
        'type': 'mcq',
        'options': ['باراسيتامول', 'أدرينالين (Epinephrine)', 'أسبرين', 'أنسولين'],
        'correct_option_index': 1,
        'explanation': 'الأدرينالين هو خط الدفاع الأول والمنقذ للحياة في الصدمة التحسسية الحادة.',
        'duration_seconds': 30,
        'order_index': 2,
      },
    };

    final dbOptions = <Map<String, dynamic>>[
      {'question_id': 'q-001', 'option_text': '120/80 mmHg', 'is_correct': true},
      {'question_id': 'q-001', 'option_text': '140/90 mmHg', 'is_correct': false},
      {'question_id': 'q-002', 'option_text': 'صح', 'is_correct': true},
      {'question_id': 'q-002', 'option_text': 'خطأ', 'is_correct': false},
      {'question_id': 'q-003', 'option_text': 'باراسيتامول', 'is_correct': false},
      {'question_id': 'q-003', 'option_text': 'أدرينالين (Epinephrine)', 'is_correct': true},
    ];

    // Helper: Simulate RLS Policy on quiz_options
    List<Map<String, dynamic>> simulateSelectQuizOptions({required String callerRole}) {
      // RLS Policy: public.get_auth_role() IN ('super_admin', 'leader', 'evaluating_doctor') OR service_role
      final isStaff = ['super_admin', 'leader', 'evaluating_doctor', 'service_role'].contains(callerRole);
      if (!isStaff) {
        // Students & anon are blocked by RLS
        return [];
      }
      return dbOptions;
    }

    // Helper: Simulate RLS Policy on quiz_questions
    List<Map<String, dynamic>> simulateSelectQuizQuestionsDirect({required String callerRole}) {
      final isStaff = ['super_admin', 'leader', 'evaluating_doctor', 'service_role'].contains(callerRole);
      if (!isStaff) {
        // Students cannot SELECT from quiz_questions table directly
        return [];
      }
      return dbQuestions.values.toList();
    }

    // Helper: Simulate get_active_quizzes RPC
    List<Map<String, dynamic>> simulateGetActiveQuizzesRpc({required String callerRole}) {
      final isStaff = ['super_admin', 'leader', 'evaluating_doctor', 'service_role'].contains(callerRole);

      return dbQuizzes.values.map((q) {
        final qList = dbQuestions.values.where((item) => item['quiz_id'] == q['id']).map((item) {
          return {
            'id': item['id'],
            'quiz_id': item['quiz_id'],
            'question_text': item['question_text'],
            'type': item['type'],
            'options': item['options'],
            'duration_seconds': item['duration_seconds'],
            'order_index': item['order_index'],
            // Sanitized mask for students; unmasked for staff
            'correct_option_index': isStaff ? item['correct_option_index'] : -1,
            'explanation': isStaff ? item['explanation'] : null,
          };
        }).toList();

        return {
          ...q,
          'departments': {'name_ar': 'قسم التمريض العام'},
          'quiz_questions': qList,
        };
      }).toList();
    }

    // Helper: Simulate submit_quiz_attempt RPC
    Map<String, dynamic> simulateSubmitQuizAttemptRpc({
      required String? callerId,
      required String? callerRole,
      required String quizId,
      required List<Map<String, dynamic>> answers,
      int completionTimeSeconds = 30,
    }) {
      if (callerId == null || callerId.isEmpty) {
        return {'success': false, 'errorCode': '42501', 'error': 'Authentication required'};
      }

      final quiz = dbQuizzes[quizId];
      if (quiz == null || quiz['is_active'] != true) {
        return {'success': false, 'errorCode': '22023', 'error': 'Quiz not found or inactive'};
      }

      final questions = dbQuestions.values.where((q) => q['quiz_id'] == quizId).toList()
        ..sort((a, b) => (a['order_index'] as int).compareTo(b['order_index'] as int));

      int correctCount = 0;
      int incorrectCount = 0;
      int unansweredCount = 0;
      final feedback = <Map<String, dynamic>>[];

      for (final q in questions) {
        final qId = q['id'];
        final correctIdx = q['correct_option_index'] as int;

        int? selectedIdx;
        for (final a in answers) {
          if (a['question_id'] == qId || a['order_index'] == q['order_index']) {
            selectedIdx = a['selected_option_index'] as int?;
            break;
          }
        }

        bool isCorrect = false;
        if (selectedIdx == null || selectedIdx < 0) {
          unansweredCount++;
        } else if (selectedIdx == correctIdx) {
          correctCount++;
          isCorrect = true;
        } else {
          incorrectCount++;
        }

        feedback.add({
          'question_id': qId,
          'selected_option_index': selectedIdx,
          'correct_option_index': correctIdx,
          'is_correct': isCorrect,
          'explanation': q['explanation'],
        });
      }

      final total = questions.length;
      final scorePct = total > 0 ? (correctCount / total) * 100.0 : 0.0;
      final passed = scorePct >= (quiz['passing_score'] as int);

      return {
        'success': true,
        'attempt_id': 'attempt-uuid-verified-001',
        'quiz_id': quizId,
        'student_id': callerId,
        'score_percentage': double.parse(scorePct.toStringAsFixed(2)),
        'passed': passed,
        'total_questions': total,
        'correct_count': correctCount,
        'incorrect_count': incorrectCount,
        'unanswered_count': unansweredCount,
        'completion_time_seconds': completionTimeSeconds,
        'questions_feedback': feedback,
      };
    }

    test('1. Student cannot SELECT is_correct directly from quiz_options', () {
      final studentResult = simulateSelectQuizOptions(callerRole: 'student');
      expect(studentResult, isEmpty);

      final anonResult = simulateSelectQuizOptions(callerRole: 'anon');
      expect(anonResult, isEmpty);
    });

    test('2. Student cannot obtain correct answers through direct quiz_questions query', () {
      final studentQuestions = simulateSelectQuizQuestionsDirect(callerRole: 'student');
      expect(studentQuestions, isEmpty);
    });

    test('3. get_active_quizzes RPC delivers sanitized questions to students without answer key', () {
      final studentQuizzes = simulateGetActiveQuizzesRpc(callerRole: 'student');
      expect(studentQuizzes, isNotEmpty);

      final quiz = Quiz.fromJson(studentQuizzes.first);
      expect(quiz.questions, hasLength(3));

      // Assert question text and choices are present
      expect(quiz.questions[0].questionText, contains('ضغط الدم'));
      expect(quiz.questions[0].options, hasLength(4));

      // Assert correct_option_index is masked (-1) and explanation is hidden
      for (final q in quiz.questions) {
        expect(q.correctOptionIndex, equals(-1), reason: 'Correct answer must be masked for students');
        expect(q.explanation, isEmpty, reason: 'Explanation must be hidden from students before grading');
      }
    });

    test('4. Legitimate staff (doctor/admin/leader) receive complete unmasked question key', () {
      final doctorQuizzes = simulateGetActiveQuizzesRpc(callerRole: 'evaluating_doctor');
      final doctorQuiz = Quiz.fromJson(doctorQuizzes.first);

      expect(doctorQuiz.questions[0].correctOptionIndex, equals(0));
      expect(doctorQuiz.questions[0].explanation, contains('المعدل المثالي'));

      expect(doctorQuiz.questions[2].correctOptionIndex, equals(1));
      expect(doctorQuiz.questions[2].explanation, contains('الأدرينالين'));
    });

    test('5. Client cannot submit a fake is_correct value and influence grading', () {
      // Student sends wrong answer (selected 3 for Epinephrine which is index 1),
      // but claims in the payload that 'is_correct' is true:
      final attemptRes = simulateSubmitQuizAttemptRpc(
        callerId: 'student-uuid-999',
        callerRole: 'student',
        quizId: 'quiz-001',
        answers: [
          {'question_id': 'q-001', 'selected_option_index': 0}, // correct
          {'question_id': 'q-002', 'selected_option_index': 1, 'is_correct': true}, // WRONG answer (index 1), fake claim true
          {'question_id': 'q-003', 'selected_option_index': 0, 'is_correct': true}, // WRONG answer (index 0), fake claim true
        ],
      );

      expect(attemptRes['success'], isTrue);
      // Server-side verification evaluates q-002 and q-003 as false regardless of client payload!
      expect(attemptRes['correct_count'], equals(1));
      expect(attemptRes['incorrect_count'], equals(2));
      expect(attemptRes['score_percentage'], closeTo(33.33, 0.05));
      expect(attemptRes['passed'], isFalse);

      final feedback = attemptRes['questions_feedback'] as List;
      expect(feedback[1]['is_correct'], isFalse);
      expect(feedback[2]['is_correct'], isFalse);
    });

    test('6. Client cannot submit a fake score and influence the final result', () {
      // Even if a malicious client attempts to call submit_quiz_attempt with 0 correct answers:
      final attemptRes = simulateSubmitQuizAttemptRpc(
        callerId: 'student-uuid-999',
        callerRole: 'student',
        quizId: 'quiz-001',
        answers: [
          {'question_id': 'q-001', 'selected_option_index': 3}, // wrong
          {'question_id': 'q-002', 'selected_option_index': 1}, // wrong
          {'question_id': 'q-003', 'selected_option_index': 0}, // wrong
        ],
      );

      expect(attemptRes['score_percentage'], equals(0.0));
      expect(attemptRes['passed'], isFalse);
    });

    test('7. Server correctly grades valid submitted answers and awards passing score', () {
      final attemptRes = simulateSubmitQuizAttemptRpc(
        callerId: 'student-uuid-999',
        callerRole: 'student',
        quizId: 'quiz-001',
        answers: [
          {'question_id': 'q-001', 'selected_option_index': 0}, // correct (120/80)
          {'question_id': 'q-002', 'selected_option_index': 0}, // correct (صح)
          {'question_id': 'q-003', 'selected_option_index': 1}, // correct (أدرينالين)
        ],
      );

      expect(attemptRes['success'], isTrue);
      expect(attemptRes['correct_count'], equals(3));
      expect(attemptRes['incorrect_count'], equals(0));
      expect(attemptRes['score_percentage'], equals(100.0));
      expect(attemptRes['passed'], isTrue);
    });

    test('8. Post-submission feedback legitimately reveals answers and explanations for completed attempt', () {
      final attemptRes = simulateSubmitQuizAttemptRpc(
        callerId: 'student-uuid-999',
        callerRole: 'student',
        quizId: 'quiz-001',
        answers: [
          {'question_id': 'q-001', 'selected_option_index': 0},
          {'question_id': 'q-002', 'selected_option_index': 1}, // wrong
          {'question_id': 'q-003', 'selected_option_index': 1},
        ],
      );

      final feedback = attemptRes['questions_feedback'] as List;
      expect(feedback, hasLength(3));

      // Once graded, student sees full explanation for educational value
      expect(feedback[0]['correct_option_index'], equals(0));
      expect(feedback[0]['is_correct'], isTrue);
      expect(feedback[0]['explanation'], contains('المعدل المثالي'));

      expect(feedback[1]['selected_option_index'], equals(1));
      expect(feedback[1]['correct_option_index'], equals(0));
      expect(feedback[1]['is_correct'], isFalse);
      expect(feedback[1]['explanation'], contains('الشريان الكعبري'));
    });

    test('9 & 10. Existing Quiz model parsing and creation data integrity', () {
      final testQuestion = QuizQuestion(
        id: 'new-q-01',
        quizId: 'quiz-new',
        questionText: 'سؤال سريري تجريبي',
        type: QuestionType.mcq,
        options: ['أ', 'ب', 'ج', 'د'],
        correctOptionIndex: 2,
        explanation: 'الخيار (ج) هو الصحيح سريرياً.',
        durationSeconds: 45,
      );

      final newQuiz = Quiz(
        id: 'quiz-new',
        title: 'اختبار تجريبي جديد',
        description: 'وصف الاختبار',
        departmentName: 'قسم الطوارئ',
        timeLimitMinutes: 15,
        passingScorePercentage: 75,
        questions: [testQuestion],
      );

      expect(newQuiz.title, equals('اختبار تجريبي جديد'));
      expect(newQuiz.questions[0].correctOptionIndex, equals(2));
      expect(newQuiz.questions[0].type.toDbString(), equals('mcq'));
    });
  });
}
