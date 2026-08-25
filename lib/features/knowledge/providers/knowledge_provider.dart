import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/knowledge_article.dart';
import '../models/knowledge_bookmark.dart';
import '../models/knowledge_category.dart';
import '../models/knowledge_reading_progress.dart';
import '../repositories/knowledge_repository.dart';

final knowledgeRepositoryProvider = Provider<KnowledgeRepository>((ref) {
  return KnowledgeRepository();
});

/// Immutable filter class for Study Files / References to guarantee Riverpod parameter equality
class StudyFilesFilter {
  final String? subcategoryId;
  final String? query;
  final String? tag;
  final String sort;
  final bool? isFeatured;

  const StudyFilesFilter({
    this.subcategoryId,
    this.query,
    this.tag,
    this.sort = 'newest',
    this.isFeatured,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudyFilesFilter &&
          runtimeType == other.runtimeType &&
          subcategoryId == other.subcategoryId &&
          query == other.query &&
          tag == other.tag &&
          sort == other.sort &&
          isFeatured == other.isFeatured;

  @override
  int get hashCode => Object.hash(subcategoryId, query, tag, sort, isFeatured);
}

/// Dynamic sections dedicated to Study Files (ملفات المذاكرة)
final studySectionsProvider = FutureProvider<List<KnowledgeCategory>>((ref) async {
  final repo = ref.watch(knowledgeRepositoryProvider);
  return await repo.fetchStudySections(includeInactive: false);
});

/// Admin all study sections (including inactive)
final adminStudySectionsProvider = FutureProvider<List<KnowledgeCategory>>((ref) async {
  final repo = ref.watch(knowledgeRepositoryProvider);
  return await repo.fetchStudySections(includeInactive: true);
});

/// All Categories hierarchy (Main categories + subcategories)
final knowledgeCategoriesProvider = FutureProvider<List<KnowledgeCategory>>((ref) async {
  final repo = ref.watch(knowledgeRepositoryProvider);
  return await repo.fetchCategories();
});

/// Admin all categories (including inactive)
final adminKnowledgeCategoriesProvider = FutureProvider<List<KnowledgeCategory>>((ref) async {
  final repo = ref.watch(knowledgeRepositoryProvider);
  return await repo.fetchCategories(includeInactive: true);
});

/// All published articles feed
final knowledgeArticlesProvider = FutureProvider<List<KnowledgeArticle>>((ref) async {
  final repo = ref.watch(knowledgeRepositoryProvider);
  return await repo.fetchArticles();
});

/// Featured study files & articles
final featuredKnowledgeArticlesProvider = FutureProvider<List<KnowledgeArticle>>((ref) async {
  final repo = ref.watch(knowledgeRepositoryProvider);
  return await repo.fetchArticles(isFeatured: true, limit: 10);
});

/// Dedicated Study Files (PDF) list with value-equal filters
final studyFilesProvider = FutureProvider.family<List<KnowledgeArticle>, StudyFilesFilter>((ref, filter) async {
  final repo = ref.watch(knowledgeRepositoryProvider);
  return await repo.fetchArticles(
    contentType: 'pdf',
    subcategoryId: filter.subcategoryId,
    query: filter.query,
    tag: filter.tag,
    isFeatured: filter.isFeatured,
    sort: filter.sort,
    limit: 100,
  );
});

/// Backward-compatible alias for scientific references
final scientificReferencesProvider = FutureProvider.family<List<KnowledgeArticle>, StudyFilesFilter>((ref, filter) async {
  final repo = ref.watch(knowledgeRepositoryProvider);
  return await repo.fetchArticles(
    contentType: 'scientific_reference',
    subcategoryId: filter.subcategoryId,
    query: filter.query,
    tag: filter.tag,
    isFeatured: filter.isFeatured,
    sort: filter.sort,
    limit: 100,
  );
});

/// Filtered knowledge articles for general library browsing
final filteredKnowledgeArticlesProvider =
    FutureProvider.family<List<KnowledgeArticle>, Map<String, String?>>((ref, params) async {
  final repo = ref.watch(knowledgeRepositoryProvider);
  return await repo.fetchArticles(
    categoryId: params['categoryId'],
    subcategoryId: params['subcategoryId'],
    contentType: params['contentType'],
    query: params['query'],
    tag: params['tag'],
    sort: params['sort'] ?? 'newest',
  );
});

/// User's bookmarked references list
final userBookmarkedArticlesProvider = FutureProvider<List<KnowledgeArticle>>((ref) async {
  final repo = ref.watch(knowledgeRepositoryProvider);
  return await repo.fetchUserBookmarkedArticles();
});

/// Reading progress for a specific article
final articleReadingProgressProvider =
    FutureProvider.family<KnowledgeReadingProgress?, String>((ref, articleId) async {
  final repo = ref.watch(knowledgeRepositoryProvider);
  return await repo.fetchReadingProgress(articleId);
});

/// Page bookmarks for a specific article
final articleBookmarksProvider =
    FutureProvider.family<List<KnowledgeBookmark>, String>((ref, articleId) async {
  final repo = ref.watch(knowledgeRepositoryProvider);
  return await repo.fetchBookmarks(articleId);
});
