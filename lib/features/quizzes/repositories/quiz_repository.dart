import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../models/quiz.dart';

class QuizRepository {
  final SupabaseClient _client;

  QuizRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  /// Fetch all active quizzes with their questions
  Future<List<Quiz>> fetchQuizzes() async {
    try {
      final res = await _client
          .from('quizzes')
          .select('''
            *,
            department:department_id(id, name_ar),
            creator:created_by(id, full_name),
            quiz_questions(*)
          ''')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (res as List)
          .map((json) => Quiz.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('فشل في جلب قائمة الاختبارات: $e');
    }
  }

  /// Create new quiz with questions (Admin / Doctor CMS)
  Future<Quiz> createQuiz({
    required String title,
    String? description,
    String? departmentId,
    required int timeLimitMinutes,
    required int passingScore,
    required List<QuizQuestion> questions,
  }) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;

      // 1. Insert Quiz header
      final quizRes = await _client
          .from('quizzes')
          .insert({
            'title': title,
            'description': description,
            'department_id': departmentId,
            'created_by': currentUserId,
            'time_limit_minutes': timeLimitMinutes,
            'passing_score': passingScore,
            'is_active': true,
          })
          .select()
          .single();

      final quizId = quizRes['id'] as String;

      // 2. Insert Quiz Questions
      if (questions.isNotEmpty) {
        final questionsPayload = questions.asMap().entries.map((entry) {
          final idx = entry.key;
          final q = entry.value;
          return {
            'quiz_id': quizId,
            'question_text': q.questionText,
            'type': q.type.toDbString(),
            'options': q.options,
            'correct_option_index': q.correctOptionIndex,
            'explanation': q.explanation,
            'duration_seconds': q.durationSeconds,
            'order_index': idx,
          };
        }).toList();

        await _client.from('quiz_questions').insert(questionsPayload);
      }

      // Return full quiz
      return Quiz(
        id: quizId,
        title: title,
        description: description ?? '',
        departmentName: 'قسم التمريض',
        departmentId: departmentId,
        timeLimitMinutes: timeLimitMinutes,
        passingScorePercentage: passingScore,
        questions: questions,
      );
    } catch (e) {
      throw Exception('فشل في إنشاء الاختبار: $e');
    }
  }

  /// Delete quiz
  Future<void> deleteQuiz(String quizId) async {
    try {
      await _client.from('quizzes').delete().eq('id', quizId);
    } catch (e) {
      throw Exception('فشل في حذف الاختبار: $e');
    }
  }

  /// Submit student quiz attempt
  Future<void> submitAttempt(QuizAttemptResult result, Quiz quiz) async {
    try {
      final attemptRes = await _client
          .from('quiz_attempts')
          .insert({
            'quiz_id': result.quizId,
            'student_id': result.studentId,
            'score_percentage': result.scorePercentage,
            'passed': result.passed,
            'total_questions': result.totalQuestions,
            'correct_count': result.correctCount,
            'incorrect_count': result.incorrectCount,
            'unanswered_count': result.unansweredCount,
            'completion_time_seconds': result.completionTimeSeconds,
            'completed_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final attemptId = attemptRes['id'] as String;

      // Save individual answers if questions exist
      if (quiz.questions.isNotEmpty) {
        final answersPayload = <Map<String, dynamic>>[];
        for (int i = 0; i < quiz.questions.length; i++) {
          final q = quiz.questions[i];
          final selectedIdx = result.userAnswers[i];
          final isCorrect = selectedIdx != null && selectedIdx == q.correctOptionIndex;

          answersPayload.add({
            'attempt_id': attemptId,
            'question_id': q.id.isNotEmpty ? q.id : null,
            'selected_option_index': selectedIdx,
            'is_correct': isCorrect,
          });
        }

        try {
          await _client.from('quiz_answers').insert(answersPayload);
        } catch (_) {}
      }
    } catch (e) {
      throw Exception('فشل في تسجيل نتيجة الاختبار: $e');
    }
  }

  /// Direct attempt recorder
  Future<void> recordAttempt({
    required String quizId,
    required String studentId,
    required int scorePercentage,
    required bool passed,
  }) async {
    try {
      await _client.from('quiz_attempts').insert({
        'quiz_id': quizId,
        'student_id': studentId,
        'score_percentage': scorePercentage,
        'passed': passed,
      });
    } catch (_) {}
  }
}
