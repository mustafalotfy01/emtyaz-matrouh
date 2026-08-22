import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../models/knowledge_article.dart';

class KnowledgeRepository {
  final SupabaseClient _client;

  KnowledgeRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  /// Fetch published articles with search and filter
  Future<List<KnowledgeArticle>> fetchArticles({
    String? contentType,
    String? query,
    String sort = 'newest',
  }) async {
    try {
      PostgrestFilterBuilder filterQuery = _client
          .from('knowledge_articles')
          .select('''
            *,
            author:author_id(id, full_name)
          ''')
          .eq('is_published', true);

      if (contentType != null && contentType.isNotEmpty && contentType != 'all') {
        filterQuery = filterQuery.eq('content_type', contentType);
      }

      if (query != null && query.trim().isNotEmpty) {
        filterQuery = filterQuery.ilike('title', '%${query.trim()}%');
      }

      final dynamic orderedQuery;
      if (sort == 'featured') {
        orderedQuery = filterQuery.order('is_featured', ascending: false).order('created_at', ascending: false);
      } else {
        orderedQuery = filterQuery.order('created_at', ascending: false);
      }

      final res = await orderedQuery;

      return (res as List)
          .map((json) => KnowledgeArticle.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('فشل في جلب مقالات المكتبة: $e');
    }
  }

  /// Create article (Admin / Doctor)
  Future<KnowledgeArticle> createArticle({
    required String title,
    required String summary,
    required String contentMarkdown,
    required String contentType,
    bool isPublished = true,
    bool isFeatured = false,
  }) async {
    try {
      final authorId = _client.auth.currentUser?.id;
      final now = DateTime.now().toIso8601String();

      final res = await _client
          .from('knowledge_articles')
          .insert({
            'title': title,
            'summary': summary,
            'content_markdown': contentMarkdown,
            'content_type': contentType,
            'type': contentType,
            'author_id': authorId,
            'is_published': isPublished,
            'is_featured': isFeatured,
            'created_at': now,
            'updated_at': now,
          })
          .select('''
            *,
            author:author_id(id, full_name)
          ''')
          .single();

      return KnowledgeArticle.fromJson(res);
    } catch (e) {
      throw Exception('فشل في حفظ المقال: $e');
    }
  }

  /// Update article
  Future<void> updateArticle({
    required String id,
    required String title,
    required String summary,
    required String contentMarkdown,
    required String contentType,
    bool isPublished = true,
    bool isFeatured = false,
  }) async {
    try {
      await _client.from('knowledge_articles').update({
        'title': title,
        'summary': summary,
        'content_markdown': contentMarkdown,
        'content_type': contentType,
        'type': contentType,
        'is_published': isPublished,
        'is_featured': isFeatured,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      throw Exception('فشل في تعديل المقال: $e');
    }
  }

  /// Delete article
  Future<void> deleteArticle(String id) async {
    try {
      await _client.from('knowledge_articles').delete().eq('id', id);
    } catch (e) {
      throw Exception('فشل في حذف المقال: $e');
    }
  }
}
