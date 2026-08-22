import 'package:flutter/foundation.dart';
import '../../../core/services/supabase_service.dart';
import '../models/knowledge_article.dart';

class KnowledgeService {
  KnowledgeService._();

  /// Loads published library articles from Supabase
  static Future<List<KnowledgeArticle>> fetchPublishedArticles() async {
    if (!SupabaseService.isInitialized) return [];

    try {
      final res = await SupabaseService.client
          .from('knowledge_articles')
          .select()
          .eq('is_published', true)
          .order('created_at', ascending: false);

      final list = (res as List).map((json) => KnowledgeArticle.fromJson(json)).toList();
      return list;
    } catch (e) {
      if (kDebugMode) print('[KnowledgeService] fetchPublishedArticles error: $e');
      return [];
    }
  }
}
