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
import '../models/knowledge_category.dart';
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
  String? _selectedTag;

  final List<String> _popularTags = [
    'تمريض',
    'ICU',
    'طوارئ',
    'باطنة',
    'جراحة',
    'أطفال',
    'نساء وتوليد',
    'أدوية',
    'مكافحة عدوى',
    'صحة نفسية',
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final canManage = user?.role == UserRole.superAdmin || user?.role == UserRole.evaluatingDoctor;

    final categoriesAsync = ref.watch(knowledgeCategoriesProvider);
    final referencesAsync = ref.watch(scientificReferencesProvider({
      'subcategoryId': _selectedSubcategoryId,
      'query': _searchQuery,
      'tag': _selectedTag,
      'sort': _selectedSort,
    }));

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () async {
                HapticFeedback.lightImpact();
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddKnowledgeContentScreen(initialContentType: 'scientific_reference'),
                  ),
                );
                ref.invalidate(scientificReferencesProvider);
              },
              backgroundColor: AppDesignTokens.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'إضافة مرجع علمي (PDF)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'المراجع العلمية 📚',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'كتب ومراجع سريرية معتمدة لطلاب الامتياز',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'إدارة الأقسام الفرعية',
              onPressed: () {
                // Find scientific reference parent category ID
                final categories = categoriesAsync.value ?? [];
                final sciCategory = categories.firstWhere(
                  (c) => c.nameAr.contains('المراجع') || c.id == '00000000-0000-0000-0000-000000000007',
                  orElse: () => KnowledgeCategory(id: '00000000-0000-0000-0000-000000000007', nameAr: 'المراجع العلمية'),
                );

                showDialog(
                  context: context,
                  builder: (_) => CategoryManagementDialog(
                    parentCategoryId: sciCategory.id,
                    parentCategoryName: sciCategory.nameAr,
                  ),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppDesignTokens.primary,
          onRefresh: () async {
            ref.invalidate(scientificReferencesProvider);
            ref.invalidate(knowledgeCategoriesProvider);
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
                    hintText: 'ابحث عن اسم المرجع، المؤلف، الناشر، أو كلمة مفتاحية...',
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
              categoriesAsync.when(
                data: (allCats) {
                  final sciCategory = allCats.firstWhere(
                    (c) => c.nameAr.contains('المراجع') || c.id == '00000000-0000-0000-0000-000000000007',
                    orElse: () => KnowledgeCategory(id: '', nameAr: 'المراجع العلمية'),
                  );
                  final subcategories = sciCategory.subcategories;

                  return SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildSubcategoryChip(
                          label: 'جميع المراجع',
                          isSelected: _selectedSubcategoryId == null,
                          onTap: () => setState(() => _selectedSubcategoryId = null),
                        ),
                        ...subcategories.map((sub) => _buildSubcategoryChip(
                              label: sub.nameAr,
                              isSelected: _selectedSubcategoryId == sub.id,
                              onTap: () => setState(() => _selectedSubcategoryId = sub.id),
                            )),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox(height: 38),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 10),

              // ── Sorting & Tags Bar ───────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Sort dropdown
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
                          DropdownMenuItem(value: 'views', child: Text('الأكثر مشاهدة 🔥')),
                          DropdownMenuItem(value: 'featured', child: Text('المراجع المميزة ⭐')),
                          DropdownMenuItem(value: 'alphabetical', child: Text('أبجديًا (أ-ي)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedSort = val);
                        },
                      ),
                    ),
                  ),

                  // Tag clear if selected
                  if (_selectedTag != null)
                    InkWell(
                      onTap: () => setState(() => _selectedTag = null),
                      child: Chip(
                        label: Text('وسم: $_selectedTag ✕', style: const TextStyle(fontSize: 11, color: Colors.white)),
                        backgroundColor: AppDesignTokens.primary,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Tags List ────────────────────────────────────────────────
              SizedBox(
                height: 28,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _popularTags.map((tag) {
                    final isSelected = _selectedTag == tag;
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTag = isSelected ? null : tag;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? AppDesignTokens.primary : AppDesignTokens.surface(context),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? AppDesignTokens.primary : AppDesignTokens.border(context),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '#$tag',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

              // ── References Feed ──────────────────────────────────────────
              referencesAsync.when(
                data: (articles) {
                  if (articles.isEmpty) {
                    return const AppCard(
                      padding: EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                      child: AppEmptyState(
                        title: 'لا توجد مراجع علمية متاحة',
                        subtitle: 'لم يتم نشر أي مراجع أو كتب في هذا القسم حتى الآن. سيقوم المشرفون بإضافة المراجع قريباً.',
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
                      return _buildReferenceCard(context, article);
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(color: AppDesignTokens.primary),
                  ),
                ),
                error: (e, _) => AppCard(
                  padding: const EdgeInsets.all(24),
                  child: AppEmptyState(
                    title: 'تعذر تحميل المراجع',
                    subtitle: '$e\nيرجى التحقق من اتصالك بالإنترنت والسحب لأسفل لتحديث الصفحة.',
                    icon: Icons.wifi_off_rounded,
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

  Widget _buildReferenceCard(BuildContext context, KnowledgeArticle article) {
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
              // PDF Icon / Cover Thumbnail
              Container(
                width: 52,
                height: 64,
                decoration: BoxDecoration(
                  color: AppDesignTokens.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppDesignTokens.primary.withOpacity(0.2)),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.picture_as_pdf_rounded, color: AppDesignTokens.danger, size: 28),
                    SizedBox(height: 2),
                    Text('PDF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppDesignTokens.danger)),
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
                          '⭐ مرجع مميز',
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
                    const SizedBox(height: 4),
                    Text(
                      'المؤلف: ${article.displayAuthor}',
                      style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context)),
                    ),
                    if (article.subcategoryName != null && article.subcategoryName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'القسم: ${article.subcategoryName}',
                          style: const TextStyle(fontSize: 11.5, color: AppDesignTokens.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
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

          // Badges row: Pages, Size, Views, Progress
          Row(
            children: [
              if (article.pageCount != null && article.pageCount! > 0)
                _buildInfoBadge(Icons.auto_stories_rounded, '${article.pageCount} صفحة'),
              if (article.formattedFileSize.isNotEmpty) ...[
                const SizedBox(width: 8),
                _buildInfoBadge(Icons.file_present_rounded, article.formattedFileSize),
              ],
              const SizedBox(width: 8),
              _buildInfoBadge(Icons.remove_red_eye_outlined, '${article.viewsCount} مشاهدة'),
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
                    ? 'متابعة القراءة (صفحة ${progress.lastPage})'
                    : 'فتح المرجع 📖',
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
