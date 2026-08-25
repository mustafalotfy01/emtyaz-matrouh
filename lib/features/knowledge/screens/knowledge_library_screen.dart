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
import '../models/knowledge_category.dart';
import '../providers/knowledge_provider.dart';
import 'add_knowledge_content_screen.dart';
import 'admin_library_management_screen.dart';
import 'article_detail_screen.dart';
import 'in_app_pdf_viewer_screen.dart';
import 'scientific_references_screen.dart';

class KnowledgeLibraryScreen extends ConsumerStatefulWidget {
  const KnowledgeLibraryScreen({super.key});

  @override
  ConsumerState<KnowledgeLibraryScreen> createState() => _KnowledgeLibraryScreenState();
}

class _KnowledgeLibraryScreenState extends ConsumerState<KnowledgeLibraryScreen> {
  String _searchQuery = '';
  ArticleCategory _selectedCategoryFilter = ArticleCategory.all;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final canManage = user?.role == UserRole.superAdmin || user?.role == UserRole.evaluatingDoctor;

    final articlesAsync = ref.watch(knowledgeArticlesProvider);
    final featuredAsync = ref.watch(featuredKnowledgeArticlesProvider);
    final bookmarkedAsync = ref.watch(userBookmarkedArticlesProvider);
    final categoriesAsync = ref.watch(knowledgeCategoriesProvider);

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () async {
                HapticFeedback.lightImpact();
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddKnowledgeContentScreen()),
                );
                ref.invalidate(knowledgeArticlesProvider);
                ref.invalidate(featuredKnowledgeArticlesProvider);
              },
              backgroundColor: AppDesignTokens.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'إضافة محتوى سريري',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppDesignTokens.primary,
          onRefresh: () async {
            ref.invalidate(knowledgeArticlesProvider);
            ref.invalidate(featuredKnowledgeArticlesProvider);
            ref.invalidate(userBookmarkedArticlesProvider);
            ref.invalidate(knowledgeCategoriesProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Top Header ─────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppDesignTokens.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_library_rounded, color: AppDesignTokens.primary, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المكتبة العلمية',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppDesignTokens.textPrimary(context),
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'المحتوى السريري والمراجع التعليمية لطلاب الامتياز',
                            style: TextStyle(fontSize: 11.5, color: AppDesignTokens.textSecondary(context)),
                          ),
                        ],
                      ),
                    ),
                    if (canManage) ...[
                      IconButton(
                        icon: const Icon(Icons.admin_panel_settings_outlined, color: AppDesignTokens.primary),
                        tooltip: 'إدارة المكتبة',
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AdminLibraryManagementScreen()),
                          );
                          ref.invalidate(knowledgeArticlesProvider);
                          ref.invalidate(featuredKnowledgeArticlesProvider);
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // ── 2. Search Bar ─────────────────────────────────────────────
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
                      hintText: 'ابحث عن مرض، إجراء، دواء، مرجع علمي...',
                      hintStyle: TextStyle(fontSize: 12.5, color: AppDesignTokens.textSecondary(context)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppDesignTokens.primary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // ── 3. Main 7 Categories Section ──────────────────────────────
                const Text(
                  'أقسام المكتبة السريرية',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                _buildMainCategoriesGrid(context),
                const SizedBox(height: 20),

                // ── 4. Featured Study Files ─────────────────────────
                featuredAsync.when(
                  data: (featuredList) {
                    if (featuredList.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '⭐ ملفات مذاكرة مميزة',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ScientificReferencesScreen()),
                              ),
                              child: const Text('عرض الكل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 148,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: featuredList.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (context, idx) {
                              final item = featuredList[idx];
                              return _buildFeaturedCard(context, item);
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // ── 5. Saved References (Bookmarks) ───────────────────────────
                bookmarkedAsync.when(
                  data: (savedList) {
                    if (savedList.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bookmark_rounded, size: 18, color: AppDesignTokens.primary),
                            SizedBox(width: 6),
                            Text(
                              'الملفات المحفوظة وإشارات القراءة',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 90,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: savedList.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (context, idx) {
                              final refItem = savedList[idx];
                              return InkWell(
                                onTap: () {
                                  if (refItem.isPdf) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => InAppPdfViewerScreen(article: refItem)),
                                    );
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: refItem)),
                                    );
                                  }
                                },
                                child: Container(
                                  width: 220,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppDesignTokens.surface(context),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppDesignTokens.border(context)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: AppDesignTokens.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.picture_as_pdf_rounded, color: AppDesignTokens.danger, size: 20),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              refItem.title,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              refItem.displayAuthor,
                                              style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                                              maxLines: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // ── 6. Latest Knowledge Articles Feed ─────────────────────────
                Row(
                  children: [
                    const Text(
                      '🆕 أحدث المحتويات والإجراءات السريرية',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (_selectedCategoryFilter != ArticleCategory.all)
                      TextButton(
                        onPressed: () => setState(() => _selectedCategoryFilter = ArticleCategory.all),
                        child: const Text('إلغاء الفلتر', style: TextStyle(fontSize: 11.5)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                articlesAsync.when(
                  data: (allArticles) {
                    final filteredArticles = allArticles.where((a) {
                      final matchesCat = _selectedCategoryFilter == ArticleCategory.all || a.category == _selectedCategoryFilter;
                      final matchesSearch = _searchQuery.isEmpty ||
                          a.title.toLowerCase().contains(_searchQuery) ||
                          a.summary.toLowerCase().contains(_searchQuery) ||
                          (a.authorName != null && a.authorName!.toLowerCase().contains(_searchQuery));
                      return matchesCat && matchesSearch;
                    }).toList();

                    if (allArticles.isEmpty) {
                      return const AppCard(
                        padding: EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                        child: AppEmptyState(
                          title: 'المكتبة فارغة حاليًا',
                          subtitle: 'سيتم إضافة ونشر المحتوى العلمي والمراجع السريرية قريبًا من قِبل المشرفين.',
                          icon: Icons.menu_book_outlined,
                        ),
                      );
                    }

                    if (filteredArticles.isEmpty) {
                      return const AppCard(
                        padding: EdgeInsets.all(24),
                        child: AppEmptyState(
                          title: 'لا توجد نتائج مطابقة',
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
                        return _buildArticleListCard(context, article);
                      },
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(color: AppDesignTokens.primary),
                    ),
                  ),
                  error: (e, _) => AppCard(
                    padding: const EdgeInsets.all(20),
                    child: AppEmptyState(
                      title: 'تعذر الاتصال بالمكتبة',
                      subtitle: 'اسحب لأسفل لتحديث الصفحة ومحاولة الاتصال مرة أخرى.',
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

  Widget _buildMainCategoriesGrid(BuildContext context) {
    return Column(
      children: [
        // Highlighted Scientific References Banner Card
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScientificReferencesScreen()),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppDesignTokens.primary,
                  AppDesignTokens.primary.withOpacity(0.85),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppDesignTokens.primary.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '📚 ملفات المذاكرة (PDF)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          SizedBox(width: 6),
                          Chip(
                            label: Text('ملفات تعليمية', style: TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold)),
                            backgroundColor: Colors.white24,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      SizedBox(height: 3),
                      Text(
                        'ملفات PDF تعليمية تساعد طلاب الامتياز على المذاكرة والمراجعة.',
                        style: TextStyle(fontSize: 11.5, color: Colors.white70, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 6 Grid Category Cards
        Row(
          children: [
            Expanded(
              child: _buildCategoryCard(
                context,
                title: '🩺 الإجراءات التمريضية',
                subtitle: 'دليل الخطوات والبروتوكولات السريرية',
                icon: Icons.assignment_rounded,
                color: const Color(0xFF0284C7),
                category: ArticleCategory.procedure,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildCategoryCard(
                context,
                title: '🧠 الأمراض والحالات',
                subtitle: 'شرح الحالات والرعاية التمريضية',
                icon: Icons.healing_rounded,
                color: const Color(0xFFE11D48),
                category: ArticleCategory.disease,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildCategoryCard(
                context,
                title: '💊 الأدوية والحسابات',
                subtitle: 'المعلومات والجرعات الدوائية',
                icon: Icons.medication_rounded,
                color: const Color(0xFF059669),
                category: ArticleCategory.medication,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildCategoryCard(
                context,
                title: '❤️ التثقيف الصحي',
                subtitle: 'إرشادات التوعية للمرضى والمجتمع',
                icon: Icons.favorite_rounded,
                color: const Color(0xFFD97706),
                category: ArticleCategory.healthEducation,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildCategoryCard(
                context,
                title: '📝 دروس وملخصات',
                subtitle: 'شروحات تدريب الامتياز',
                icon: Icons.school_rounded,
                color: const Color(0xFF7C3AED),
                category: ArticleCategory.studentLessons,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildCategoryCard(
                context,
                title: '📖 محتوى عام',
                subtitle: 'توجيهات وأخلاقيات المهنة',
                icon: Icons.article_rounded,
                color: const Color(0xFF475569),
                category: ArticleCategory.general,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required ArticleCategory category,
  }) {
    final isSelected = _selectedCategoryFilter == category;

    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedCategoryFilter = isSelected ? ArticleCategory.all : category;
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, color: AppDesignTokens.primary, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isSelected ? AppDesignTokens.primary : AppDesignTokens.textPrimary(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10.5, color: AppDesignTokens.textSecondary(context)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCard(BuildContext context, KnowledgeArticle article) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppDesignTokens.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppDesignTokens.warning.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 46,
                decoration: BoxDecoration(
                  color: AppDesignTokens.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppDesignTokens.danger.withOpacity(0.2)),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.picture_as_pdf_rounded, color: AppDesignTokens.danger, size: 20),
                    Text('PDF', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppDesignTokens.danger)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      article.displayAuthor,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppDesignTokens.primary,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.menu_book_rounded, size: 14, color: Colors.white),
              label: const Text('فتح المرجع', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
              onPressed: () {
                if (article.isPdf) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => InAppPdfViewerScreen(article: article)),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article)),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleListCard(BuildContext context, KnowledgeArticle article) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () {
        HapticFeedback.lightImpact();
        if (article.isPdf) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => InAppPdfViewerScreen(article: article)),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article)),
          );
        }
      },
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: article.isPdf
                  ? AppDesignTokens.danger.withOpacity(0.1)
                  : AppDesignTokens.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              article.isPdf ? Icons.picture_as_pdf_rounded : Icons.article_rounded,
              color: article.isPdf ? AppDesignTokens.danger : AppDesignTokens.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (article.isFeatured)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text('⭐', style: TextStyle(fontSize: 12)),
                      ),
                    Expanded(
                      child: Text(
                        article.title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppDesignTokens.textPrimary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
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
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      article.category.displayNameAr,
                      style: const TextStyle(fontSize: 10.5, color: AppDesignTokens.primary, fontWeight: FontWeight.w600),
                    ),
                    if (article.pageCount != null && article.pageCount! > 0) ...[
                      const Text(' • ', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                      Text('${article.pageCount} صفحة', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    ],
                    const Text(' • ', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                    Text('👁 ${article.viewsCount}', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
