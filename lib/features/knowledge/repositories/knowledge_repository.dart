import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../models/knowledge_article.dart';
import '../models/knowledge_bookmark.dart';
import '../models/knowledge_category.dart';
import '../models/knowledge_reading_progress.dart';

class KnowledgeRepository {
  final SupabaseClient _client;

  KnowledgeRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  // ── CATEGORIES & SECTIONS ───────────────────────────────────────────────────

  /// Fetch all sections/categories available in the database
  Future<List<KnowledgeCategory>> fetchStudySections({
    String? parentId,
    bool includeInactive = false,
  }) async {
    try {
      // 1. Try structured query with ordering
      dynamic res;
      try {
        PostgrestFilterBuilder query = _client.from('knowledge_categories').select();
        if (!includeInactive) {
          query = query.eq('is_active', true);
        }
        if (parentId != null && parentId.isNotEmpty) {
          query = query.eq('parent_id', parentId);
        }
        res = await query.order('order_index', ascending: true);
      } catch (e) {
        // Fallback to basic select if order_index or is_active column doesn't exist
        res = await _client.from('knowledge_categories').select();
      }

      final rawList = (res as List)
          .map((json) => KnowledgeCategory.fromJson(json as Map<String, dynamic>))
          .toList();

      if (rawList.isEmpty) return [];

      // If specific parentId requested, return matching items
      if (parentId != null && parentId.isNotEmpty) {
        return rawList;
      }

      // Umbrella root containers to exclude if present
      const rootUmbrellas = {'المكتبة السريرية', 'المراجع العلمية'};

      // Return both subcategories AND top-level custom sections (excluding root umbrella names)
      final sections = rawList.where((c) {
        final name = c.nameAr.trim();
        return !rootUmbrellas.contains(name);
      }).toList();

      return sections.isNotEmpty ? sections : rawList;
    } catch (e) {
      if (kDebugMode) print('[KnowledgeRepository] fetchStudySections error: $e');
      return [];
    }
  }

  /// Fetch flat list of categories directly
  Future<List<KnowledgeCategory>> fetchFlatCategories({
    String? parentId,
    bool includeInactive = false,
  }) async {
    return await fetchStudySections(parentId: parentId, includeInactive: includeInactive);
  }

  /// Fetch all categories structured as a parent -> subcategories hierarchy
  Future<List<KnowledgeCategory>> fetchCategories({bool includeInactive = false}) async {
    try {
      dynamic res;
      try {
        PostgrestFilterBuilder query = _client.from('knowledge_categories').select();
        if (!includeInactive) {
          query = query.eq('is_active', true);
        }
        res = await query.order('order_index', ascending: true);
      } catch (_) {
        res = await _client.from('knowledge_categories').select();
      }

      final rawList = (res as List).map((json) => KnowledgeCategory.fromJson(json as Map<String, dynamic>)).toList();

      final mainCategories = rawList.where((c) => c.isMainCategory).toList();
      final subcategories = rawList.where((c) => !c.isMainCategory).toList();

      if (mainCategories.isEmpty) {
        return rawList;
      }

      return mainCategories.map((main) {
        final subs = subcategories.where((s) => s.parentId == main.id).toList();
        return main.copyWith(subcategories: subs);
      }).toList();
    } catch (e) {
      if (kDebugMode) print('[KnowledgeRepository] fetchCategories error: $e');
      return [];
    }
  }

  /// Create category with adaptive schema fallback
  Future<KnowledgeCategory> createCategory({
    required String nameAr,
    String? description,
    String iconName = 'menu_book',
    String? parentId,
    int orderIndex = 0,
    bool isActive = true,
  }) async {
    final name = nameAr.trim();
    if (name.isEmpty) throw Exception('اسم القسم لا يمكن أن يكون فارغاً');

    final userId = _client.auth.currentUser?.id;

    // 1. Try full payload insert
    try {
      final Map<String, dynamic> payload = {
        'name_ar': name,
        'icon_name': iconName,
        'order_index': orderIndex,
        'is_active': isActive,
      };
      if (description != null && description.trim().isNotEmpty) {
        payload['description'] = description.trim();
      }
      if (parentId != null && parentId.isNotEmpty) {
        payload['parent_id'] = parentId;
      }
      if (userId != null) {
        payload['created_by'] = userId;
      }

      final res = await _client.from('knowledge_categories').insert(payload).select().single();
      return KnowledgeCategory.fromJson(res);
    } catch (e) {
      if (kDebugMode) print('[KnowledgeRepository] createCategory full payload error: $e, trying fallback payload');

      // 2. Fallback to basic payload without created_by / order_index
      try {
        final Map<String, dynamic> fallbackPayload = {
          'name_ar': name,
          'icon_name': iconName,
          'is_active': isActive,
        };
        if (description != null && description.trim().isNotEmpty) {
          fallbackPayload['description'] = description.trim();
        }
        if (parentId != null && parentId.isNotEmpty) {
          fallbackPayload['parent_id'] = parentId;
        }

        final res = await _client.from('knowledge_categories').insert(fallbackPayload).select().single();
        return KnowledgeCategory.fromJson(res);
      } catch (e2) {
        // 3. Fallback to minimal schema columns
        try {
          final res = await _client.from('knowledge_categories').insert({
            'name_ar': name,
            'icon_name': iconName,
          }).select().single();
          return KnowledgeCategory.fromJson(res);
        } catch (e3) {
          throw Exception('فشل في إضافة القسم في قاعدة البيانات: $e3');
        }
      }
    }
  }

