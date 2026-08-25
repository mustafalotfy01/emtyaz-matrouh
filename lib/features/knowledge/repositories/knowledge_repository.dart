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

  // ── CATEGORIES & SUBCATEGORIES ──────────────────────────────────────────────

  /// Fixed UUID for the Study Files / References main category
  static const String studyFilesParentId = '00000000-0000-0000-0000-000000000007';

  /// Ensures the parent "ملفات المذاكرة" category exists in the database
  Future<String> ensureStudyParentCategory() async {
    try {
      final res = await _client
          .from('knowledge_categories')
          .select('id, name_ar')
          .or('id.eq.$studyFilesParentId,name_ar.ilike.%ملفات المذاكرة%,name_ar.ilike.%المراجع%')
          .limit(1);

      if ((res as List).isNotEmpty) {
        return res.first['id'].toString();
      }

      // Create study files parent category if not found
      final inserted = await _client.from('knowledge_categories').insert({
        'id': studyFilesParentId,
        'name_ar': 'ملفات المذاكرة',
        'description': 'ملفات PDF تعليمية وشروحات تخصصية لطلاب الامتياز',
        'icon_name': 'menu_book',
        'order_index': 7,
        'is_active': true,
        'parent_id': null,
      }).select('id').single();

      return inserted['id'].toString();
    } catch (e) {
      if (kDebugMode) print('[KnowledgeRepository] ensureStudyParentCategory error: $e');
      return studyFilesParentId;
    }
  }

  /// Fetch all sections dedicated to Study Files
  Future<List<KnowledgeCategory>> fetchStudySections({bool includeInactive = false}) async {
    try {
      final parentId = await ensureStudyParentCategory();

      PostgrestFilterBuilder query = _client.from('knowledge_categories').select();

      if (!includeInactive) {
        query = query.eq('is_active', true);
      }

      // Fetch categories with this parent_id
      final res = await query
          .eq('parent_id', parentId)
          .order('order_index', ascending: true);

      final list = (res as List)
          .map((json) => KnowledgeCategory.fromJson(json as Map<String, dynamic>))
          .toList();

      // If no subcategories found under parent, fallback to any non-main category or all active
      if (list.isEmpty) {
        final fallbackQuery = _client.from('knowledge_categories').select();
        final fallbackRes = await (includeInactive ? fallbackQuery : fallbackQuery.eq('is_active', true))
            .not('parent_id', 'is', null)
            .order('order_index', ascending: true);

        return (fallbackRes as List)
            .map((json) => KnowledgeCategory.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      return list;
    } catch (e) {
      if (kDebugMode) print('[KnowledgeRepository] fetchStudySections error: $e');
      return [];
    }
  }

  /// Fetch flat list of categories directly without nested dropping
  Future<List<KnowledgeCategory>> fetchFlatCategories({
    String? parentId,
    bool includeInactive = false,
  }) async {
    try {
      PostgrestFilterBuilder query = _client.from('knowledge_categories').select();

      if (!includeInactive) {
        query = query.eq('is_active', true);
      }

      if (parentId != null && parentId.isNotEmpty) {
        query = query.eq('parent_id', parentId);
      }

      final res = await query.order('order_index', ascending: true);
      return (res as List)
          .map((json) => KnowledgeCategory.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) print('[KnowledgeRepository] fetchFlatCategories error: $e');
      return [];
    }
  }

  /// Fetch all categories structured as a parent -> subcategories hierarchy
  Future<List<KnowledgeCategory>> fetchCategories({bool includeInactive = false}) async {
    try {
      PostgrestFilterBuilder query = _client.from('knowledge_categories').select();

      if (!includeInactive) {
        query = query.eq('is_active', true);
      }

      final res = await query.order('order_index', ascending: true);
      final rawList = (res as List).map((json) => KnowledgeCategory.fromJson(json as Map<String, dynamic>)).toList();

      final mainCategories = rawList.where((c) => c.isMainCategory).toList();
      final subcategories = rawList.where((c) => !c.isMainCategory).toList();

      if (mainCategories.isEmpty && rawList.isNotEmpty) {
        // If all categories were inserted without parent_id, return them as main categories
        return rawList;
      }

      // Build hierarchy
      return mainCategories.map((main) {
        final subs = subcategories.where((s) => s.parentId == main.id).toList();
        return main.copyWith(subcategories: subs);
      }).toList();
    } catch (e) {
      if (kDebugMode) print('[KnowledgeRepository] fetchCategories error: $e');
      return [];
    }
  }

  /// Create category or subcategory (Admin / Doctor)
  Future<KnowledgeCategory> createCategory({
    required String nameAr,
    String? description,
    String iconName = 'menu_book',
    String? parentId,
    int orderIndex = 0,
    bool isActive = true,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      final now = DateTime.now().toIso8601String();

      // If parentId was not provided, default to the Study Files parent ID
      final effectiveParentId = parentId ?? await ensureStudyParentCategory();

      final res = await _client.from('knowledge_categories').insert({
        'name_ar': nameAr.trim(),
        'description': description?.trim(),
        'icon_name': iconName,
        'parent_id': effectiveParentId,
        'order_index': orderIndex,
        'is_active': isActive,
        'created_by': userId,
        'created_at': now,
        'updated_at': now,
      }).select().single();

      return KnowledgeCategory.fromJson(res);
    } catch (e) {
      throw Exception('فشل في إنشاء القسم: $e');
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
      final Map<String, dynamic> updates = {
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (nameAr != null) updates['name_ar'] = nameAr.trim();
      if (description != null) updates['description'] = description.trim();
      if (iconName != null) updates['icon_name'] = iconName;
      if (parentId != null) updates['parent_id'] = parentId;
      if (orderIndex != null) updates['order_index'] = orderIndex;
      if (isActive != null) updates['is_active'] = isActive;

      await _client.from('knowledge_categories').update(updates).eq('id', id);
    } catch (e) {
      throw Exception('فشل في تعديل القسم: $e');
    }
  }

  /// Delete category
  Future<void> deleteCategory(String id) async {
    try {
      // Check if articles are associated with this category
      final checkRes = await _client
          .from('knowledge_articles')
          .select('id')
          .or('category_id.eq.$id,subcategory_id.eq.$id')
          .limit(1);

      if ((checkRes as List).isNotEmpty) {
        throw Exception('لا يمكن حذف القسم لوجود مقالات أو ملفات مرتبطة به. يرجى نقلها أولاً.');
      }

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
        filterQuery = filterQuery.eq('subcategory_id', subcategoryId);
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
    try {
      final authorId = _client.auth.currentUser?.id;
      final now = DateTime.now().toIso8601String();

      final effectiveCategoryId = categoryId ?? (contentType == 'pdf' || contentType == 'scientific_reference' ? studyFilesParentId : null);

      final res = await _client.from('knowledge_articles').insert({
        'title': title.trim(),
        'summary': summary.trim(),
        'content_markdown': contentMarkdown.trim(),
        'type': contentType,
        'content_type': contentType,
        'category_id': effectiveCategoryId,
        'subcategory_id': subcategoryId,
        'drive_file_id': driveFileId,
        'drive_file_url': driveFileUrl,
        'file_name': fileName,
        'file_size_bytes': fileSizeBytes,
        'page_count': pageCount,
        'cover_image_url': coverImageUrl,
        'author_id': authorId,
        'author_name': authorName?.trim(),
        'publisher': publisher?.trim(),
        'publication_year': publicationYear,
        'edition': edition?.trim(),
        'language': language,
        'tags': tags,
        'is_published': isPublished,
        'is_featured': isFeatured,
        'views_count': 0,
        'published_at': isPublished ? now : null,
        'created_at': now,
        'updated_at': now,
      }).select('''
        *,
        author:author_id(id, full_name),
        subcategory:subcategory_id(id, name_ar)
      ''').single();

      return KnowledgeArticle.fromJson(res);
    } catch (e) {
      throw Exception('فشل في حفظ ملف المذاكرة: $e');
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
      final Map<String, dynamic> updates = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (title != null) updates['title'] = title.trim();
      if (summary != null) updates['summary'] = summary.trim();
      if (contentMarkdown != null) updates['content_markdown'] = contentMarkdown.trim();
      if (contentType != null) {
        updates['content_type'] = contentType;
        updates['type'] = contentType;
      }
      if (categoryId != null) updates['category_id'] = categoryId;
      if (subcategoryId != null) updates['subcategory_id'] = subcategoryId;
      if (driveFileId != null) updates['drive_file_id'] = driveFileId;
      if (driveFileUrl != null) updates['drive_file_url'] = driveFileUrl;
      if (fileName != null) updates['file_name'] = fileName;
      if (fileSizeBytes != null) updates['file_size_bytes'] = fileSizeBytes;
      if (pageCount != null) updates['page_count'] = pageCount;
      if (coverImageUrl != null) updates['cover_image_url'] = coverImageUrl;
      if (authorName != null) updates['author_name'] = authorName.trim();
      if (publisher != null) updates['publisher'] = publisher.trim();
      if (publicationYear != null) updates['publication_year'] = publicationYear;
      if (edition != null) updates['edition'] = edition.trim();
      if (language != null) updates['language'] = language;
      if (tags != null) updates['tags'] = tags;
      if (isPublished != null) {
        updates['is_published'] = isPublished;
        if (isPublished) updates['published_at'] = DateTime.now().toIso8601String();
      }
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
