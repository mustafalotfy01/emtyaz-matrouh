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
import '../models/knowledge_article.dart';
import '../providers/knowledge_provider.dart';
import 'article_detail_screen.dart';
import 'knowledge_article_form_screen.dart';

class KnowledgeLibraryScreen extends ConsumerStatefulWidget {
  const KnowledgeLibraryScreen({super.key});

  @override
  ConsumerState<KnowledgeLibraryScreen> createState() => _KnowledgeLibraryScreenState();
}

class _KnowledgeLibraryScreenState extends ConsumerState<KnowledgeLibraryScreen> {
  String _searchQuery = '';
  ArticleCategory _selectedCategory = ArticleCategory.all;

  @override
  Widget build(BuildContext context) {
    final articlesAsync = ref.watch(knowledgeArticlesProvider);
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
                  MaterialPageRoute(builder: (_) => const KnowledgeArticleFormScreen()),
                );
                ref.invalidate(knowledgeArticlesProvider);
              },
              backgroundColor: AppDesignTokens.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'إضافة مرجع / إجراء',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppDesignTokens.primary,
          onRefresh: () async {
            ref.invalidate(knowledgeArticlesProvider);
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
                    const Icon(Icons.menu_book_rounded, color: AppDesignTokens.primary, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.libraryScreenTitle,
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
                            MaterialPageRoute(builder: (_) => const KnowledgeArticleFormScreen()),
                          );
                          ref.invalidate(knowledgeArticlesProvider);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppDesignTokens.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                        label: const Text(
                          'إضافة محتوى',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Search Bar ───────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: AppDesignTokens.surface(context),
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
                    border: Border.all(color: AppDesignTokens.border(context)),
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                    style: TextStyle(fontSize: 13.5, color: AppDesignTokens.textPrimary(context)),
                    decoration: InputDecoration(
                      hintText: l10n.searchLibraryPlaceholder,
                      hintStyle: TextStyle(fontSize: 13, color: AppDesignTokens.textSecondary(context)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppDesignTokens.primary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Category Filter Chips ──────────────────────────────────────
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: ArticleCategory.values.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _selectedCategory = cat);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? AppDesignTokens.primary : AppDesignTokens.surface(context),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? AppDesignTokens.primary : AppDesignTokens.border(context),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                cat.displayNameAr,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? Colors.white : AppDesignTokens.textSecondary(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Articles List ──────────────────────────────────────────────
                articlesAsync.when(
                  data: (allArticles) {
                    final filteredArticles = allArticles.where((a) {
                      final matchesCategory = _selectedCategory == ArticleCategory.all || a.category == _selectedCategory;
                      final matchesQuery = _searchQuery.isEmpty ||
                          a.title.toLowerCase().contains(_searchQuery) ||
                          a.summary.toLowerCase().contains(_searchQuery);
                      return matchesCategory && matchesQuery;
                    }).toList();

                    if (allArticles.isEmpty) {
                      return const AppCard(
                        padding: EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                        child: AppEmptyState(
                          title: 'المكتبة فارغة حاليًا',
                          subtitle: 'سيتم نشر الإجراءات التمريضية والمراجع الإكلينيكية المعتمدة من قِبل المشرفين.',
                          icon: Icons.menu_book_outlined,
                        ),
                      );
                    }

                    if (filteredArticles.isEmpty) {
                      return const AppCard(
                        padding: EdgeInsets.all(24),
                        child: AppEmptyState(
                          title: 'لا توجد نتائج مطابقة للبحث',
                          subtitle: 'جرب البحث بكلمات أخرى أو اختر تصنيفاً مختلفاً.',
                          icon: Icons.search_off_rounded,
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredArticles.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final article = filteredArticles[index];
                        return AppCard(
                          padding: const EdgeInsets.all(14),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ArticleDetailScreen(article: article),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppDesignTokens.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.article_rounded, color: AppDesignTokens.primary, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      article.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppDesignTokens.textPrimary(context),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      article.summary,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppDesignTokens.textSecondary(context),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textMuted),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(color: AppDesignTokens.primary),
                    ),
                  ),
                  error: (_, __) => const AppCard(
                    padding: EdgeInsets.all(20),
                    child: AppEmptyState(
                      title: 'المكتبة فارغة حاليًا',
                      subtitle: 'تعذر الاتصال بقاعدة البيانات. اسحب لأسفل لتحديث الصفحة.',
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
}
