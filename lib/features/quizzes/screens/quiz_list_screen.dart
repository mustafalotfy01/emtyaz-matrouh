import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/quiz.dart';
import '../providers/quiz_provider.dart';
import 'quiz_create_screen.dart';
import 'quiz_runner_screen.dart';

class QuizListScreen extends ConsumerWidget {
  const QuizListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizzesAsync = ref.watch(publishedQuizzesProvider);
    final user = ref.watch(authProvider).user;
    final canCreate = user?.role == UserRole.superAdmin ||
        user?.role == UserRole.evaluatingDoctor ||
        user?.role == UserRole.leader;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () async {
                HapticFeedback.lightImpact();
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuizCreateScreen()),
                );
                ref.invalidate(publishedQuizzesProvider);
              },
              backgroundColor: AppDesignTokens.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'إنشاء اختبار جديد',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppDesignTokens.primary,
          onRefresh: () async {
            ref.invalidate(publishedQuizzesProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────────────────────────────
                Row(
                  children: [
                    const Icon(Icons.quiz_rounded, color: AppDesignTokens.primary, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.quizzesScreenTitle,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppDesignTokens.textPrimary(context),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    if (canCreate)
                      FilledButton.icon(
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const QuizCreateScreen()),
                          );
                          ref.invalidate(publishedQuizzesProvider);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppDesignTokens.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                        label: const Text(
                          'إضافة اختبار',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Quizzes Content ──────────────────────────────────────────
                quizzesAsync.when(
                  data: (quizzes) {
                    if (quizzes.isEmpty) {
                      return const AppCard(
                        padding: EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                        child: AppEmptyState(
                          title: 'لا توجد اختبارات متاحة حاليًا',
                          subtitle: 'سيتم إشعارك فور قيام الدكتور المشرف أو الإدارة بنشر اختبار سريري جديد.',
                          icon: Icons.quiz_outlined,
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: quizzes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final quiz = quizzes[index];
                        return _buildQuizCard(context, quiz, l10n);
                      },
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(color: AppDesignTokens.primary),
                    ),
                  ),
                  error: (err, _) => AppCard(
                    padding: const EdgeInsets.all(20),
                    child: AppEmptyState(
                      title: 'لا توجد اختبارات متاحة حاليًا',
                      subtitle: 'تعذر جلب الاختبارات من الخادم. يرجى سحب الشاشة للأسفل للتحديث.',
                      icon: Icons.error_outline_rounded,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizCard(BuildContext context, Quiz quiz, AppLocalizations l10n) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuizRunnerScreen(quiz: quiz),
          ),
        );
      },
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.tileOrange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.psychology_rounded, color: AppColors.tileOrange, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quiz.title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: AppDesignTokens.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  quiz.description,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppDesignTokens.textSecondary(context),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppDesignTokens.surfaceMuted(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${quiz.questions.length} أسئلة',
                        style: TextStyle(fontSize: 10.5, color: AppDesignTokens.textSecondary(context), fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppDesignTokens.surfaceMuted(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${quiz.timeLimitMinutes} دقيقة',
                        style: TextStyle(fontSize: 10.5, color: AppDesignTokens.textSecondary(context), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
