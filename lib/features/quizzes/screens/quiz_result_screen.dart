import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../models/quiz.dart';

class QuizResultScreen extends StatelessWidget {
  final Quiz quiz;
  final Map<int, int> userAnswers;
  final double scorePercentage;
  final int correctAnswersCount;
  final bool passed;

  const QuizResultScreen({
    super.key,
    required this.quiz,
    required this.userAnswers,
    required this.scorePercentage,
    required this.correctAnswersCount,
    required this.passed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نتيجة الكويز والتوضيح العلمي'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Banner Result Card
            CustomCard(
              backgroundColor: passed ? AppColors.successLight : AppColors.dangerLight,
              child: Column(
                children: [
                  Icon(
                    passed ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                    size: 64,
                    color: passed ? AppColors.success : AppColors.danger,
                  ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

                  const SizedBox(height: 12),

                  Text(
                    passed ? 'مبروك! اجتزت الكويز بنجاح 🎉' : 'لم تتجاوز الكويز هذه المرة',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: passed ? AppColors.success : AppColors.danger,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'الدرجة الحاصل عليها: ${scorePercentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: passed ? AppColors.success : AppColors.danger,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    '$correctAnswersCount من إجمالي ${quiz.questions.length} إجابة صحيحة (حد النجاح ${quiz.passingScorePercentage}%)',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'مراجعة الأسئلة والتفسير العلمي (Scientific Rationale):',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.deepNavy,
              ),
            ),

            const SizedBox(height: 12),

            ...List.generate(quiz.questions.length, (i) {
              final q = quiz.questions[i];
              final userOptionIndex = userAnswers[i];
              final isCorrect = userOptionIndex == q.correctOptionIndex;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14.0),
                child: CustomCard(
                  borderColor: isCorrect ? AppColors.success : AppColors.danger,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isCorrect ? Icons.check_circle : Icons.cancel,
                            color: isCorrect ? AppColors.success : AppColors.danger,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'س${i + 1}: ${q.questionText}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Text(
                        'إجابتك: ${userOptionIndex != null ? q.options[userOptionIndex] : 'لم تجب'}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isCorrect ? AppColors.success : AppColors.danger,
                        ),
                      ),
                      if (!isCorrect) ...[
                        const SizedBox(height: 4),
                        Text(
                          'الإجابة الصحيحة: ${q.options[q.correctOptionIndex]}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryTeal,
                          ),
                        ),
                      ],

                      const Divider(height: 20),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.menu_book, size: 16, color: AppColors.primaryTeal),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'الشرح والتبرير العلمي: ${q.explanation}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),

            CustomButton(
              text: 'العودة لقائمة الاختبارات',
              icon: Icons.check,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
