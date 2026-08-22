import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/knowledge_article.dart';
import '../repositories/knowledge_repository.dart';

final knowledgeRepositoryProvider = Provider<KnowledgeRepository>((ref) {
  return KnowledgeRepository();
});

final knowledgeArticlesProvider = FutureProvider<List<KnowledgeArticle>>((ref) async {
  final repo = ref.watch(knowledgeRepositoryProvider);
  return await repo.fetchArticles();
});

final filteredKnowledgeArticlesProvider =
    FutureProvider.family<List<KnowledgeArticle>, Map<String, String?>>((ref, params) async {
  final repo = ref.watch(knowledgeRepositoryProvider);
  return await repo.fetchArticles(
    contentType: params['contentType'],
    query: params['query'],
    sort: params['sort'] ?? 'newest',
  );
});
