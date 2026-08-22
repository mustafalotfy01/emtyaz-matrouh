import 'package:flutter/foundation.dart';
import '../../../core/services/supabase_service.dart';
import '../models/leaderboard_entry.dart';

class LeaderboardService {
  LeaderboardService._();

  /// Fetches real student leaderboard from Supabase
  static Future<List<LeaderboardEntry>> fetchLeaderboard({required String requesterId}) async {
    if (!SupabaseService.isInitialized) return [];

    try {
      final res = await SupabaseService.client.rpc('get_student_leaderboard', params: {
        'p_requester_id': requesterId,
      });

      if (res != null && res['leaderboard'] is List) {
        final rawList = (res['leaderboard'] as List)
            .map((json) => LeaderboardEntry.fromJson(json as Map<String, dynamic>, 1))
            .toList();

        // Check if everyone has 0 points
        final allZero = rawList.every((e) => e.score == 0.0);
        if (allZero) {
          rawList.sort((a, b) => a.fullName.compareTo(b.fullName));
        } else {
          rawList.sort((a, b) {
            final scoreComp = b.score.compareTo(a.score);
            if (scoreComp != 0) return scoreComp;
            return a.fullName.compareTo(b.fullName);
          });
        }

        // Re-assign ranks
        return List.generate(rawList.length, (i) {
          final item = rawList[i];
          return LeaderboardEntry(
            rank: i + 1,
            studentId: item.studentId,
            fullName: item.fullName,
            studentGroup: item.studentGroup,
            avatarUrl: item.avatarUrl,
            score: item.score,
            attendedShifts: item.attendedShifts,
            attendancePercentage: item.attendancePercentage,
          );
        });
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('[LeaderboardService] fetchLeaderboard error: $e');
      return [];
    }
  }
}
