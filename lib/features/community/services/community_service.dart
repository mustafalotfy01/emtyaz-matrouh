import 'package:flutter/foundation.dart';
import '../../../core/services/supabase_service.dart';
import '../models/community_comment.dart';
import '../models/community_post.dart';

class CommunityService {
  CommunityService._();

  /// Loads community posts ordered by created_at DESC
  static Future<List<CommunityPost>> fetchPosts() async {
    if (!SupabaseService.isInitialized) return [];

    try {
      final res = await SupabaseService.client
          .from('community_posts')
          .select('*, profiles(full_name, role), community_comments(id)')
          .order('created_at', ascending: false);

      return (res as List).map((json) => CommunityPost.fromJson(json)).toList();
    } catch (e) {
      try {
        final basicRes = await SupabaseService.client
            .from('community_posts')
            .select()
            .order('created_at', ascending: false);

        return (basicRes as List).map((json) => CommunityPost.fromJson(json)).toList();
      } catch (_) {
        if (kDebugMode) print('[CommunityService] fetchPosts error: $e');
        return [];
      }
    }
  }

  /// Loads comments for a specific post
  static Future<List<CommunityComment>> fetchComments(String postId) async {
    if (!SupabaseService.isInitialized) return [];

    try {
      final res = await SupabaseService.client
          .from('community_comments')
          .select('*, profiles(full_name, role)')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      return (res as List).map((json) => CommunityComment.fromJson(json)).toList();
    } catch (e) {
      if (kDebugMode) print('[CommunityService] fetchComments error: $e');
      return [];
    }
  }

  /// Creates a new community post
  static Future<bool> createPost({
    required String authorId,
    required String title,
    required String content,
    required PostCategory category,
    String? imageUrl,
  }) async {
    if (!SupabaseService.isInitialized) return true;

    try {
      final authId = SupabaseService.client.auth.currentUser?.id ?? authorId;
      await SupabaseService.client.from('community_posts').insert({
        'author_id': authId,
        'title': title,
        'content': content,
        'category': category.toDbString(),
        'is_pinned': false,
        'is_featured': false,
        if (imageUrl != null) 'image_url': imageUrl,
      });
      return true;
    } catch (e) {
      if (kDebugMode) print('[CommunityService] createPost error: $e');
      return false;
    }
  }

  /// Adds a comment to a post
  static Future<bool> addComment({
    required String postId,
    required String authorId,
    required String content,
  }) async {
    if (!SupabaseService.isInitialized) return true;

    try {
      await SupabaseService.client.from('community_comments').insert({
        'post_id': postId,
        'author_id': authorId,
        'content': content,
      });
      return true;
    } catch (e) {
      if (kDebugMode) print('[CommunityService] addComment error: $e');
      return false;
    }
  }

  /// Deletes a post (author or admin)
  static Future<bool> deletePost(String postId) async {
    if (!SupabaseService.isInitialized) return true;

    try {
      await SupabaseService.client
          .from('community_posts')
          .delete()
          .eq('id', postId);
      return true;
    } catch (e) {
      if (kDebugMode) print('[CommunityService] deletePost error: $e');
      return false;
    }
  }

  /// Toggles featured status (Staff only)
  static Future<bool> toggleFeatured({required String postId, required bool isFeatured}) async {
    if (!SupabaseService.isInitialized) return true;

    try {
      await SupabaseService.client
          .from('community_posts')
          .update({'is_featured': isFeatured})
          .eq('id', postId);
      return true;
    } catch (e) {
      if (kDebugMode) print('[CommunityService] toggleFeatured error: $e');
      return false;
    }
  }
}
