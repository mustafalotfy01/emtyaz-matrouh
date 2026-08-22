import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/leaderboard_entry.dart';
import '../services/leaderboard_service.dart';

final leaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) async {
  final user = ref.watch(authProvider).user;
  return await LeaderboardService.fetchLeaderboard(requesterId: user?.id ?? '');
});
