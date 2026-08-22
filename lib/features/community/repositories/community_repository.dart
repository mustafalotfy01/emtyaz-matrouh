import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../models/community_comment.dart';
import '../models/community_post.dart';

class CommunityRepository {
  final SupabaseClient _client;

  CommunityRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  /// Fetch paginated community feed with featured posts first
  Future<List<CommunityPost>> fetchPosts({
    int page = 0,
    int pageSize = 15,
  }) async {
    try {
      final from = page * pageSize;
      final to = from + pageSize - 1;

      final res = await _client
          .from('community_posts')
          .select('''
            *,
            author:author_id(id, full_name, role, university_code),
            comments:community_comments(id)
          ''')
          .order('created_at', ascending: false)
          .range(from, to);

      return (res as List)
          .map((json) => CommunityPost.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      try {
        final basicRes = await _client
            .from('community_posts')
            .select()
            .order('created_at', ascending: false);

        return (basicRes as List)
            .map((json) => CommunityPost.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  /// Create new community post (Student / Doctor / Admin)
  Future<CommunityPost> createPost({
    required String title,
    required String content,
    String category = 'general',
    String? imageUrl,
    String? authorId,
  }) async {
    try {
      final effectiveAuthorId = authorId ?? _client.auth.currentUser?.id;
      final now = DateTime.now().toIso8601String();

      final res = await _client
          .from('community_posts')
          .insert({
            if (effectiveAuthorId != null) 'author_id': effectiveAuthorId,
            'title': title,
            'content': content,
            'category': category,
            'image_url': imageUrl,
            'is_featured': false,
            'is_pinned': false,
            'created_at': now,
            'updated_at': now,
          })
          .select('''
            *,
            author:author_id(id, full_name, role, university_code)
          ''')
          .single();

      return CommunityPost.fromJson(res);
    } catch (e) {
      throw Exception('فشل في نشر المشاركة: $e');
    }
  }

  /// Toggle Gold / Featured status for post (Doctor / Admin / Leader)
  Future<void> toggleGoldPost(String postId, bool isGold) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      await _client.from('community_posts').update({
        'is_featured': isGold,
        'is_pinned': isGold,
        'featured_at': isGold ? DateTime.now().toIso8601String() : null,
        'featured_by': isGold ? currentUserId : null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', postId);
    } catch (e) {
      throw Exception('فشل في تغيير حالة التمييز الذهبي: $e');
    }
  }

  /// Toggle featured status for post (Doctor / Admin only)
  Future<void> toggleFeaturePost(String postId, bool isFeatured) async {
    return toggleGoldPost(postId, isFeatured);
  }

  /// Delete post
  Future<void> deletePost(String postId) async {
    try {
      await _client.from('community_posts').delete().eq('id', postId);
    } catch (e) {
      throw Exception('فشل في حذف المشاركة: $e');
    }
  }

  /// Fetch comments for post
  Future<List<CommunityComment>> fetchComments(String postId) async {
    try {
      final res = await _client
          .from('community_comments')
          .select('''
            *,
            author:author_id(id, full_name, role, avatar_url, university_code)
          ''')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      return (res as List)
          .map((json) => CommunityComment.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('فشل في جلب التعليقات: $e');
    }
  }

  /// Add comment to post
  Future<CommunityComment> addComment(String postId, String content) async {
    try {
      final authorId = _client.auth.currentUser?.id;
      final now = DateTime.now().toIso8601String();

      final res = await _client
          .from('community_comments')
          .insert({
            'post_id': postId,
            'author_id': authorId,
            'content': content,
            'created_at': now,
            'updated_at': now,
          })
          .select('''
            *,
            author:author_id(id, full_name, role, avatar_url, university_code)
          ''')
          .single();

      return CommunityComment.fromJson(res);
    } catch (e) {
      throw Exception('فشل في إضافة التعليق: $e');
    }
  }

  /// Reward a comment with recognition and points (Supervisor action)
  Future<void> rewardComment({
    required String commentId,
    required String currentContent,
    String rewardTitle = 'إجابة متميزة ومكافأة من المشرف 🏆 (+10 نقاط)',
  }) async {
    try {
      String newContent = currentContent;
      if (!newContent.contains('[REWARD:')) {
        newContent = '[REWARD:$rewardTitle]\n$newContent';
      }
      await _client.from('community_comments').update({
        'content': newContent,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', commentId);
    } catch (e) {
      throw Exception('فشل في منح مكافأة التميز للتعليق: $e');
    }
  }
}
