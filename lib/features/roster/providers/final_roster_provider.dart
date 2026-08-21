import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/roster_entry.dart';
import '../models/roster_month.dart';
import '../services/final_roster_service.dart';

/// Active month selected for Final Approved Roster view
final activeFinalRosterMonthProvider = StateProvider<RosterMonth>((ref) {
  final now = DateTime.now();
  return RosterMonth(
    id: '00000000-0000-0000-0000-${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}000000',
    title: 'روستر شهر ${now.month} ${now.year}',
    month: now.month,
    year: now.year,
    status: RosterMonthStatus.published,
    isPublished: true,
  );
});

/// Fetches the live month published metadata from Supabase
final finalRosterMonthMetaProvider = FutureProvider.autoDispose<RosterMonth>((ref) async {
  final selected = ref.watch(activeFinalRosterMonthProvider);
  return await FinalRosterService.getFinalRosterMonth(selected.month, selected.year);
});

/// Complete Official Approved Roster (Leader View: all roster_entries)
final finalApprovedRosterProvider = FutureProvider.autoDispose<List<RosterEntry>>((ref) async {
  final monthState = ref.watch(activeFinalRosterMonthProvider);
  return await FinalRosterService.getFinalApprovedRoster(
    month: monthState.month,
    year: monthState.year,
  );
});

/// Student's Personal Approved Shifts (Student View: only own roster_entries)
final studentFinalApprovedRosterProvider = FutureProvider.autoDispose<List<RosterEntry>>((ref) async {
  final user = ref.watch(authProvider).user;
  final monthState = ref.watch(activeFinalRosterMonthProvider);
  if (user == null) return [];

  return await FinalRosterService.getStudentFinalApprovedRoster(
    studentId: user.id,
    month: monthState.month,
    year: monthState.year,
  );
});

/// State for Leader Final Roster Editing Mode
class FinalRosterEditState {
  final bool isEditMode;
  final bool isSaving;
  final Map<String, List<RosterEntry>> studentShifts;
  final String? errorMessage;
  final String? successMessage;

  FinalRosterEditState({
    this.isEditMode = false,
    this.isSaving = false,
    this.studentShifts = const {},
    this.errorMessage,
    this.successMessage,
  });

  FinalRosterEditState copyWith({
    bool? isEditMode,
    bool? isSaving,
    Map<String, List<RosterEntry>>? studentShifts,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return FinalRosterEditState(
      isEditMode: isEditMode ?? this.isEditMode,
      isSaving: isSaving ?? this.isSaving,
      studentShifts: studentShifts ?? this.studentShifts,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class FinalRosterEditNotifier extends StateNotifier<FinalRosterEditState> {
  final Ref ref;

  FinalRosterEditNotifier(this.ref) : super(FinalRosterEditState());

  void enterEditMode(List<RosterEntry> currentEntries) {
    final Map<String, List<RosterEntry>> grouped = {};
    for (final e in currentEntries) {
      grouped.putIfAbsent(e.studentId, () => []).add(e);
    }
    state = state.copyWith(isEditMode: true, studentShifts: grouped, clearError: true);
  }

  void cancelEditMode() {
    state = state.copyWith(isEditMode: false, clearError: true);
  }

  void assignOrReplaceShift({
    required String studentId,
    required String studentName,
    required DateTime date,
    required ShiftType shiftType,
    required String departmentId,
    required String departmentName,
  }) {
    final current = Map<String, List<RosterEntry>>.from(state.studentShifts);
    final list = List<RosterEntry>.from(current[studentId] ?? []);

    // Remove old shift on that date (ONE DATE = ONE SHIFT)
    list.removeWhere((e) =>
        e.shiftDate.year == date.year &&
        e.shiftDate.month == date.month &&
        e.shiftDate.day == date.day);

    list.add(RosterEntry(
      id: 'final-edit-${DateTime.now().millisecondsSinceEpoch}',
      studentId: studentId,
      studentName: studentName,
      departmentId: departmentId,
      departmentName: departmentName,
      shiftDate: date,
      shiftType: shiftType,
      status: ShiftStatus.published,
    ));

    current[studentId] = list;
    state = state.copyWith(studentShifts: current);
  }

  void removeShiftOnDate({
    required String studentId,
    required DateTime date,
  }) {
    final current = Map<String, List<RosterEntry>>.from(state.studentShifts);
    final list = List<RosterEntry>.from(current[studentId] ?? []);

    list.removeWhere((e) =>
        e.shiftDate.year == date.year &&
        e.shiftDate.month == date.month &&
        e.shiftDate.day == date.day);

    current[studentId] = list;
    state = state.copyWith(studentShifts: current);
  }

  Future<bool> saveAndReapprove() async {
    final leader = ref.read(authProvider).user;
    final monthState = ref.read(activeFinalRosterMonthProvider);
    if (leader == null) return false;

    state = state.copyWith(isSaving: true, clearError: true);

    final res = await FinalRosterService.approveAndPublishRoster(
      month: monthState.month,
      year: monthState.year,
      leaderId: leader.id,
      studentAssignments: state.studentShifts,
    );

    if (res['success'] == true) {
      state = state.copyWith(isSaving: false, isEditMode: false, successMessage: res['message']);
      ref.invalidate(finalApprovedRosterProvider);
      ref.invalidate(studentFinalApprovedRosterProvider);
      ref.invalidate(finalRosterMonthMetaProvider);
      return true;
    } else {
      state = state.copyWith(isSaving: false, errorMessage: res['message']);
      return false;
    }
  }
}

final finalRosterEditProvider =
    StateNotifierProvider<FinalRosterEditNotifier, FinalRosterEditState>(
        (ref) => FinalRosterEditNotifier(ref));
