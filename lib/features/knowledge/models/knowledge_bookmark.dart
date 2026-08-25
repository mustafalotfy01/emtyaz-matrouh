class KnowledgeBookmark {
  final String id;
  final String userId;
  final String articleId;
  final int pageNumber;
  final String? note;
  final DateTime? createdAt;

  KnowledgeBookmark({
    required this.id,
    required this.userId,
    required this.articleId,
    required this.pageNumber,
    this.note,
    this.createdAt,
  });

  String get displayTitle => '🔖 صفحة $pageNumber';

  factory KnowledgeBookmark.fromJson(Map<String, dynamic> json) {
    return KnowledgeBookmark(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      articleId: json['article_id']?.toString() ?? '',
      pageNumber: (json['page_number'] as num?)?.toInt() ?? 1,
      note: json['note']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'article_id': articleId,
      'page_number': pageNumber,
      'note': note,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
