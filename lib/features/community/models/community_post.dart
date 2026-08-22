enum PostCategory {
  general,
  announcement,
  caseStudy,
  emergency,
  shiftUpdate,
  educational;

  String get displayNameAr {
    switch (this) {
      case PostCategory.general:
        return 'عام';
      case PostCategory.announcement:
        return 'إعلان رسمي';
      case PostCategory.caseStudy:
        return 'دراسة حالة';
      case PostCategory.emergency:
        return 'طوارئ';
      case PostCategory.shiftUpdate:
        return 'تبادل شيفت';
      case PostCategory.educational:
        return 'معلومة سريرية';
    }
  }

  static PostCategory fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'announcement':
        return PostCategory.announcement;
      case 'case_study':
      case 'casestudy':
        return PostCategory.caseStudy;
      case 'emergency':
        return PostCategory.emergency;
      case 'shift_update':
      case 'shiftupdate':
        return PostCategory.shiftUpdate;
      case 'educational':
        return PostCategory.educational;
      case 'general':
      default:
        return PostCategory.general;
    }
  }

  String toDbString() {
    switch (this) {
      case PostCategory.announcement:
        return 'announcement';
      case PostCategory.caseStudy:
        return 'case_study';
      case PostCategory.emergency:
        return 'emergency';
      case PostCategory.shiftUpdate:
        return 'shift_update';
      case PostCategory.educational:
        return 'educational';
      case PostCategory.general:
        return 'general';
    }
  }
}



class CommunityPost {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorRole;
  final String? authorAvatarUrl;
  final String title;
  final String content;
  final PostCategory category;
  final String? imageUrl;
  final bool isPinned;
  final bool isFeatured;
  final int commentsCount;
  final DateTime createdAt;

  CommunityPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorRole,
    this.authorAvatarUrl,
    required this.title,
    required this.content,
    required this.category,
    this.imageUrl,
    this.isPinned = false,
    this.isFeatured = false,
    this.commentsCount = 0,
    required this.createdAt,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    String name = json['author_name']?.toString() ?? 'طالب امتياز';
    String? role = json['author_role']?.toString();
    String? avatar = json['author_avatar_url']?.toString();

    if (json['author'] != null) {
      name = json['author']['full_name']?.toString() ?? name;
      role = json['author']['role']?.toString() ?? role;
      avatar = json['author']['avatar_url']?.toString() ?? avatar;
    } else if (json['profiles'] != null) {
      name = json['profiles']['full_name']?.toString() ?? name;
      role = json['profiles']['role']?.toString() ?? role;
      avatar = json['profiles']['avatar_url']?.toString() ?? avatar;
    }

    int count = 0;
    if (json['comments'] is List) {
      count = (json['comments'] as List).length;
    } else if (json['community_comments'] is List) {
      count = (json['community_comments'] as List).length;
    } else if (json['comments_count'] != null) {
      count = int.tryParse(json['comments_count'].toString()) ?? 0;
    }

    return CommunityPost(
      id: json['id']?.toString() ?? '',
      authorId: json['author_id']?.toString() ?? '',
      authorName: name,
      authorRole: role,
      authorAvatarUrl: avatar,
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      category: PostCategory.fromString(json['category']?.toString()),
      imageUrl: json['image_url']?.toString(),
      isPinned: json['is_pinned'] == true,
      isFeatured: json['is_featured'] == true,
      commentsCount: count,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  bool get isGold => isFeatured || isPinned;

  CommunityPost copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorRole,
    String? authorAvatarUrl,
    String? title,
    String? content,
    PostCategory? category,
    String? imageUrl,
    bool? isPinned,
    bool? isFeatured,
    int? commentsCount,
    DateTime? createdAt,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorRole: authorRole ?? this.authorRole,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      isPinned: isPinned ?? this.isPinned,
      isFeatured: isFeatured ?? this.isFeatured,
      commentsCount: commentsCount ?? this.commentsCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