  /// Update category
  Future<void> updateCategory({
    required String id,
    String? nameAr,
    String? description,
    String? iconName,
    String? parentId,
    int? orderIndex,
    bool? isActive,
  }) async {
    try {
      final Map<String, dynamic> updates = {};
      if (nameAr != null) updates['name_ar'] = nameAr.trim();
      if (description != null) updates['description'] = description.trim();
      if (iconName != null) updates['icon_name'] = iconName;
      if (parentId != null) updates['parent_id'] = parentId;
      if (orderIndex != null) updates['order_index'] = orderIndex;
      if (isActive != null) updates['is_active'] = isActive;

      await _client.from('knowledge_categories').update(updates).eq('id', id);
    } catch (e) {
      // If extended columns fail, try updating only name_ar
      if (nameAr != null) {
        await _client.from('knowledge_categories').update({'name_ar': nameAr.trim()}).eq('id', id);
      } else {
        throw Exception('فشل في تعديل القسم: $e');
      }
    }
  }

  /// Delete category
  Future<void> deleteCategory(String id) async {
    try {
      // Check if articles are associated with this category
      try {
        final checkRes = await _client
            .from('knowledge_articles')
            .select('id')
            .or('category_id.eq.$id,subcategory_id.eq.$id')
            .limit(1);

        if ((checkRes as List).isNotEmpty) {
          throw Exception('لا يمكن حذف القسم لوجود مقالات أو ملفات مرتبطة به. يرجى نقلها أولاً.');
        }
      } catch (_) {}

      await _client.from('knowledge_categories').delete().eq('id', id);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ── ARTICLES & STUDY FILES (PDF) ─────────────────────────────────────────────

  /// Fetch articles with filtering, search, and sorting
  Future<List<KnowledgeArticle>> fetchArticles({
    String? categoryId,
    String? subcategoryId,
    String? contentType,
    String? query,
    String? tag,
    bool? isFeatured,
    bool? isPublished = true,
    String sort = 'newest',
    int limit = 100,
  }) async {
    try {
      PostgrestFilterBuilder filterQuery = _client.from('knowledge_articles').select('''
        *,
        author:author_id(id, full_name),
        subcategory:subcategory_id(id, name_ar)
      ''');

      if (isPublished != null) {
        filterQuery = filterQuery.eq('is_published', isPublished);
      }

      if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
        filterQuery = filterQuery.eq('category_id', categoryId);
      }

      if (subcategoryId != null && subcategoryId.isNotEmpty && subcategoryId != 'all') {
        filterQuery = filterQuery.or('subcategory_id.eq.$subcategoryId,category_id.eq.$subcategoryId');
      }

      if (contentType != null && contentType.isNotEmpty && contentType != 'all') {
        if (contentType == 'scientific_reference' || contentType == 'pdf') {
          filterQuery = filterQuery.or('content_type.eq.scientific_reference,content_type.eq.pdf,type.eq.scientific_reference,type.eq.pdf');
        } else {
          filterQuery = filterQuery.or('content_type.eq.$contentType,type.eq.$contentType');
        }
      }

      if (isFeatured == true) {
        filterQuery = filterQuery.eq('is_featured', true);
      }

      if (tag != null && tag.isNotEmpty) {
        filterQuery = filterQuery.contains('tags', [tag]);
      }

      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim();
        filterQuery = filterQuery.or('title.ilike.%$q%,summary.ilike.%$q%');
      }

      final dynamic orderedQuery;
      switch (sort) {
        case 'views':
          orderedQuery = filterQuery.order('views_count', ascending: false).order('created_at', ascending: false);
          break;
        case 'alphabetical':
          orderedQuery = filterQuery.order('title', ascending: true);
          break;
        case 'featured':
          orderedQuery = filterQuery.order('is_featured', ascending: false).order('created_at', ascending: false);
          break;
        case 'newest':
        default:
          orderedQuery = filterQuery.order('created_at', ascending: false);
          break;
      }

      final res = await orderedQuery.limit(limit);

      return (res as List)
          .map((json) => KnowledgeArticle.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) print('[KnowledgeRepository] fetchArticles error: $e');
      return [];
    }
  }

