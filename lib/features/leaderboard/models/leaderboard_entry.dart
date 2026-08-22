class LeaderboardEntry {
  final int rank;
  final String studentId;
  final String fullName;
  final String studentGroup;
  final String? avatarUrl;
  final double score;
  final int attendedShifts;
  final double attendancePercentage;

  LeaderboardEntry({
    required this.rank,
    required this.studentId,
    required this.fullName,
    required this.studentGroup,
    this.avatarUrl,
    required this.score,
    required this.attendedShifts,
    required this.attendancePercentage,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json, int defaultRank) {
    return LeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? defaultRank,
      studentId: json['student_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'طالب امتياز',
      studentGroup: json['student_group']?.toString() ?? 'A',
      avatarUrl: json['avatar_url']?.toString(),
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      attendedShifts: (json['attended_shifts'] as num?)?.toInt() ?? 0,
      attendancePercentage: (json['attendance_percentage'] as num?)?.toDouble() ?? 100.0,
    );
  }
}
