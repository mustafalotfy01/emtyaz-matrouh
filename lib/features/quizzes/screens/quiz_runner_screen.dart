import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../models/quiz.dart';
import 'quiz_result_screen.dart';

class QuizRunnerScreen extends StatefulWidget {
  final Quiz quiz;

  const QuizRunnerScreen({super.key, required this.quiz});

  @override
  State<QuizRunnerScreen> createState() => _QuizRunnerScreenState();
}

class _QuizRunnerScreenState extends State<QuizRunnerScreen> {
  int _currentQuestionIndex = 0;
  final Map<int, int> _userAnswers = {};
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.quiz.timeLimitMinutes * 60;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds <= 1) {
        t.cancel();
        _submitQuiz();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _submitQuiz() {
    _timer?.cancel();
    int correctCount = 0;
    for (int i = 0; i < widget.quiz.questions.length; i++) {
      if (_userAnswers[i] == widget.quiz.questions[i].correctOptionIndex) {
        correctCount++;
      }
    }

    final scorePercentage = (correctCount / widget.quiz.questions.length) * 100;
    final passed = scorePercentage >= widget.quiz.passingScorePercentage;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuizResultScreen(
          quiz: widget.quiz,
          userAnswers: _userAnswers,
          scorePercentage: scorePercentage,
          correctAnswersCount: correctCount,
          passed: passed,
        ),
      ),
    );
  }

  String _formatTimer() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentQ = widget.quiz.questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / widget.quiz.questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quiz.title),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(left: 16),
            decoration: BoxDecoration(
              color: _remainingSeconds < 60 ? AppColors.dangerLight : AppColors.primaryTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer,
                  size: 16,
                  color: _remainingSeconds < 60 ? AppColors.danger : AppColors.primaryTeal,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatTimer(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _remainingSeconds < 60 ? AppColors.danger : AppColors.primaryTeal,
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
            // Progress Bar
            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.borderLight,
              color: AppColors.primaryTeal,
              minHeight: 6,
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
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
                            color: AppColors.primaryTeal,
                          ),
                        ),
                        if (currentQ.type == QuestionType.caseStudy)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.warningLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'دراسة حالة كينيكية',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.warning),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Question Card
                    CustomCard(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        currentQ.questionText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepNavy,
                          height: 1.5,
                        ),
                      ),
                    ).animate().fade().slideX(begin: 0.1, end: 0),

                    const SizedBox(height: 20),

                    // Options List
                    ...List.generate(currentQ.options.length, (optIdx) {
                      final optionText = currentQ.options[optIdx];
                      final isSelected = _userAnswers[_currentQuestionIndex] == optIdx;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: CustomCard(
                          onTap: () {
                            setState(() {
                              _userAnswers[_currentQuestionIndex] = optIdx;
                            });
                          },
                          backgroundColor: isSelected ? AppColors.primaryTeal.withOpacity(0.08) : AppColors.surfaceWhite,
                          borderColor: isSelected ? AppColors.primaryTeal : AppColors.borderLight,
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? AppColors.primaryTeal : AppColors.lightBg,
                                  border: Border.all(
                                    color: isSelected ? AppColors.primaryTeal : AppColors.borderLight,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${optIdx + 1}',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : AppColors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  optionText,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? AppColors.primaryTeal : AppColors.textPrimary,
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

            // Bottom Navigation Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.surfaceWhite,
                border: Border(top: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                children: [
                  if (_currentQuestionIndex > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() => _currentQuestionIndex--);
                        },
                        child: const Text('السابق'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: CustomButton(
                      text: _currentQuestionIndex == widget.quiz.questions.length - 1
                          ? 'إنهاء وتكشيف النتيجة'
                          : 'التالي',
                      onPressed: () {
                        if (_currentQuestionIndex < widget.quiz.questions.length - 1) {
                          setState(() => _currentQuestionIndex++);
                        } else {
                          _submitQuiz();
                        }
                      },
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