  /// Create Article / Study File PDF
  Future<KnowledgeArticle> createArticle({
    required String title,
    required String summary,
    required String contentMarkdown,
    required String contentType,
    String? categoryId,
    String? subcategoryId,
    String? driveFileId,
    String? driveFileUrl,
    String? fileName,
    int? fileSizeBytes,
    int? pageCount,
    String? coverImageUrl,
    String? authorName,
    String? publisher,
    int? publicationYear,
    String? edition,
    String language = 'العربية',
    List<String> tags = const [],
    bool isPublished = true,
    bool isFeatured = false,
  }) async {
    final authorId = _client.auth.currentUser?.id;
    final now = DateTime.now().toIso8601String();

    final Map<String, dynamic> payload = {
      'title': title.trim(),
      'summary': summary.trim(),
      'content_markdown': contentMarkdown.trim(),
      'type': contentType,
      'is_published': isPublished,
      'views_count': 0,
      'created_at': now,
    };

    if (authorId != null) payload['author_id'] = authorId;
    if (categoryId != null && categoryId.isNotEmpty) payload['category_id'] = categoryId;
    if (subcategoryId != null && subcategoryId.isNotEmpty) {
      payload['subcategory_id'] = subcategoryId;
      if (payload['category_id'] == null) payload['category_id'] = subcategoryId;
    }
    if (driveFileId != null && driveFileId.isNotEmpty) payload['drive_file_id'] = driveFileId;
    if (driveFileUrl != null && driveFileUrl.isNotEmpty) payload['drive_file_url'] = driveFileUrl;
    if (fileName != null && fileName.isNotEmpty) payload['file_name'] = fileName;
    if (fileSizeBytes != null && fileSizeBytes > 0) payload['file_size_bytes'] = fileSizeBytes;
    if (pageCount != null && pageCount > 0) payload['page_count'] = pageCount;
    if (authorName != null && authorName.trim().isNotEmpty) payload['author_name'] = authorName.trim();
    if (isFeatured) payload['is_featured'] = true;
    if (tags.isNotEmpty) payload['tags'] = tags;

    // 1. Try insert with full clean payload
    try {
      final res = await _client.from('knowledge_articles').insert(payload).select('''
        *,
        author:author_id(id, full_name),
        subcategory:subcategory_id(id, name_ar)
      ''').single();

      return KnowledgeArticle.fromJson(res);
    } catch (e) {
      if (kDebugMode) print('[KnowledgeRepository] createArticle full insert error: $e, trying simple select');

      // 2. Try simpler insert without joins in case foreign key join fails
      try {
        final res = await _client.from('knowledge_articles').insert(payload).select().single();
        return KnowledgeArticle.fromJson(res);
      } catch (e2) {
        if (kDebugMode) print('[KnowledgeRepository] createArticle simple insert error: $e2, trying minimal payload');

        // 3. Fallback to basic schema columns only
        try {
          final minimalPayload = {
            'title': title.trim(),
            'summary': summary.trim(),
            'content_markdown': contentMarkdown.trim(),
            'type': contentType,
            'category_id': categoryId ?? subcategoryId,
            'is_published': isPublished,
          };
          if (authorId != null) minimalPayload['author_id'] = authorId;

          final res = await _client.from('knowledge_articles').insert(minimalPayload).select().single();
          return KnowledgeArticle.fromJson(res);
        } catch (e3) {
          throw Exception('فشل في حفظ ملف المذاكرة: $e3');
        }
      }
    }
  }

