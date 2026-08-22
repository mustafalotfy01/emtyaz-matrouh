enum RosterMonthStatus {
  draft,
  open,
  studentSubmission,
  leaderReview,
  assignment,
  readyForApproval,
  published,
  locked;

  String get displayNameAr {
    switch (this) {
      case RosterMonthStatus.draft:
        return 'مسودة';
      case RosterMonthStatus.open:
      case RosterMonthStatus.studentSubmission:
        return 'مفتوح لاختيار الطلاب';
      case RosterMonthStatus.leaderReview:
        return 'قيد مراجعة الليدر';
      case RosterMonthStatus.assignment:
        return 'مرحلة توزيع الشيفتات';
      case RosterMonthStatus.readyForApproval:
        return 'جاهز للاعتماد';
      case RosterMonthStatus.published:
        return 'معتمد ومنشور رسميًا';
      case RosterMonthStatus.locked:
        return 'مغلق ومؤرشف';
    }
  }

  static RosterMonthStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'open':
      case 'student_submission':
        return RosterMonthStatus.studentSubmission;
      case 'leader_review':
        return RosterMonthStatus.leaderReview;
      case 'assignment':
        return RosterMonthStatus.assignment;
      case 'ready_for_approval':
        return RosterMonthStatus.readyForApproval;
      case 'published':
        return RosterMonthStatus.published;
      case 'locked':
        return RosterMonthStatus.locked;
      case 'draft':
      default:
        return RosterMonthStatus.draft;
    }
  }

  String toDbString() {
    switch (this) {
      case RosterMonthStatus.studentSubmission:
      case RosterMonthStatus.open:
        return 'open';
      case RosterMonthStatus.leaderReview:
        return 'leader_review';
      case RosterMonthStatus.assignment:
        return 'assignment';
      case RosterMonthStatus.readyForApproval:
        return 'ready_for_approval';
      case RosterMonthStatus.published:
        return 'published';
      case RosterMonthStatus.locked:
        return 'locked';
      case RosterMonthStatus.draft:
        return 'draft';
    }
  }
}

class RosterMonth {
  final String id;
  final String title;
  final int month;
  final int year;
  final RosterMonthStatus status;
  final bool isPublished;
  final DateTime? openedAt;
  final DateTime? submissionDeadline;
  final DateTime? publishedAt;
  final String? publishedBy;
  final DateTime? createdAt;

  RosterMonth({
    required this.id,
    required this.title,
    required this.month,
    required this.year,
    this.status = RosterMonthStatus.studentSubmission,
    this.isPublished = false,
    this.openedAt,
    this.submissionDeadline,
    this.publishedAt,
    this.publishedBy,
    this.createdAt,
  });

  bool get isOpenForSelection =>
      status == RosterMonthStatus.open ||
      status == RosterMonthStatus.studentSubmission;

  factory RosterMonth.fromJson(Map<String, dynamic> json) {
    final status = RosterMonthStatus.fromString(json['status']);
    final isPub = json['is_published'] == true || status == RosterMonthStatus.published;
    return RosterMonth(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'روستر شهر ${json['month']} - ${json['year']}',
      month: (json['month'] as num?)?.toInt() ?? DateTime.now().month,
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      status: status,
      isPublished: isPub,
      openedAt: json['opened_at'] != null ? DateTime.tryParse(json['opened_at']) : null,
      submissionDeadline: json['submission_deadline'] != null ? DateTime.tryParse(json['submission_deadline']) : null,
      publishedAt: json['published_at'] != null ? DateTime.tryParse(json['published_at']) : null,
      publishedBy: json['published_by']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'month': month,
      'year': year,
      'status': status.toDbString(),
      'is_published': isPublished,
      'opened_at': openedAt?.toIso8601String(),
      'submission_deadline': submissionDeadline?.toIso8601String(),
      'published_at': publishedAt?.toIso8601String(),
      'published_by': publishedBy,
    };
  }

  RosterMonth copyWith({
    String? id,
    String? title,
    int? month,
    int? year,
    RosterMonthStatus? status,
    bool? isPublished,
    DateTime? openedAt,
    DateTime? submissionDeadline,
    DateTime? publishedAt,
    String? publishedBy,
  }) {
    return RosterMonth(
      id: id ?? this.id,
      title: title ?? this.title,
      month: month ?? this.month,
      year: year ?? this.year,
      status: status ?? this.status,
      isPublished: isPublished ?? this.isPublished,
      openedAt: openedAt ?? this.openedAt,
      submissionDeadline: submissionDeadline ?? this.submissionDeadline,
      publishedAt: publishedAt ?? this.publishedAt,
      publishedBy: publishedBy ?? this.publishedBy,
    );
  }

  static RosterMonth nextMonthDefault() {
    final now = DateTime.now();
    final nextMonth = (now.month % 12) + 1;
    final nextYear = now.month == 12 ? now.year + 1 : now.year;
    final monthNames = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    final monthName = monthNames[nextMonth];

    return RosterMonth(
      id: 'roster-$nextYear-${nextMonth.toString().padLeft(2, '0')}',
      title: 'روستر شهر $monthName $nextYear (التقديم متاح)',
      month: nextMonth,
      year: nextYear,
      status: RosterMonthStatus.studentSubmission,
      isPublished: false,
    );
  }

  static RosterMonth currentDefault() {
    return nextMonthDefault();
  }

  static List<RosterMonth> getAvailableMonths() {
    final now = DateTime.now();
    final nextMonth = (now.month % 12) + 1;
    final nextYear = now.month == 12 ? now.year + 1 : now.year;

    final curMonth = now.month;
    final curYear = now.year;

    final prevMonth = (now.month == 1) ? 12 : now.month - 1;
    final prevYear = (now.month == 1) ? now.year - 1 : now.year;

    final monthNames = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];

    return [
      // 1. Next Month (Open for Preference submission)
      RosterMonth(
        id: 'roster-$nextYear-${nextMonth.toString().padLeft(2, '0')}',
        title: 'روستر شهر ${monthNames[nextMonth]} $nextYear (الشهر القادم — اختيار التفضيلات)',
        month: nextMonth,
        year: nextYear,
        status: RosterMonthStatus.studentSubmission,
        isPublished: false,
      ),
      // 2. Current Month (Published / Active)
      RosterMonth(
        id: 'roster-$curYear-${curMonth.toString().padLeft(2, '0')}',
        title: 'روستر شهر ${monthNames[curMonth]} $curYear (الشهر الحالي — معتمد ومفعل)',
        month: curMonth,
        year: curYear,
        status: RosterMonthStatus.published,
        isPublished: true,
      ),
      // 3. Previous Month (Archived History)
      RosterMonth(
        id: 'roster-$prevYear-${prevMonth.toString().padLeft(2, '0')}',
        title: 'روستر شهر ${monthNames[prevMonth]} $prevYear (سجل سابق — مؤرشف)',
        month: prevMonth,
        year: prevYear,
        status: RosterMonthStatus.locked,
        isPublished: true,
      ),
    ];
  }
}
