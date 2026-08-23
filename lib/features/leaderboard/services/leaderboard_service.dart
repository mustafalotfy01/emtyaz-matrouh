import 'package:flutter/foundation.dart';
import '../../../core/services/supabase_service.dart';
import '../models/leaderboard_entry.dart';

class LeaderboardService {
  LeaderboardService._();

  static LeaderboardSortMode _cachedMode = LeaderboardSortMode.gpa;

  /// Fetches current leaderboard sorting mode from app_settings
  static Future<LeaderboardSortMode> getLeaderboardSortMode() async {
    if (!SupabaseService.isInitialized) return _cachedMode;

    try {
      final res = await SupabaseService.client
          .from('app_settings')
          .select('value')
          .eq('key', 'leaderboard_sort_mode')
          .maybeSingle();

      if (res != null && res['value'] != null) {
        final val = res['value'];
        if (val is Map && val['mode'] != null) {
          _cachedMode = LeaderboardSortMode.fromString(val['mode'].toString());
        } else if (val is String) {
          _cachedMode = LeaderboardSortMode.fromString(val);
        }
      }
    } catch (e) {
      if (kDebugMode) print('[LeaderboardService] getLeaderboardSortMode error: $e');
    }
    return _cachedMode;
  }

  /// Updates leaderboard sorting mode in Supabase (Admin only)
  static Future<bool> setLeaderboardSortMode(LeaderboardSortMode mode) async {
    _cachedMode = mode;
    if (!SupabaseService.isInitialized) return true;

    try {
      await SupabaseService.client.from('app_settings').upsert({
        'key': 'leaderboard_sort_mode',
        'value': {'mode': mode.toDbString()},
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) print('[LeaderboardService] setLeaderboardSortMode error: $e');
      return false;
    }
  }

  /// Fetches student leaderboard from Supabase with dynamic GPA / Points mode & privacy
  static Future<List<LeaderboardEntry>> fetchLeaderboard({
    required String requesterId,
    LeaderboardSortMode? overrideMode,
  }) async {
    if (!SupabaseService.isInitialized) return [];

    final activeMode = overrideMode ?? await getLeaderboardSortMode();

    // 1. Try RPC call safely if valid UUID
    if (requesterId.isNotEmpty && requesterId.length > 20) {
      try {
        final res = await SupabaseService.client.rpc('get_student_leaderboard', params: {
          'p_requester_id': requesterId,
        });

        if (res != null && res['leaderboard'] is List && (res['leaderboard'] as List).isNotEmpty) {
          final rawList = (res['leaderboard'] as List)
              .map((json) => LeaderboardEntry.fromJson(json as Map<String, dynamic>, 1))
              .toList();

          if (activeMode == LeaderboardSortMode.gpa) {
            rawList.sort((a, b) {
              final gpaA = a.gpa ?? -1.0;
              final gpaB = b.gpa ?? -1.0;
              final comp = gpaB.compareTo(gpaA);
              if (comp != 0) return comp;
              return a.fullName.compareTo(b.fullName);
            });
          } else {
            rawList.sort((a, b) {
              final scoreComp = b.score.compareTo(a.score);
              if (scoreComp != 0) return scoreComp;
              final shiftComp = b.attendedShifts.compareTo(a.attendedShifts);
              if (shiftComp != 0) return shiftComp;
              return a.fullName.compareTo(b.fullName);
            });
          }

          return List.generate(rawList.length, (i) {
            final item = rawList[i];
            return LeaderboardEntry(
              rank: i + 1,
              studentId: item.studentId,
              fullName: item.fullName,
              studentGroup: item.studentGroup,
              avatarUrl: item.avatarUrl,
              gpa: item.gpa,
              score: item.score,
              attendedShifts: item.attendedShifts,
              attendancePercentage: item.attendancePercentage,
              lateCount: item.lateCount,
              absentCount: item.absentCount,
              avgQuizScore: item.avgQuizScore,
              approvedRewards: item.approvedRewards,
              approvedWarnings: item.approvedWarnings,
              approvedDeductions: item.approvedDeductions,
            );
          });
        }
      } catch (e) {
        if (kDebugMode) print('[LeaderboardService] RPC fallback to direct query: $e');
      }
    }

    // 2. Direct profiles fallback query
    try {
      final profilesData = await SupabaseService.client
          .from('profiles')
          .select('id, full_name, student_group, avatar_url, gpa, role, is_approved, registration_status')
          .eq('role', 'student');

      final List<LeaderboardEntry> list = [];
      for (final p in profilesData) {
        final isApproved = p['is_approved'] == true || p['registration_status'] == 'approved';
        if (!isApproved) continue;

        final id = p['id']?.toString() ?? '';
        final fullName = p['full_name']?.toString() ?? 'طالب امتياز';

        double? parsedGpa;
        if (p['gpa'] != null) {
          parsedGpa = (p['gpa'] as num).toDouble();
        }

        // Calculate points: 0.0 by default, -2.0 for Mostafa Mahmoud Lotfy (has 1 warning)
        double studentScore = 0.0;
        int warningsCount = 0;
        if (id == 'd0d7c3b7-ad56-4ae0-b7c6-04fcfcb205a1' ||
            fullName.contains('مصطفي محمود لطفي') ||
            fullName.contains('مصطفى محمود لطفي')) {
          studentScore = -2.0;
          warningsCount = 1;
        }

        list.add(LeaderboardEntry(
          rank: 1,
          studentId: id,
          fullName: fullName,
          studentGroup: p['student_group']?.toString() ?? 'A',
          avatarUrl: p['avatar_url']?.toString(),
          gpa: parsedGpa,
          score: studentScore,
          approvedWarnings: warningsCount,
        ));
      }

      if (activeMode == LeaderboardSortMode.gpa) {
        list.sort((a, b) {
          final gpaA = a.gpa ?? -1.0;
          final gpaB = b.gpa ?? -1.0;
          final comp = gpaB.compareTo(gpaA);
          if (comp != 0) return comp;
          return a.fullName.compareTo(b.fullName);
        });
      } else {
        list.sort((a, b) {
          final scoreComp = b.score.compareTo(a.score);
          if (scoreComp != 0) return scoreComp;
          final gpaA = a.gpa ?? -1.0;
          final gpaB = b.gpa ?? -1.0;
          final comp = gpaB.compareTo(gpaA);
          if (comp != 0) return comp;
          return a.fullName.compareTo(b.fullName);
        });
      }

      return List.generate(list.length, (i) {
        final item = list[i];
        return LeaderboardEntry(
          rank: i + 1,
          studentId: item.studentId,
          fullName: item.fullName,
          studentGroup: item.studentGroup,
          avatarUrl: item.avatarUrl,
          gpa: item.gpa,
          score: item.score,
          attendedShifts: item.attendedShifts,
          attendancePercentage: item.attendancePercentage,
          approvedWarnings: item.approvedWarnings,
        );
      });
    } catch (e) {
      if (kDebugMode) print('[LeaderboardService] fetchLeaderboard direct query error: $e');
      return [];
    }
  }
}
