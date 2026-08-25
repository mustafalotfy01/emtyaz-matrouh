class KnowledgeReadingProgress {
  final String id;
  final String userId;
  final String articleId;
  final int lastPage;
  final int? totalPages;
  final double progressPercentage;
  final DateTime? lastOpenedAt;
  final DateTime? completedAt;
  final DateTime? updatedAt;

  KnowledgeReadingProgress({
    required this.id,
    required this.userId,
    required this.articleId,
    required this.lastPage,
    this.totalPages,
    this.progressPercentage = 0.0,
    this.lastOpenedAt,
    this.completedAt,
    this.updatedAt,
  });

  bool get isCompleted => completedAt != null || (totalPages != null && totalPages! > 0 && lastPage >= totalPages!);

  String get displayProgress {
    if (totalPages != null && totalPages! > 0) {
      return 'آخر قراءة: الصفحة $lastPage من $totalPages';
    }
    return 'آخر قراءة: الصفحة $lastPage';
  }

  factory KnowledgeReadingProgress.fromJson(Map<String, dynamic> json) {
    return KnowledgeReadingProgress(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      articleId: json['article_id']?.toString() ?? '',
      lastPage: (json['last_page'] as num?)?.toInt() ?? 1,
      totalPages: (json['total_pages'] as num?)?.toInt(),
      progressPercentage: (json['progress_percentage'] as num?)?.toDouble() ?? 0.0,
      lastOpenedAt: json['last_opened_at'] != null ? DateTime.tryParse(json['last_opened_at'].toString()) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'article_id': articleId,
      'last_page': lastPage,
      'total_pages': totalPages,
      'progress_percentage': progressPercentage,
      'last_opened_at': lastOpenedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
