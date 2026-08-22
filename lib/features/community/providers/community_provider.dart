import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/community_comment.dart';
import '../models/community_post.dart';
import '../repositories/community_repository.dart';

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepository();
});

final communityPostsProvider = FutureProvider<List<CommunityPost>>((ref) async {
  final repo = ref.watch(communityRepositoryProvider);
  return await repo.fetchPosts();
});

final postCommentsProvider =
    FutureProvider.family<List<CommunityComment>, String>((ref, postId) async {
  final repo = ref.watch(communityRepositoryProvider);
  return await repo.fetchComments(postId);
});
