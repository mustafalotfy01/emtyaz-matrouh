class CommunityComment {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String authorRole;
  final String? authorAvatarUrl;
  final String? authorCode;
  final String content;
  final bool isRewarded;
  final String? rewardTitle;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CommunityComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    this.authorAvatarUrl,
    this.authorCode,
    required this.content,
    this.isRewarded = false,
    this.rewardTitle,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isStaff =>
      authorRole == 'evaluating_doctor' ||
      authorRole == 'super_admin' ||
      authorRole == 'leader';

  String get roleBadgeLabel {
    switch (authorRole) {
      case 'super_admin':
        return 'الإدارة العليا ⭐';
      case 'evaluating_doctor':
        return 'طبيب مقيّـم 🩺';
      case 'leader':
        return 'ليدر 📋';
      case 'student':
      default:
        return 'طالب امتياز 🎓';
    }
  }

  String get displayContent {
    if (content.contains('[REWARD:')) {
      final endIdx = content.indexOf(']');
      if (endIdx != -1) {
        return content.substring(endIdx + 1).trim();
      }
    }
    return content;
  }

  factory CommunityComment.fromJson(Map<String, dynamic> json) {
    String aName = 'مستخدم';
    String aRole = 'student';
    String? aAvatar;
    String? aCode;

    if (json['author'] != null && json['author'] is Map) {
      final map = json['author'] as Map;
      aName = map['full_name']?.toString() ?? aName;
      aRole = map['role']?.toString() ?? aRole;
      aAvatar = map['avatar_url']?.toString();
      aCode = map['university_code']?.toString();
    } else if (json['profiles'] != null && json['profiles'] is Map) {
      final map = json['profiles'] as Map;
      aName = map['full_name']?.toString() ?? aName;
      aRole = map['role']?.toString() ?? aRole;
      aAvatar = map['avatar_url']?.toString();
      aCode = map['university_code']?.toString();
    }

    final rawContent = json['content']?.toString() ?? '';
    bool rewarded = json['is_rewarded'] == true || rawContent.contains('[REWARD:');
    String? rewardTitle;
    if (rawContent.contains('[REWARD:')) {
      final start = rawContent.indexOf('[REWARD:') + 8;
      final end = rawContent.indexOf(']', start);
      if (end != -1) {
        rewardTitle = rawContent.substring(start, end).trim();
      }
    }

    return CommunityComment(
      id: json['id'] ?? '',
      postId: json['post_id'] ?? '',
      authorId: json['author_id'] ?? '',
      authorName: json['author_name'] ?? aName,
      authorRole: json['author_role'] ?? aRole,
      authorAvatarUrl: json['author_avatar_url'] ?? aAvatar,
      authorCode: json['author_code'] ?? aCode,
      content: rawContent,
      isRewarded: rewarded,
      rewardTitle: rewardTitle ?? (rewarded ? 'إجابة متميزة معتمدة ومكافأة من المشرف 🏆 (+10 نقاط)' : null),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) ?? DateTime.now() : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }
}
