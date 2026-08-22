enum ArticleCategory {
  all,
  disease,
  procedure,
  emergency,
  medication,
  skill;

  String get displayNameAr {
    switch (this) {
      case ArticleCategory.all:
        return 'الكل';
      case ArticleCategory.procedure:
        return 'إجراءات تمريضية';
      case ArticleCategory.emergency:
        return 'طوارئ وعناية';
      case ArticleCategory.medication:
        return 'حسابات وجرعات';
      case ArticleCategory.skill:
        return 'مهارات إكلينيكية';
      case ArticleCategory.disease:
        return 'أمراض شائعة';
    }
  }

  static ArticleCategory fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'procedure':
        return ArticleCategory.procedure;
      case 'emergency':
        return ArticleCategory.emergency;
      case 'medication':
        return ArticleCategory.medication;
      case 'skill':
        return ArticleCategory.skill;
      case 'disease':
        return ArticleCategory.disease;
      default:
        return ArticleCategory.procedure;
    }
  }
}

class KnowledgeArticle {
  final String id;
  final String title;
  final String summary;
  final ArticleCategory category;
  final String definition;
  final List<String> indications;
  final List<String> equipment;
  final List<String> steps;
  final List<String> aftercare;
  final String references;
  final bool isPublished;
  final int viewsCount;
  final DateTime? createdAt;

  KnowledgeArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.category,
    required this.definition,
    this.indications = const [],
    this.equipment = const [],
    this.steps = const [],
    this.aftercare = const [],
    this.references = '',
    this.isPublished = true,
    this.viewsCount = 0,
    this.createdAt,
  });

  String get contentMarkdown => definition;
  String get contentType => category.name;
  bool get isFeatured => isPublished;

  KnowledgeArticle copyWith({
    String? id,
    String? title,
    String? summary,
    ArticleCategory? category,
    String? definition,
    List<String>? indications,
    List<String>? equipment,
    List<String>? steps,
    List<String>? aftercare,
    String? references,
    bool? isPublished,
    int? viewsCount,
    DateTime? createdAt,
  }) {
    return KnowledgeArticle(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      category: category ?? this.category,
      definition: definition ?? this.definition,
      indications: indications ?? this.indications,
      equipment: equipment ?? this.equipment,
      steps: steps ?? this.steps,
      aftercare: aftercare ?? this.aftercare,
      references: references ?? this.references,
      isPublished: isPublished ?? this.isPublished,
      viewsCount: viewsCount ?? this.viewsCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory KnowledgeArticle.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic val) {
      if (val is List) return val.map((e) => e.toString()).toList();
      if (val is String && val.isNotEmpty) return [val];
      return [];
    }

    return KnowledgeArticle(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      category: ArticleCategory.fromString(json['type']?.toString()),
      definition: json['content_markdown']?.toString() ?? (json['summary']?.toString() ?? ''),
      indications: parseList(json['indications']),
      equipment: parseList(json['equipment']),
      steps: parseList(json['steps']),
      aftercare: parseList(json['aftercare']),
      references: json['references']?.toString() ?? '',
      isPublished: json['is_published'] != false,
      viewsCount: (json['views_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : null,
    );
  }
}
