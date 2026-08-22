import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/student_approvals_provider.dart';
import '../models/department.dart';
import '../models/roster_entry.dart';
import '../models/roster_month.dart';
import '../models/roster_preference.dart';
import '../models/student_roster_summary.dart';
import '../services/roster_service.dart';
import '../services/suggestion_engine.dart';
import 'final_roster_provider.dart';

// â”€â”€ Department Provider â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
final departmentsProvider = Provider<List<Department>>((ref) {
  return Department.defaultDepartments();
});

// â”€â”€ Current Roster Month Provider â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
final currentRosterMonthProvider = StateProvider<RosterMonth>((ref) {
  return RosterService.getCurrentRosterMonth();
});

// â”€â”€ Student Preferences State & Notifier â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class StudentPreferencesState {
  final List<RosterPreference> preferences;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final bool isSubmitted;

  StudentPreferencesState({
    required this.preferences,
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.isSubmitted = false,
  });

  int get morningCount =>
      preferences.where((p) => p.preferenceShiftType == PreferenceShiftType.morning).length;

  int get longCount =>
      preferences.where((p) => p.preferenceShiftType == PreferenceShiftType.longShift).length;

  int get nightCount =>
      preferences.where((p) => p.preferenceShiftType == PreferenceShiftType.night).length;

  int get totalCount => preferences.length;

  // Legacy compat
  int get optionACount => morningCount + longCount;
  int get optionBCount => nightCount;

  ShiftValidationResult get validationResult => ShiftRulesHelper.validate(
        morningCount: morningCount,
        longCount: longCount,
        nightCount: nightCount,
      );

  bool get isReadyToSubmit =>
      totalCount == ShiftRulesHelper.requiredDaysForMorning(morningCount) && validationResult.canSubmit;

  PreferenceShiftType? getShiftTypeForDate(DateTime date) {
    try {
      final match = preferences.firstWhere(
        (p) =>
            p.preferenceDate.year == date.year &&
            p.preferenceDate.month == date.month &&
            p.preferenceDate.day == date.day,
      );
      return match.preferenceShiftType;
    } catch (_) {
      return null;
    }
  }

  // Legacy compat
  PreferenceType? getPreferenceForDate(DateTime date) {
    final shift = getShiftTypeForDate(date);
    if (shift == null) return null;
    return shift == PreferenceShiftType.night ? PreferenceType.optionB : PreferenceType.optionA;
  }

  StudentPreferencesState copyWith({
    List<RosterPreference>? preferences,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool? isSubmitted,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return StudentPreferencesState(
      preferences: preferences ?? this.preferences,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      isSubmitted: isSubmitted ?? this.isSubmitted,
    );
  }
}

class StudentPreferencesNotifier extends StateNotifier<StudentPreferencesState> {
  final Ref ref;

  StudentPreferencesNotifier(this.ref)
      : super(StudentPreferencesState(preferences: [])) {
    loadPreferences();
  }

  Future<void> loadPreferences() async {
    final user = ref.read(authProvider).user;
    final rosterMonth = ref.read(currentRosterMonthProvider);
    if (user == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final prefs = await RosterService.loadStudentPreferences(
        studentId: user.id,
        rosterId: rosterMonth.id,
        month: rosterMonth.month,
        year: rosterMonth.year,
      );
      state = state.copyWith(
        preferences: prefs,
        isLoading: false,
        isSubmitted: prefs.any((p) => p.status == PreferenceStatus.submitted),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'فشل تحميل التفضيلات: $e',
      );
    }
  }

