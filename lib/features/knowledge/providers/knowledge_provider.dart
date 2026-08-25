import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/knowledge_article.dart';
import '../models/knowledge_bookmark.dart';
import '../models/knowledge_category.dart';
import '../models/knowledge_reading_progress.dart';
import '../repositories/knowledge_repository.dart';

final knowledgeRepositoryProvider = Provider<KnowledgeRepository>((ref) {
  return KnowledgeRepository();
});

/// Categories hierarchy (Main categories + subcategories)
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

/// Featured scientific references & articles
final featuredKnowledgeArticlesProvider = FutureProvider<List<KnowledgeArticle>>((ref) async {
  final repo = ref.watch(knowledgeRepositoryProvider);
  return await repo.fetchArticles(isFeatured: true, limit: 10);
});

/// Dedicated Scientific References PDF list with dynamic filters
final scientificReferencesProvider = FutureProvider.family<List<KnowledgeArticle>, Map<String, dynamic>>((ref, params) async {
  final repo = ref.watch(knowledgeRepositoryProvider);
  return await repo.fetchArticles(
    contentType: 'scientific_reference',
    subcategoryId: params['subcategoryId']?.toString(),
    query: params['query']?.toString(),
    tag: params['tag']?.toString(),
    isFeatured: params['isFeatured'] == true ? true : null,
    sort: params['sort']?.toString() ?? 'newest',
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
