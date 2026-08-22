import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/quiz.dart';
import '../providers/quiz_provider.dart';
import 'quiz_result_screen.dart';

class QuizRunnerScreen extends ConsumerStatefulWidget {
  final Quiz quiz;

  const QuizRunnerScreen({super.key, required this.quiz});

  @override
  ConsumerState<QuizRunnerScreen> createState() => _QuizRunnerScreenState();
}

class _QuizRunnerScreenState extends ConsumerState<QuizRunnerScreen> {
  int _currentQuestionIndex = 0;
  final Map<int, int?> _userAnswers = {}; // null if unanswered
  late int _questionRemainingSeconds;
  Timer? _questionTimer;
  final Stopwatch _totalStopwatch = Stopwatch();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _totalStopwatch.start();
    _startQuestionTimer();
  }

  void _startQuestionTimer() {
    _questionTimer?.cancel();
    final currentQ = widget.quiz.questions[_currentQuestionIndex];
    _questionRemainingSeconds = currentQ.durationSeconds > 0 ? currentQ.durationSeconds : 30;

    _questionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_questionRemainingSeconds <= 1) {
        t.cancel();
        _onQuestionTimeout();
      } else {
        setState(() => _questionRemainingSeconds--);
      }
    });
  }

  void _onQuestionTimeout() {
    // Record unanswered if not picked
    if (!_userAnswers.containsKey(_currentQuestionIndex)) {
      _userAnswers[_currentQuestionIndex] = null;
    }

    if (_currentQuestionIndex < widget.quiz.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
      _startQuestionTimer();
    } else {
      _submitQuiz();
    }
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _totalStopwatch.stop();
    super.dispose();
  }

  void _goToNextQuestion() {
    _questionTimer?.cancel();
    if (_currentQuestionIndex < widget.quiz.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
      _startQuestionTimer();
    } else {
      _submitQuiz();
    }
  }

  Future<void> _submitQuiz() async {
    _questionTimer?.cancel();
    _totalStopwatch.stop();

    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    int correctCount = 0;
    int incorrectCount = 0;
    int unansweredCount = 0;

    for (int i = 0; i < widget.quiz.questions.length; i++) {
      final ans = _userAnswers[i];
      if (ans == null) {
        unansweredCount++;
      } else if (ans == widget.quiz.questions[i].correctOptionIndex) {
        correctCount++;
      } else {
        incorrectCount++;
      }
    }

    final totalQuestions = widget.quiz.questions.length;
    final scorePercentage = totalQuestions > 0 ? (correctCount / totalQuestions) * 100 : 0.0;
    final passed = scorePercentage >= widget.quiz.passingScorePercentage;
    final completionTime = _totalStopwatch.elapsed.inSeconds;

    final currentUserId = ref.read(authProvider).user?.id ?? '';

    final attemptResult = QuizAttemptResult(
      quizId: widget.quiz.id,
      studentId: currentUserId,
      totalQuestions: totalQuestions,
      correctCount: correctCount,
      incorrectCount: incorrectCount,
      unansweredCount: unansweredCount,
      scorePercentage: scorePercentage,
      passed: passed,
      completionTimeSeconds: completionTime,
      userAnswers: _userAnswers,
    );

    // Save to real database
    try {
      await ref.read(quizRepositoryProvider).submitAttempt(attemptResult, widget.quiz);
    } catch (_) {}

    if (!mounted) return;

    final nonNullAnswers = <int, int>{};
    _userAnswers.forEach((k, v) {
      if (v != null) nonNullAnswers[k] = v;
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuizResultScreen(
          quiz: widget.quiz,
          userAnswers: nonNullAnswers,
          scorePercentage: scorePercentage,
          correctAnswersCount: correctCount,
          passed: passed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.quiz.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.quiz.title)),
        body: const Center(child: Text('لا توجد أسئلة في هذا الاختبار')),
      );
    }

    final currentQ = widget.quiz.questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / widget.quiz.questions.length;
    final questionDuration = currentQ.durationSeconds > 0 ? currentQ.durationSeconds : 30;
    final timerRatio = (_questionRemainingSeconds / questionDuration).clamp(0.0, 1.0);
    final isUrgent = _questionRemainingSeconds <= 10;

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: Text(widget.quiz.title),
        centerTitle: false,
        actions: [
          // Per-Question Countdown Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isUrgent ? AppDesignTokens.danger.withOpacity(0.12) : AppDesignTokens.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
              border: Border.all(
                color: isUrgent ? AppDesignTokens.danger : AppDesignTokens.primary,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 18,
                  color: isUrgent ? AppDesignTokens.danger : AppDesignTokens.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '$_questionRemainingSeconds ثانية',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isUrgent ? AppDesignTokens.danger : AppDesignTokens.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Overall Quiz Progress Bar
            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppDesignTokens.border(context),
              color: AppDesignTokens.primary,
              minHeight: 4,
            ),

            // Question Timer Bar (shrinking countdown)
            LinearProgressIndicator(
              value: timerRatio,
              backgroundColor: Colors.transparent,
              color: isUrgent ? AppDesignTokens.danger : AppDesignTokens.warning,
              minHeight: 2.5,
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'السؤال ${_currentQuestionIndex + 1} من ${widget.quiz.questions.length}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppDesignTokens.primary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppDesignTokens.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                          ),
                          child: Text(
                            currentQ.type.displayNameAr,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppDesignTokens.primary),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Question Card
                    AppCard(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        currentQ.questionText,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppDesignTokens.textPrimary(context),
                          height: 1.5,
                        ),
                      ),
                    ).animate().fade().slideX(begin: 0.05, end: 0),

                    const SizedBox(height: 16),

                    // Options List
                    ...List.generate(currentQ.options.length, (optIdx) {
                      final optionText = currentQ.options[optIdx];
                      final isSelected = _userAnswers[_currentQuestionIndex] == optIdx;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: AppCard(
                          onTap: () {
                            setState(() {
                              _userAnswers[_currentQuestionIndex] = optIdx;
                            });
                          },
                          variant: isSelected ? AppCardVariant.elevated : AppCardVariant.standard,
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? AppDesignTokens.primary : AppDesignTokens.surfaceMuted(context),
                                  border: Border.all(
                                    color: isSelected ? AppDesignTokens.primary : AppDesignTokens.border(context),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${optIdx + 1}',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : AppDesignTokens.textSecondary(context),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  optionText,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? AppDesignTokens.primary : AppDesignTokens.textPrimary(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Bottom Navigation Action Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppDesignTokens.surface(context),
                border: Border(top: BorderSide(color: AppDesignTokens.border(context))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: _currentQuestionIndex == widget.quiz.questions.length - 1
                          ? 'إنهاء وتأكيد النتيجة'
                          : 'التالي (السؤال التالي)',
                      icon: _currentQuestionIndex == widget.quiz.questions.length - 1
                          ? Icons.done_all_rounded
                          : Icons.arrow_forward_rounded,
                      variant: AppButtonVariant.primary,
                      isLoading: _isSubmitting,
                      onPressed: _goToNextQuestion,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
