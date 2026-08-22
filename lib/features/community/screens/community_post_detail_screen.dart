import 'package:flutter/material.dart';
import '../models/community_post.dart';
import 'post_detail_screen.dart';

/// Clean alias for [PostDetailScreen] to preserve backward compatibility.
class CommunityPostDetailScreen extends StatelessWidget {
  final CommunityPost post;

  const CommunityPostDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return PostDetailScreen(post: post);
  }
}
