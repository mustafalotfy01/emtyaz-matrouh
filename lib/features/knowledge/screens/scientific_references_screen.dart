import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/knowledge_article.dart';
import '../providers/knowledge_provider.dart';
import '../widgets/category_management_dialog.dart';
import 'add_knowledge_content_screen.dart';
import 'in_app_pdf_viewer_screen.dart';

class ScientificReferencesScreen extends ConsumerStatefulWidget {
  const ScientificReferencesScreen({super.key});

  @override
  ConsumerState<ScientificReferencesScreen> createState() => _ScientificReferencesScreenState();
}

class _ScientificReferencesScreenState extends ConsumerState<ScientificReferencesScreen> {
  String _searchQuery = '';
  String? _selectedSubcategoryId;
  String _selectedSort = 'newest';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final canManage = user?.role == UserRole.superAdmin || user?.role == UserRole.evaluatingDoctor;

    final sectionsAsync = ref.watch(studySectionsProvider);
    final filter = StudyFilesFilter(
      subcategoryId: _selectedSubcategoryId,
      query: _searchQuery,
      sort: _selectedSort,
    );
    final studyFilesAsync = ref.watch(studyFilesProvider(filter));

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () async {
                HapticFeedback.lightImpact();
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddKnowledgeContentScreen(initialContentType: 'pdf'),
                  ),
                );
                ref.invalidate(studyFilesProvider);
              },
              backgroundColor: AppDesignTokens.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'إضافة ملف PDF',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ملفات المذاكرة 📚',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'ملفات PDF تعليمية تساعد طلاب الامتياز على المذاكرة والمراجعة.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'إدارة أقسام المذاكرة',
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (_) => const CategoryManagementDialog(),
                );
                ref.invalidate(studySectionsProvider);
              },
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppDesignTokens.primary,
          onRefresh: () async {
            ref.invalidate(studyFilesProvider);
            ref.invalidate(studySectionsProvider);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 90),
            children: [
              // ── Search Bar ───────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppDesignTokens.surface(context),
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
                  border: Border.all(color: AppDesignTokens.border(context)),
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: TextStyle(fontSize: 13.5, color: AppDesignTokens.textPrimary(context)),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن ملف مذاكرة...',
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
              const SizedBox(height: 12),

              // ── Dynamic Subcategories Filter ─────────────────────────────
              sectionsAsync.when(
                data: (sections) {
                  return SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildSubcategoryChip(
                          label: 'جميع الملفات',
                          isSelected: _selectedSubcategoryId == null,
                          onTap: () => setState(() => _selectedSubcategoryId = null),
                        ),
                        ...sections.map((sub) => _buildSubcategoryChip(
                              label: sub.nameAr,
                              isSelected: _selectedSubcategoryId == sub.id,
                              onTap: () => setState(() => _selectedSubcategoryId = sub.id),
                            )),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox(
                  height: 38,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppDesignTokens.primary),
                    ),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 10),

              // ── Sorting Bar ──────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.surface(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppDesignTokens.border(context)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedSort,
                        isDense: true,
                        icon: const Icon(Icons.sort_rounded, size: 16, color: AppDesignTokens.primary),
                        style: TextStyle(fontSize: 12, color: AppDesignTokens.textPrimary(context), fontWeight: FontWeight.bold),
                        items: const [
                          DropdownMenuItem(value: 'newest', child: Text('الأحدث إضافة')),
                          DropdownMenuItem(value: 'views', child: Text('الأكثر قراءة 🔥')),
                          DropdownMenuItem(value: 'featured', child: Text('الملفات المميزة ⭐')),
                          DropdownMenuItem(value: 'alphabetical', child: Text('أبجديًا (أ-ي)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedSort = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Study Files Feed ─────────────────────────────────────────
              studyFilesAsync.when(
                data: (articles) {
                  if (articles.isEmpty) {
                    return const AppCard(
                      padding: EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                      child: AppEmptyState(
                        title: 'لا توجد ملفات مذاكرة في هذا القسم حاليًا',
                        subtitle: 'لم يتم نشر أي ملفات PDF في هذا القسم حتى الآن. سيقوم المشرفون بإضافة ملفات المذاكرة قريباً.',
                        icon: Icons.menu_book_outlined,
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: articles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final article = articles[index];
                      final isOwnerOrAdmin = canManage || (user != null && article.authorId == user.id);
                      return _buildReferenceCard(context, article, isOwnerOrAdmin: isOwnerOrAdmin);
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppDesignTokens.primary),
                        SizedBox(height: 12),
                        Text(
                          'جاري تحميل ملفات المذاكرة...',
                          style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                error: (e, _) => AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const AppEmptyState(
                        title: 'تعذر تحميل ملفات المذاكرة',
                        subtitle: 'يرجى التحقق من اتصالك بالإنترنت والضغط على إعادة المحاولة.',
                        icon: Icons.wifi_off_rounded,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => ref.invalidate(studyFilesProvider),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('إعادة المحاولة'),
                        style: FilledButton.styleFrom(backgroundColor: AppDesignTokens.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubcategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
              label,
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
  }

  Widget _buildReferenceCard(BuildContext context, KnowledgeArticle article, {bool isOwnerOrAdmin = false}) {
    final progressAsync = ref.watch(articleReadingProgressProvider(article.id));
    final progress = progressAsync.value;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // PDF Icon / Thumbnail
              Container(
                width: 48,
                height: 58,
                decoration: BoxDecoration(
                  color: AppDesignTokens.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppDesignTokens.danger.withOpacity(0.2)),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.picture_as_pdf_rounded, color: AppDesignTokens.danger, size: 26),
                    SizedBox(height: 2),
                    Text('PDF', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppDesignTokens.danger)),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Title and metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (article.isFeatured)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppDesignTokens.warning.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '⭐ ملف مميز',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppDesignTokens.warning),
                        ),
                      ),
                    Text(
                      article.title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AppDesignTokens.textPrimary(context),
                        height: 1.3,
                      ),
                    ),
                    if (article.subcategoryName != null && article.subcategoryName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'القسم: ${article.subcategoryName}',
                          style: const TextStyle(fontSize: 11.5, color: AppDesignTokens.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),

              // Edit & Delete actions for admins / owners
              if (isOwnerOrAdmin)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 19, color: AppDesignTokens.primary),
                      tooltip: 'تعديل الملف',
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddKnowledgeContentScreen(article: article),
                          ),
                        );
                        ref.invalidate(studyFilesProvider);
                        ref.invalidate(knowledgeArticlesProvider);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppDesignTokens.danger),
                      tooltip: 'حذف الملف',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _deleteArticle(article),
                    ),
                  ],
                ),
            ],
          ),

          if (article.summary.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              article.summary,
              style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context), height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Badges row: Size, Views
          Row(
            children: [
              if (article.formattedFileSize.isNotEmpty)
                _buildInfoBadge(Icons.file_present_rounded, article.formattedFileSize),
              const SizedBox(width: 10),
              _buildInfoBadge(Icons.remove_red_eye_outlined, '${article.viewsCount} قراءة'),
              const Spacer(),
            ],
          ),

          // Reading progress if started
          if (progress != null && progress.lastPage > 1) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppDesignTokens.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bookmark_added_rounded, size: 14, color: AppDesignTokens.primary),
                  const SizedBox(width: 6),
                  Text(
                    progress.displayProgress,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppDesignTokens.primary),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Open Reference Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppDesignTokens.primary,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.menu_book_rounded, size: 18, color: Colors.white),
              label: Text(
                progress != null && progress.lastPage > 1
                    ? 'متابعة القراءة من صفحة ${progress.lastPage}'
                    : 'فتح الملف 📖',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InAppPdfViewerScreen(article: article),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _deleteArticle(KnowledgeArticle article) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد حذف الملف'),
        content: Text('هل أنت متأكد من رغبتك في حذف "${article.title}" نهائياً من المكتبة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppDesignTokens.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف الآن'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await ref.read(knowledgeRepositoryProvider).deleteArticle(article.id);
        ref.invalidate(studyFilesProvider);
        ref.invalidate(knowledgeArticlesProvider);
        ref.invalidate(featuredKnowledgeArticlesProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppDesignTokens.success,
              content: Text('تم حذف الملف بنجاح ✅'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppDesignTokens.danger,
              content: Text('فشل حذف الملف: $e'),
            ),
          );
        }
      }
    }
  }

  Widget _buildInfoBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }
}
