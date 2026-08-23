enum LeaderboardSortMode {
  gpa,
  points;

  String get displayNameAr {
    switch (this) {
      case LeaderboardSortMode.gpa:
        return 'المعدل التراكمي (GPA)';
      case LeaderboardSortMode.points:
        return 'نقاط التميز السريري (Points)';
    }
  }

  static LeaderboardSortMode fromString(String? str) {
    if (str == 'points' || str == 'score') {
      return LeaderboardSortMode.points;
    }
    return LeaderboardSortMode.gpa;
  }

  String toDbString() {
    switch (this) {
      case LeaderboardSortMode.gpa:
        return 'gpa';
      case LeaderboardSortMode.points:
        return 'points';
    }
  }
}

class LeaderboardEntry {
  final int rank;
  final String studentId;
  final String fullName;
  final String studentGroup;
  final String? avatarUrl;
  final double? gpa;
  final double score;
  final int attendedShifts;
  final double attendancePercentage;
  final int? lateCount;
  final int? absentCount;
  final double? avgQuizScore;
  final int? approvedRewards;
  final int? approvedWarnings;
  final double? approvedDeductions;

  LeaderboardEntry({
    required this.rank,
    required this.studentId,
    required this.fullName,
    required this.studentGroup,
    this.avatarUrl,
    this.gpa,
    this.score = 0.0,
    this.attendedShifts = 0,
    this.attendancePercentage = 100.0,
    this.lateCount,
    this.absentCount,
    this.avgQuizScore,
    this.approvedRewards,
    this.approvedWarnings,
    this.approvedDeductions,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json, int defaultRank) {
    double? parsedGpa;
    if (json['gpa'] != null) {
      parsedGpa = (json['gpa'] as num).toDouble();
    }

    return LeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? defaultRank,
      studentId: json['student_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'طالب امتياز',
      studentGroup: json['student_group']?.toString() ?? 'A',
      avatarUrl: json['avatar_url']?.toString(),
      gpa: parsedGpa,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      attendedShifts: (json['attended_shifts'] as num?)?.toInt() ?? 0,
      attendancePercentage: (json['attendance_percentage'] as num?)?.toDouble() ?? 100.0,
      lateCount: (json['late_count'] as num?)?.toInt(),
      absentCount: (json['absent_count'] as num?)?.toInt(),
      avgQuizScore: (json['avg_quiz_score'] as num?)?.toDouble(),
      approvedRewards: (json['approved_rewards'] as num?)?.toInt(),
      approvedWarnings: (json['approved_warnings'] as num?)?.toInt(),
      approvedDeductions: (json['approved_deductions'] as num?)?.toDouble(),
    );
  }
}
