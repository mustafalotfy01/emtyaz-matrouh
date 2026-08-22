import 'package:flutter/foundation.dart';
import '../../../core/services/supabase_service.dart';
import '../models/quiz.dart';

class QuizService {
  QuizService._();

  /// Loads all published and active quizzes from Supabase
  static Future<List<Quiz>> fetchPublishedQuizzes() async {
    if (!SupabaseService.isInitialized) return [];

    try {
      final res = await SupabaseService.client
          .from('quizzes')
          .select('*, departments(name_ar), quiz_questions(*)')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final list = (res as List).map((json) => Quiz.fromJson(json)).toList();
      return list;
    } catch (e) {
      if (kDebugMode) print('[QuizService] fetchPublishedQuizzes error: $e');
      return [];
    }
  }

  /// Records a completed quiz attempt into Supabase
  static Future<bool> recordAttempt({
    required String quizId,
    required String studentId,
    required double scorePercentage,
    required bool passed,
  }) async {
    if (!SupabaseService.isInitialized) return true;

    try {
      await SupabaseService.client.from('quiz_attempts').insert({
        'quiz_id': quizId,
        'student_id': studentId,
        'score_percentage': scorePercentage,
        'passed': passed,
        'completed_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) print('[QuizService] recordAttempt error: $e');
      return false;
    }
  }
}