  /// Update Article / Study File
  Future<void> updateArticle({
    required String id,
    String? title,
    String? summary,
    String? contentMarkdown,
    String? contentType,
    String? categoryId,
    String? subcategoryId,
    String? driveFileId,
    String? driveFileUrl,
    String? fileName,
    int? fileSizeBytes,
    int? pageCount,
    String? coverImageUrl,
    String? authorName,
    String? publisher,
    int? publicationYear,
    String? edition,
    String? language,
    List<String>? tags,
    bool? isPublished,
    bool? isFeatured,
  }) async {
    try {
      final Map<String, dynamic> updates = {};

      if (title != null) updates['title'] = title.trim();
      if (summary != null) updates['summary'] = summary.trim();
      if (contentMarkdown != null) updates['content_markdown'] = contentMarkdown.trim();
      if (contentType != null) updates['type'] = contentType;
      if (categoryId != null) updates['category_id'] = categoryId;
      if (subcategoryId != null) updates['subcategory_id'] = subcategoryId;
      if (driveFileId != null) updates['drive_file_id'] = driveFileId;
      if (driveFileUrl != null) updates['drive_file_url'] = driveFileUrl;
      if (fileName != null) updates['file_name'] = fileName;
      if (fileSizeBytes != null) updates['file_size_bytes'] = fileSizeBytes;
      if (pageCount != null) updates['page_count'] = pageCount;
      if (authorName != null) updates['author_name'] = authorName.trim();
      if (tags != null) updates['tags'] = tags;
      if (isPublished != null) updates['is_published'] = isPublished;
      if (isFeatured != null) updates['is_featured'] = isFeatured;

      await _client.from('knowledge_articles').update(updates).eq('id', id);
    } catch (e) {
      throw Exception('فشل في تحديث ملف المذاكرة: $e');
    }
  }

  /// Delete article
  Future<void> deleteArticle(String id) async {
    try {
      await _client.from('knowledge_articles').delete().eq('id', id);
    } catch (e) {
      throw Exception('فشل في حذف المحتوى: $e');
    }
  }

  /// Safe server-side increment of article view count
  Future<int> incrementViewsCount(String articleId) async {
    try {
      final res = await _client.rpc('increment_article_view', params: {
        'p_article_id': articleId,
      });
      return (res as num?)?.toInt() ?? 0;
    } catch (e) {
      if (kDebugMode) print('[KnowledgeRepository] incrementViewsCount error: $e');
      return 0;
    }
  }

  // ── READING PROGRESS & BOOKMARKS ────────────────────────────────────────────

  /// Fetch user's reading progress for a specific article
  Future<KnowledgeReadingProgress?> fetchReadingProgress(String articleId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final res = await _client
          .from('knowledge_reading_progress')
          .select()
          .eq('user_id', userId)
          .eq('article_id', articleId)
          .maybeSingle();

      if (res == null) return null;
      return KnowledgeReadingProgress.fromJson(res);
    } catch (e) {
      if (kDebugMode) print('[KnowledgeRepository] fetchReadingProgress error: $e');
      return null;
    }
  }

  /// Save reading progress
  Future<void> saveReadingProgress({
    required String articleId,
    required int lastPage,
    int? totalPages,
    double? percentage,
  }) async {
    try {
      await _client.rpc('save_reading_progress', params: {
        'p_article_id': articleId,
        'p_page': lastPage,
        'p_total_pages': totalPages,
        'p_percentage': percentage,
      });
    } catch (e) {
      if (kDebugMode) print('[KnowledgeRepository] saveReadingProgress error: $e');
    }
  }

  /// Fetch user's page bookmarks for an article
  Future<List<KnowledgeBookmark>> fetchBookmarks(String articleId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final res = await _client
          .from('knowledge_bookmarks')
          .select()
          .eq('user_id', userId)
          .eq('article_id', articleId)
          .order('page_number', ascending: true);

      return (res as List)
          .map((json) => KnowledgeBookmark.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) print('[KnowledgeRepository] fetchBookmarks error: $e');
      return [];
    }
  }

  /// Toggle page bookmark
  Future<bool> toggleBookmark({
    required String articleId,
    int pageNumber = 1,
    String? note,
  }) async {
    try {
      final res = await _client.rpc('toggle_article_bookmark', params: {
        'p_article_id': articleId,
        'p_page': pageNumber,
        'p_note': note,
      });
      return res == true;
    } catch (e) {
      if (kDebugMode) print('[KnowledgeRepository] toggleBookmark error: $e');
      return false;
    }
  }

  /// Fetch user's all bookmarked references for the "المراجع المحفوظة" section
  Future<List<KnowledgeArticle>> fetchUserBookmarkedArticles() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final res = await _client
          .from('knowledge_bookmarks')
          .select('article:article_id(*, author:author_id(id, full_name), subcategory:subcategory_id(id, name_ar))')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<KnowledgeArticle> list = [];
      final Set<String> seenIds = {};

      for (final item in (res as List)) {
        if (item['article'] is Map) {
          final a = KnowledgeArticle.fromJson(item['article'] as Map<String, dynamic>);
          if (!seenIds.contains(a.id)) {
            seenIds.add(a.id);
            list.add(a);
          }
        }
      }
      return list;
    } catch (e) {
      if (kDebugMode) print('[KnowledgeRepository] fetchUserBookmarkedArticles error: $e');
      return [];
    }
  }
}
