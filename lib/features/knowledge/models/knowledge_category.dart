class KnowledgeCategory {
  final String id;
  final String nameAr;
  final String? description;
  final String iconName;
  final int orderIndex;
  final bool isActive;
  final String? parentId;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<KnowledgeCategory> subcategories;
  final int articlesCount;

  KnowledgeCategory({
    required this.id,
    required this.nameAr,
    this.description,
    this.iconName = 'menu_book',
    this.orderIndex = 0,
    this.isActive = true,
    this.parentId,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.subcategories = const [],
    this.articlesCount = 0,
  });

  bool get isMainCategory => parentId == null;

  KnowledgeCategory copyWith({
    String? id,
    String? nameAr,
    String? description,
    String? iconName,
    int? orderIndex,
    bool? isActive,
    String? parentId,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<KnowledgeCategory>? subcategories,
    int? articlesCount,
  }) {
    return KnowledgeCategory(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      orderIndex: orderIndex ?? this.orderIndex,
      isActive: isActive ?? this.isActive,
      parentId: parentId ?? this.parentId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subcategories: subcategories ?? this.subcategories,
      articlesCount: articlesCount ?? this.articlesCount,
    );
  }

  factory KnowledgeCategory.fromJson(Map<String, dynamic> json) {
    final subList = json['subcategories'] is List
        ? (json['subcategories'] as List)
            .map((e) => KnowledgeCategory.fromJson(e as Map<String, dynamic>))
            .toList()
        : <KnowledgeCategory>[];

    return KnowledgeCategory(
      id: json['id']?.toString() ?? '',
      nameAr: json['name_ar']?.toString() ?? '',
      description: json['description']?.toString(),
      iconName: json['icon_name']?.toString() ?? 'menu_book',
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] != false,
      parentId: json['parent_id']?.toString(),
      createdBy: json['created_by']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      subcategories: subList,
      articlesCount: (json['articles_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_ar': nameAr,
      'description': description,
      'icon_name': iconName,
      'order_index': orderIndex,
      'is_active': isActive,
      'parent_id': parentId,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
