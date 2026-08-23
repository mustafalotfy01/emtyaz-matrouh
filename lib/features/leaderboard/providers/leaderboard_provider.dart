import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/leaderboard_entry.dart';
import '../services/leaderboard_service.dart';

class LeaderboardSortModeNotifier extends StateNotifier<AsyncValue<LeaderboardSortMode>> {
  LeaderboardSortModeNotifier() : super(const AsyncValue.loading()) {
    loadMode();
  }

  Future<void> loadMode() async {
    try {
      final mode = await LeaderboardService.getLeaderboardSortMode();
      state = AsyncValue.data(mode);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> setMode(LeaderboardSortMode newMode) async {
    state = AsyncValue.data(newMode);
    final ok = await LeaderboardService.setLeaderboardSortMode(newMode);
    return ok;
  }
}

final leaderboardSortModeProvider =
    StateNotifierProvider<LeaderboardSortModeNotifier, AsyncValue<LeaderboardSortMode>>((ref) {
  return LeaderboardSortModeNotifier();
});

final leaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) async {
  final user = ref.watch(authProvider).user;
  final sortModeAsync = ref.watch(leaderboardSortModeProvider);
  final sortMode = sortModeAsync.valueOrNull ?? LeaderboardSortMode.gpa;

  return await LeaderboardService.fetchLeaderboard(
    requesterId: user?.id ?? '',
    overrideMode: sortMode,
  );
});
