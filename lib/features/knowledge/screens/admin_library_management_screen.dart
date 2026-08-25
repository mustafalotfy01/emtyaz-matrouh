import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../models/knowledge_article.dart';
import '../providers/knowledge_provider.dart';
import '../widgets/category_management_dialog.dart';
import 'add_knowledge_content_screen.dart';
import 'in_app_pdf_viewer_screen.dart';

class AdminLibraryManagementScreen extends ConsumerStatefulWidget {
  const AdminLibraryManagementScreen({super.key});

  @override
  ConsumerState<AdminLibraryManagementScreen> createState() => _AdminLibraryManagementScreenState();
}

class _AdminLibraryManagementScreenState extends ConsumerState<AdminLibraryManagementScreen> {
  String _searchQuery = '';
  String _selectedContentType = 'all';
  bool? _selectedPublishStatus; // null = all, true = published, false = draft

  @override
  Widget build(BuildContext context) {
    final articlesAsync = ref.watch(filteredKnowledgeArticlesProvider({
      'contentType': _selectedContentType == 'all' ? null : _selectedContentType,
      'query': _searchQuery,
      'sort': 'newest',
    }));

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: const Text('إدارة المكتبة والمراجع السريرية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_rounded),
            tooltip: 'إدارة الأقسام والتصنيفات',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const CategoryManagementDialog(),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          HapticFeedback.lightImpact();
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddKnowledgeContentScreen()),
          );
          ref.invalidate(filteredKnowledgeArticlesProvider);
          ref.invalidate(knowledgeArticlesProvider);
        },
        backgroundColor: AppDesignTokens.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('إضافة محتوى جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppDesignTokens.primary,
          onRefresh: () async {
            ref.invalidate(filteredKnowledgeArticlesProvider);
            ref.invalidate(knowledgeArticlesProvider);
          },
          child: ListView(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 90),
            children: [
              // ── KPIs Section ─────────────────────────────────────────────
              articlesAsync.when(
                data: (articles) {
                  final total = articles.length;
                  final pdfCount = articles.where((a) => a.isPdf).length;
                  final publishedCount = articles.where((a) => a.isPublished).length;
                  final draftCount = total - publishedCount;
                  final totalViews = articles.fold<int>(0, (sum, a) => sum + a.viewsCount);

                  return Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          title: 'إجمالي المحتوى',
                          value: '$total',
                          icon: Icons.auto_stories_rounded,
                          color: AppDesignTokens.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildKpiCard(
                          title: 'مراجع PDF',
                          value: '$pdfCount',
                          icon: Icons.picture_as_pdf_rounded,
                          color: AppDesignTokens.danger,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildKpiCard(
                          title: 'إجمالي المشاهدات',
                          value: '$totalViews',
                          icon: Icons.remove_red_eye_rounded,
                          color: AppDesignTokens.success,
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 14),

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
                  decoration: const InputDecoration(
                    hintText: 'ابحث في محتوى ومراجع المكتبة...',
                    prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppDesignTokens.primary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Content Type Filters ─────────────────────────────────────
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildFilterChip('الكل', 'all'),
                    _buildFilterChip('📚 مراجع علمية PDF', 'scientific_reference'),
                    _buildFilterChip('📋 إجراءات تمريضية', 'procedure'),
                    _buildFilterChip('🩺 حالات مرضية', 'disease'),
                    _buildFilterChip('💊 أدوية وجرعات', 'medication'),
                    _buildFilterChip('📝 دروس وملخصات', 'lesson'),
                    _buildFilterChip('📄 محتوى عام', 'general'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Articles List ────────────────────────────────────────────
              articlesAsync.when(
                data: (articles) {
                  if (articles.isEmpty) {
                    return const AppCard(
                      padding: EdgeInsets.all(32),
                      child: AppEmptyState(
                        title: 'لا يوجد محتوى مسجل',
                        subtitle: 'لم يتم العثور على أي مقالات أو مراجع مطابقة للبحث.',
                        icon: Icons.folder_open_rounded,
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: articles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final a = articles[idx];
                      return _buildAdminArticleCard(context, a);
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Center(child: Text('خطأ في جلب البيانات: $e')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted), maxLines: 1),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedContentType == value;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: GestureDetector(
        onTap: () => setState(() => _selectedContentType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppDesignTokens.primary : AppDesignTokens.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppDesignTokens.primary : AppDesignTokens.border(context),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : AppDesignTokens.textSecondary(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminArticleCard(BuildContext context, KnowledgeArticle article) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: article.isPdf
                      ? AppDesignTokens.danger.withOpacity(0.1)
                      : AppDesignTokens.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  article.isPdf ? Icons.picture_as_pdf_rounded : Icons.article_rounded,
                  color: article.isPdf ? AppDesignTokens.danger : AppDesignTokens.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppDesignTokens.textPrimary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          article.category.displayNameAr,
                          style: const TextStyle(fontSize: 11, color: AppDesignTokens.primary, fontWeight: FontWeight.w600),
                        ),
                        if (article.subcategoryName != null) ...[
                          const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
                          Text(
                            article.subcategoryName!,
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                        const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
                        Text(
                          '👁 ${article.viewsCount}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status badges
              if (article.isFeatured)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text('⭐', style: TextStyle(fontSize: 14)),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: article.isPublished
                      ? AppDesignTokens.success.withOpacity(0.12)
                      : AppDesignTokens.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  article.isPublished ? 'منشور' : 'مسودة',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: article.isPublished ? AppDesignTokens.success : AppDesignTokens.warning,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 6),

          // Action row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (article.isPdf)
                TextButton.icon(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.menu_book_rounded, size: 16),
                  label: const Text('معاينة', style: TextStyle(fontSize: 11.5)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => InAppPdfViewerScreen(article: article)),
                    );
                  },
                ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppDesignTokens.primary),
                tooltip: 'تعديل',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AddKnowledgeContentScreen(article: article)),
                  );
                  ref.invalidate(filteredKnowledgeArticlesProvider);
                  ref.invalidate(knowledgeArticlesProvider);
                },
              ),
              IconButton(
                icon: Icon(
                  article.isPublished ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                tooltip: article.isPublished ? 'إلغاء النشر' : 'نشر الآن',
                onPressed: () async {
                  await ref.read(knowledgeRepositoryProvider).updateArticle(
                        id: article.id,
                        isPublished: !article.isPublished,
                      );
                  ref.invalidate(filteredKnowledgeArticlesProvider);
                  ref.invalidate(knowledgeArticlesProvider);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppDesignTokens.danger),
                tooltip: 'حذف',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('تأكيد الحذف'),
                      content: Text('هل أنت متأكد من حذف "${article.title}" نهائياً من المكتبة؟'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: AppDesignTokens.danger),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('حذف الآن'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await ref.read(knowledgeRepositoryProvider).deleteArticle(article.id);
                    ref.invalidate(filteredKnowledgeArticlesProvider);
                    ref.invalidate(knowledgeArticlesProvider);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