  /// تبديل اليوم بين: Morning → Long → Night → إلغاء
  /// يتيح اختيار أي يوم في الشهر مع مراعاة قاعدة 36 ساعة أسبوعياً
  void toggleDateShift(DateTime date, [StudentGroup? group]) {
    if (state.isSubmitted) return;

    final rosterMonth = ref.read(currentRosterMonthProvider);
    final user = ref.read(authProvider).user;
    final currentShift = state.getShiftTypeForDate(date);

    List<RosterPreference> updated = List.from(state.preferences);

    if (currentShift == null) {
      // يبدأ بـ Morning
      updated.add(RosterPreference(
        id: 'pref-${DateTime.now().millisecondsSinceEpoch}',
        rosterId: rosterMonth.id,
        studentId: user?.id ?? 'student-001',
        preferenceDate: date,
        preferenceType: PreferenceType.optionA,
        preferenceShiftType: PreferenceShiftType.morning,
      ));
    } else if (currentShift == PreferenceShiftType.morning) {
      // Morning → Long
      updated = _replaceShift(updated, date, rosterMonth.id, user?.id ?? '', PreferenceShiftType.longShift);
    } else if (currentShift == PreferenceShiftType.longShift) {
      // Long → Night
      updated = _replaceShift(updated, date, rosterMonth.id, user?.id ?? '', PreferenceShiftType.night);
    } else {
      // Night → إلغاء
      updated.removeWhere((p) =>
          p.preferenceDate.year == date.year &&
          p.preferenceDate.month == date.month &&
          p.preferenceDate.day == date.day);
    }

    state = state.copyWith(
      preferences: updated,
      clearError: true,
      clearSuccess: true,
    );

    // حفظ تلقائي في الخلفية
    if (user != null) {
      RosterService.savePreferences(
        studentId: user.id,
        rosterId: rosterMonth.id,
        preferences: updated,
      );
    }
  }

  List<RosterPreference> _replaceShift(
    List<RosterPreference> list,
    DateTime date,
    String rosterId,
    String studentId,
    PreferenceShiftType newShift,
  ) {
    final updated = list.where((p) => !(
      p.preferenceDate.year == date.year &&
      p.preferenceDate.month == date.month &&
      p.preferenceDate.day == date.day
    )).toList();

    updated.add(RosterPreference(
      id: 'pref-${DateTime.now().millisecondsSinceEpoch}',
      rosterId: rosterId,
      studentId: studentId,
      preferenceDate: date,
      preferenceType: newShift == PreferenceShiftType.night ? PreferenceType.optionB : PreferenceType.optionA,
      preferenceShiftType: newShift,
    ));

    return updated;
  }

  /// Legacy compat - toggle day (used by calendar)
  void toggleDatePreference(DateTime date, [StudentGroup? group]) {
    toggleDateShift(date, group);
  }

  /// تعيين شيفت محدد ليوم معين مباشرة
  void selectShiftForDate(DateTime date, PreferenceShiftType shiftType, [StudentGroup? group]) {
    if (state.isSubmitted) return;

    final rosterMonth = ref.read(currentRosterMonthProvider);
    final user = ref.read(authProvider).user;
    final currentShift = state.getShiftTypeForDate(date);

    List<RosterPreference> updated = List.from(state.preferences);

    if (currentShift == shiftType) {
      // إلغاء اليوم
      updated.removeWhere((p) =>
          p.preferenceDate.year == date.year &&
          p.preferenceDate.month == date.month &&
          p.preferenceDate.day == date.day);
    } else {
      updated = _replaceShift(updated, date, rosterMonth.id, user?.id ?? '', shiftType);
    }

    state = state.copyWith(preferences: updated, clearError: true, clearSuccess: true);

    if (user != null) {
      RosterService.savePreferences(
        studentId: user.id,
        rosterId: rosterMonth.id,
        preferences: updated,
      ).then((_) {
        ref.read(leaderRosterProvider.notifier).loadDashboard();
      });
    }
  }

  // Legacy compat
  void selectOptionA(DateTime date, StudentGroup group) {
    selectShiftForDate(date, PreferenceShiftType.morning, group);
  }

  void selectOptionB(DateTime date, StudentGroup group) {
    selectShiftForDate(date, PreferenceShiftType.night, group);
  }

  /// Submit preferences to Leader
  Future<bool> submitPreferences() async {
    final user = ref.read(authProvider).user;
    final rosterMonth = ref.read(currentRosterMonthProvider);
    if (user == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);

    final res = await RosterService.submitPreferences(
      studentId: user.id,
      rosterId: rosterMonth.id,
      studentGroup: user.studentGroup,
      preferences: state.preferences,
    );

    if (res['success'] == true) {
      state = state.copyWith(
        isLoading: false,
        isSubmitted: true,
        successMessage: res['message'],
      );
      // Immediately refresh leader dashboard in memory
      await ref.read(leaderRosterProvider.notifier).loadDashboard();
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: res['message'],
      );
      return false;
    }
  }
}

final studentPreferencesProvider =
    StateNotifierProvider<StudentPreferencesNotifier, StudentPreferencesState>(
        (ref) => StudentPreferencesNotifier(ref));

