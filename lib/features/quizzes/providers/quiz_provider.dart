import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/quiz.dart';
import '../repositories/quiz_repository.dart';
import '../services/quiz_service.dart';

final quizRepositoryProvider = Provider<QuizRepository>((ref) {
  return QuizRepository();
});

final publishedQuizzesProvider = FutureProvider<List<Quiz>>((ref) async {
  return await QuizService.fetchPublishedQuizzes();
});

class QuizzesNotifier extends StateNotifier<AsyncValue<List<Quiz>>> {
  final QuizRepository _repo;

  QuizzesNotifier(this._repo) : super(const AsyncValue.loading()) {
    loadQuizzes();
  }

  Future<void> loadQuizzes() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repo.fetchQuizzes();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Quiz> createQuiz({
    required String title,
    String? description,
    String? departmentId,
    required int timeLimitMinutes,
    required int passingScore,
    required List<QuizQuestion> questions,
  }) async {
    final quiz = await _repo.createQuiz(
      title: title,
      description: description,
      departmentId: departmentId,
      timeLimitMinutes: timeLimitMinutes,
      passingScore: passingScore,
      questions: questions,
    );
    await loadQuizzes();
    return quiz;
  }
}

final quizzesProvider =
    StateNotifierProvider<QuizzesNotifier, AsyncValue<List<Quiz>>>((ref) {
  final repo = ref.watch(quizRepositoryProvider);
  return QuizzesNotifier(repo);
});
