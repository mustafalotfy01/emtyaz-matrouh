enum ArticleCategory {
  all,
  procedure,
  disease,
  medication,
  healthEducation,
  studentLessons,
  general,
  scientificReference;

  String get displayNameAr {
    switch (this) {
      case ArticleCategory.all:
        return 'الكل';
      case ArticleCategory.procedure:
        return 'إجراءات تمريضية';
      case ArticleCategory.disease:
        return 'أمراض وحالات';
      case ArticleCategory.medication:
        return 'أدوية وحسابات';
      case ArticleCategory.healthEducation:
        return 'تثقيف صحي';
      case ArticleCategory.studentLessons:
        return 'دروس وملخصات';
      case ArticleCategory.scientificReference:
        return 'ملفات المذاكرة';
      case ArticleCategory.general:
        return 'محتوى عام';
    }
  }

  String get iconName {
    switch (this) {
      case ArticleCategory.all:
        return 'apps';
      case ArticleCategory.procedure:
        return 'assignment';
      case ArticleCategory.disease:
        return 'healing';
      case ArticleCategory.medication:
        return 'medication';
      case ArticleCategory.healthEducation:
        return 'favorite';
      case ArticleCategory.studentLessons:
        return 'school';
      case ArticleCategory.scientificReference:
        return 'menu_book';
      case ArticleCategory.general:
        return 'article';
    }
  }

  static ArticleCategory fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'procedure':
        return ArticleCategory.procedure;
      case 'disease':
        return ArticleCategory.disease;
      case 'medication':
        return ArticleCategory.medication;
      case 'healtheducation':
      case 'health_education':
      case 'tip':
        return ArticleCategory.healthEducation;
      case 'studentlessons':
      case 'student_lessons':
      case 'lesson':
      case 'skill':
        return ArticleCategory.studentLessons;
      case 'scientificreference':
      case 'scientific_reference':
      case 'pdf':
      case 'emergency': // map legacy emergency to procedure/scientific
        return ArticleCategory.scientificReference;
      case 'general':
      case 'text':
        return ArticleCategory.general;
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
  final bool isFeatured;
  final int viewsCount;
  final String? categoryId;
  final String? subcategoryId;
  final String? subcategoryName;
  final String? driveFileId;
  final String? driveFileUrl;
  final String? fileName;
  final int? fileSizeBytes;
  final int? pageCount;
  final String? coverImageUrl;
  final String? authorId;
  final String? authorName;
  final String? publisher;
  final int? publicationYear;
  final String? edition;
  final String language;
  final List<String> tags;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
    this.isFeatured = false,
    this.viewsCount = 0,
    this.categoryId,
    this.subcategoryId,
    this.subcategoryName,
    this.driveFileId,
    this.driveFileUrl,
    this.fileName,
    this.fileSizeBytes,
    this.pageCount,
    this.coverImageUrl,
    this.authorId,
    this.authorName,
    this.publisher,
    this.publicationYear,
    this.edition,
    this.language = 'العربية',
    this.tags = const [],
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPdf => (driveFileId != null && driveFileId!.isNotEmpty) || category == ArticleCategory.scientificReference;
  String get contentMarkdown => definition;
  String get contentType => category.name;

  String get formattedFileSize {
    if (fileSizeBytes == null || fileSizeBytes! <= 0) return '';
    final mb = fileSizeBytes! / (1024 * 1024);
    if (mb >= 1.0) {
      return '${mb.toStringAsFixed(1)} ميجابايت';
    }
    final kb = fileSizeBytes! / 1024;
    return '${kb.toStringAsFixed(0)} ك.ب';
  }

  String get displayAuthor => (authorName != null && authorName!.isNotEmpty) ? authorName! : (references.isNotEmpty ? references : 'هيئة التمريض السريري');

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
    bool? isFeatured,
    int? viewsCount,
    String? categoryId,
    String? subcategoryId,
    String? subcategoryName,
    String? driveFileId,
    String? driveFileUrl,
    String? fileName,
    int? fileSizeBytes,
    int? pageCount,
    String? coverImageUrl,
    String? authorId,
    String? authorName,
    String? publisher,
    int? publicationYear,
    String? edition,
    String? language,
    List<String>? tags,
    DateTime? publishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
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
      isFeatured: isFeatured ?? this.isFeatured,
      viewsCount: viewsCount ?? this.viewsCount,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      subcategoryName: subcategoryName ?? this.subcategoryName,
      driveFileId: driveFileId ?? this.driveFileId,
      driveFileUrl: driveFileUrl ?? this.driveFileUrl,
      fileName: fileName ?? this.fileName,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      pageCount: pageCount ?? this.pageCount,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      publisher: publisher ?? this.publisher,
      publicationYear: publicationYear ?? this.publicationYear,
      edition: edition ?? this.edition,
      language: language ?? this.language,
      tags: tags ?? this.tags,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory KnowledgeArticle.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic val) {
      if (val is List) return val.map((e) => e.toString()).toList();
      if (val is String && val.isNotEmpty) return [val];
      return [];
    }

    final rawType = json['content_type']?.toString() ?? json['type']?.toString();
    final cat = ArticleCategory.fromString(rawType);

    // Extract subcategory name if populated via join
    String? subName;
    if (json['subcategory'] is Map && json['subcategory']['name_ar'] != null) {
      subName = json['subcategory']['name_ar']?.toString();
    } else if (json['categories'] is Map && json['categories']['name_ar'] != null) {
      subName = json['categories']['name_ar']?.toString();
    }

    // Extract author name from profiles if populated via join
    String? aName = json['author_name']?.toString();
    if (aName == null || aName.isEmpty) {
      if (json['author'] is Map && json['author']['full_name'] != null) {
        aName = json['author']['full_name']?.toString();
      } else if (json['profiles'] is Map && json['profiles']['full_name'] != null) {
        aName = json['profiles']['full_name']?.toString();
      }
    }

    return KnowledgeArticle(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? (json['description']?.toString() ?? ''),
      category: cat,
      definition: json['content_markdown']?.toString() ?? (json['summary']?.toString() ?? ''),
      indications: parseList(json['indications']),
      equipment: parseList(json['equipment']),
      steps: parseList(json['steps']),
      aftercare: parseList(json['aftercare']),
      references: json['references']?.toString() ?? '',
      isPublished: json['is_published'] != false,
      isFeatured: json['is_featured'] == true,
      viewsCount: (json['views_count'] as num?)?.toInt() ?? 0,
      categoryId: json['category_id']?.toString(),
      subcategoryId: json['subcategory_id']?.toString(),
      subcategoryName: subName,
      driveFileId: json['drive_file_id']?.toString(),
      driveFileUrl: json['drive_file_url']?.toString(),
      fileName: json['file_name']?.toString(),
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? (json['file_size'] as num?)?.toInt(),
      pageCount: (json['page_count'] as num?)?.toInt(),
      coverImageUrl: json['cover_image_url']?.toString() ?? json['image_url']?.toString(),
      authorId: json['author_id']?.toString(),
      authorName: aName,
      publisher: json['publisher']?.toString(),
      publicationYear: (json['publication_year'] as num?)?.toInt(),
      edition: json['edition']?.toString(),
      language: json['language']?.toString() ?? 'العربية',
      tags: parseList(json['tags']),
      publishedAt: json['published_at'] != null ? DateTime.tryParse(json['published_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'content_markdown': definition,
      'type': category.name,
      'content_type': category == ArticleCategory.scientificReference ? 'scientific_reference' : category.name,
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'drive_file_id': driveFileId,
      'drive_file_url': driveFileUrl,
      'file_name': fileName,
      'file_size_bytes': fileSizeBytes,
      'page_count': pageCount,
      'cover_image_url': coverImageUrl,
      'author_id': authorId,
      'author_name': authorName,
      'publisher': publisher,
      'publication_year': publicationYear,
      'edition': edition,
      'language': language,
      'tags': tags,
      'is_published': isPublished,
      'is_featured': isFeatured,
      'views_count': viewsCount,
      'published_at': publishedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