// â”€â”€ Student Published Roster Provider â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
final studentPublishedRosterProvider =
    FutureProvider<List<RosterEntry>>((ref) async {
  final user = ref.watch(authProvider).user;
  final rosterMonth = ref.watch(currentRosterMonthProvider);
  if (user == null) return [];

  return await RosterService.loadStudentFinalRoster(
    studentId: user.id,
    rosterId: rosterMonth.id,
  );
});

// ── Leader Dashboard State & Notifier ───────────────────────────────────────
class LeaderRosterState {
  final List<StudentRosterSummary> summaries;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final String filterStatus; // 'ALL', 'SUBMITTED', 'DRAFT', 'NEEDS_REVIEW', 'COMPLETED'
  final String searchQuery;

  LeaderRosterState({
    required this.summaries,
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.filterStatus = 'ALL',
    this.searchQuery = '',
  });

  List<StudentRosterSummary> get filteredSummaries {
    return summaries.where((s) {
      if (searchQuery.isNotEmpty && !s.studentName.toLowerCase().contains(searchQuery.toLowerCase())) {
        return false;
      }
      if (filterStatus == 'SUBMITTED' && !s.isSubmitted) return false;
      if (filterStatus == 'DRAFT' && s.isSubmitted) return false;
      if (filterStatus == 'COMPLETED' && s.totalFinalShifts != ShiftRulesHelper.requiredDays) return false;
      if (filterStatus == 'NEEDS_REVIEW' && (s.fairnessLevel == FairnessLevel.fair && s.totalFinalShifts == ShiftRulesHelper.requiredDays)) return false;
      return true;
    }).toList();
  }

  LeaderRosterState copyWith({
    List<StudentRosterSummary>? summaries,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    String? filterStatus,
    String? searchQuery,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return LeaderRosterState(
      summaries: summaries ?? this.summaries,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      filterStatus: filterStatus ?? this.filterStatus,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class LeaderRosterNotifier extends StateNotifier<LeaderRosterState> {
  final Ref ref;

  LeaderRosterNotifier(this.ref) : super(LeaderRosterState(summaries: [])) {
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    final rosterMonth = ref.read(currentRosterMonthProvider);
    final studentsAsync = ref.read(studentApprovalsProvider);
    final registeredStudents = studentsAsync.maybeWhen(
      data: (list) => list.where((u) => u.isApproved && u.registrationStatus == RegistrationStatus.approved).toList(),
      orElse: () => <UserProfile>[],
    );

    state = state.copyWith(isLoading: true, clearError: true);

    // Sync latest month status from Supabase
    final updatedMonth = await RosterService.fetchRosterMonthFromSupabase(rosterMonth.month, rosterMonth.year);
    ref.read(currentRosterMonthProvider.notifier).state = updatedMonth;

    final summaries = await RosterService.loadLeaderSummaries(
      rosterId: rosterMonth.id,
      month: rosterMonth.month,
      year: rosterMonth.year,
      registeredStudents: registeredStudents,
    );

    state = state.copyWith(summaries: summaries, isLoading: false);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilterStatus(String status) {
    state = state.copyWith(filterStatus: status);
  }

  /// Reopens preferences for a student
  Future<Map<String, dynamic>> reopenStudentPreferences(String studentId) async {
    final leader = ref.read(authProvider).user;
    final rosterMonth = ref.read(currentRosterMonthProvider);
    if (leader == null) return {'success': false, 'message': 'يجب تسجيل الدخول كمنسق أو قائد'};

    final res = await RosterService.reopenPreferences(
      leaderId: leader.id,
      studentId: studentId,
      rosterId: rosterMonth.id,
    );

    await loadDashboard();
    return res;
  }

  /// Reopens full roster for editing (unpublish)
  Future<bool> unpublishRoster() async {
    final leader = ref.read(authProvider).user;
    final rosterMonth = ref.read(currentRosterMonthProvider);
    if (leader == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);

    final res = await RosterService.unpublishRoster(
      rosterId: rosterMonth.id,
      leaderId: leader.id,
    );

    ref.read(currentRosterMonthProvider.notifier).state =
        RosterService.getCurrentRosterMonth();
    ref.invalidate(finalApprovedRosterProvider);
    ref.invalidate(finalRosterMonthMetaProvider);
    ref.invalidate(studentFinalApprovedRosterProvider);
    await loadDashboard();
    state = state.copyWith(
      isLoading: false,
      successMessage: res['message'],
    );
    return true;
  }

  /// Clears all preferences and assigned shifts to start fresh
  Future<void> clearAllPreferencesToReset() async {
    state = state.copyWith(isLoading: true);
    await RosterService.clearAllPreferencesAndCache();
    ref.read(studentPreferencesProvider.notifier).loadPreferences();
    await loadDashboard();
  }

  /// Applies Suggestion 1 automatically for a student
  Future<void> applySuggestion1ForStudent(StudentRosterSummary summary) async {
    final leader = ref.read(authProvider).user;
    final rosterMonth = ref.read(currentRosterMonthProvider);
    if (leader == null) return;

    final suggested = SuggestionEngine.generateSuggestion1(
      studentId: summary.studentId,
      studentName: summary.studentName,
      studentGroup: summary.studentGroup,
      rosterId: rosterMonth.id,
      month: rosterMonth.month,
      year: rosterMonth.year,
      preferences: summary.preferences,
    );

    await RosterService.saveFinalAssignment(
      rosterId: rosterMonth.id,
      studentId: summary.studentId,
      entries: suggested,
      approvedBy: leader.id,
    );

    await loadDashboard();
  }

  /// Saves manual assignment edits
  Future<void> saveStudentAssignments(String studentId, List<RosterEntry> entries) async {
    final leader = ref.read(authProvider).user;
    final rosterMonth = ref.read(currentRosterMonthProvider);
    if (leader == null) return;

    await RosterService.saveFinalAssignment(
      rosterId: rosterMonth.id,
      studentId: studentId,
      entries: entries,
      approvedBy: leader.id,
    );

    await loadDashboard();
  }

  /// Quick-assigns a shift to a student on a specific date directly from Day View
  Future<void> assignShiftToStudentOnDate({
    required String studentId,
    required String studentName,
    required DateTime date,
    required PreferenceShiftType shiftType,
    required String departmentId,
    required String departmentName,
    String? preferenceType,
  }) async {
    final leader = ref.read(authProvider).user;
    final rosterMonth = ref.read(currentRosterMonthProvider);
    final leaderId = leader?.id ?? 'leader-001';

    // Convert PreferenceShiftType → ShiftType (roster_entry)
    final entryShiftType = shiftType == PreferenceShiftType.night
        ? ShiftType.night
        : shiftType == PreferenceShiftType.longShift
            ? ShiftType.long
            : ShiftType.morning;

    await RosterService.quickAssignShift(
      rosterId: rosterMonth.id,
      studentId: studentId,
      studentName: studentName,
      date: date,
      shiftType: entryShiftType,
      departmentId: departmentId,
      departmentName: departmentName,
      approvedBy: leaderId,
      preferenceType: preferenceType,
    );

    await loadDashboard();
  }

  /// Removes a shift from a student on a specific date directly from Day View
  Future<void> removeShiftFromStudentOnDate({
    required String studentId,
    required DateTime date,
  }) async {
    final leader = ref.read(authProvider).user;
    final rosterMonth = ref.read(currentRosterMonthProvider);
    final leaderId = leader?.id ?? 'leader-001';

    await RosterService.removeShiftOnDate(
      rosterId: rosterMonth.id,
      studentId: studentId,
      date: date,
      approvedBy: leaderId,
    );

    await loadDashboard();
  }

  /// Publishes Final Roster
  Future<bool> publishRoster() async {
    final leader = ref.read(authProvider).user;
    final rosterMonth = ref.read(currentRosterMonthProvider);
    if (leader == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);

    final res = await RosterService.publishRoster(
      rosterId: rosterMonth.id,
      leaderId: leader.id,
      summaries: state.summaries,
    );

    if (res['success'] == true) {
      ref.read(currentRosterMonthProvider.notifier).state =
          RosterService.getCurrentRosterMonth();
      ref.invalidate(finalApprovedRosterProvider);
      ref.invalidate(finalRosterMonthMetaProvider);
      ref.invalidate(studentFinalApprovedRosterProvider);
      await loadDashboard();
      state = state.copyWith(
        isLoading: false,
        successMessage: res['message'],
      );
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: (res['issues'] as List<String>?)?.join('\n') ?? res['message'],
      );
      return false;
    }
  }
}

final leaderRosterProvider =
    StateNotifierProvider<LeaderRosterNotifier, LeaderRosterState>(
        (ref) => LeaderRosterNotifier(ref));

// â”€â”€ Legacy Compatibility Provider â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
final rosterProvider = Provider<List<RosterEntry>>((ref) {
  final summaries = ref.watch(leaderRosterProvider).summaries;
  return summaries.expand((s) => s.assignedShifts).toList();
});

