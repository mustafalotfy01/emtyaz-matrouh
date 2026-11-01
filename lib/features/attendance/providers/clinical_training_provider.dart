import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/timezone_helper.dart';
import '../../auth/providers/auth_provider.dart';
import '../../groups/models/student_group.dart';
import '../../groups/providers/student_groups_provider.dart';
import '../../roster/models/roster_entry.dart';
import '../models/clinical_compensation_model.dart';
import '../models/student_clinical_daily_item.dart';
import '../repositories/clinical_training_repository.dart';

final clinicalTrainingRepositoryProvider = Provider<ClinicalTrainingRepository>((ref) {
  return ClinicalTrainingRepository();
});

/// High-speed summary for Leader Dashboard
final leaderDashboardSummaryProvider = FutureProvider.autoDispose<LeaderDashboardSummary>((ref) async {
  final repo = ref.watch(clinicalTrainingRepositoryProvider);
  return await repo.fetchLeaderDashboardSummary();
});

/// Groups assigned to current doctor with daily attendance metrics
final doctorDashboardGroupsProvider = FutureProvider.family.autoDispose<List<GroupCardSummary>, String>((ref, doctorId) async {
  final repo = ref.watch(clinicalTrainingRepositoryProvider);
  return await repo.fetchDoctorDashboardGroups(doctorId);
});

/// Groups assigned to current doctor
final doctorAssignedGroupsProvider = FutureProvider.autoDispose<List<StudentGroupModel>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return [];

  final groupsRepo = ref.watch(studentGroupsRepositoryProvider);
  final allGroups = await groupsRepo.fetchGroups();

  return allGroups.where((g) => g.supervisorDoctorId == user.id).toList();
});

/// Group Clinical Management UI State
class GroupClinicalState {
  final String groupId;
  final DateTime date;
  final String departmentName;
  final String? departmentId;
  final String? doctorName;
  final List<StudentClinicalDailyItem> rawItems;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;
  final String searchQuery;
  final ShiftType? filterShift;
  final ClinicalAttendanceState? filterState;
  final bool sortUnrecordedFirst;

  const GroupClinicalState({
    required this.groupId,
    required this.date,
    this.departmentName = 'قسم الطوارئ',
    this.departmentId,
    this.doctorName,
    this.rawItems = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.successMessage,
    this.searchQuery = '',
    this.filterShift,
    this.filterState,
    this.sortUnrecordedFirst = true,
  });

  int get totalCount => rawItems.length;

  int get presentCount => rawItems
      .where((i) => i.pendingState == ClinicalAttendanceState.present)
      .length;

  int get absentCount => rawItems
      .where((i) => i.pendingState == ClinicalAttendanceState.absent)
      .length;

  int get exceptionCount => rawItems
      .where((i) => i.pendingState == ClinicalAttendanceState.exception || i.hasException)
      .length;

  int get unrecordedCount => rawItems
      .where((i) => i.pendingState == ClinicalAttendanceState.unrecorded)
      .length;

  int get dirtyCount => rawItems.where((i) => i.isDirty).length;

  List<StudentClinicalDailyItem> get filteredItems {
    var list = List<StudentClinicalDailyItem>.from(rawItems);

    // 1. Search Query (name or university code)
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      list = list.where((i) {
        return i.studentName.toLowerCase().contains(q) ||
            i.universityCode.toLowerCase().contains(q);
      }).toList();
    }

    // 2. Shift Filter
    if (filterShift != null) {
      list = list.where((i) => i.effectiveShiftType == filterShift).toList();
    }

    // 3. Status Filter
    if (filterState != null) {
      list = list.where((i) => i.pendingState == filterState).toList();
    }

    // 4. Sorting
    list.sort((a, b) {
      if (sortUnrecordedFirst) {
        final aUnrec = a.pendingState == ClinicalAttendanceState.unrecorded;
        final bUnrec = b.pendingState == ClinicalAttendanceState.unrecorded;
        if (aUnrec && !bUnrec) return -1;
        if (!aUnrec && bUnrec) return 1;
      }
      return a.studentName.compareTo(b.studentName);
    });

    return list;
  }

  GroupClinicalState copyWith({
    String? groupId,
    DateTime? date,
    String? departmentName,
    String? departmentId,
    String? doctorName,
    List<StudentClinicalDailyItem>? rawItems,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    String? successMessage,
    String? searchQuery,
    ShiftType? filterShift,
    ClinicalAttendanceState? filterState,
    bool? sortUnrecordedFirst,
    bool clearFilterShift = false,
    bool clearFilterState = false,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return GroupClinicalState(
      groupId: groupId ?? this.groupId,
      date: date ?? this.date,
      departmentName: departmentName ?? this.departmentName,
      departmentId: departmentId ?? this.departmentId,
      doctorName: doctorName ?? this.doctorName,
      rawItems: rawItems ?? this.rawItems,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      searchQuery: searchQuery ?? this.searchQuery,
      filterShift: clearFilterShift ? null : (filterShift ?? this.filterShift),
      filterState: clearFilterState ? null : (filterState ?? this.filterState),
      sortUnrecordedFirst: sortUnrecordedFirst ?? this.sortUnrecordedFirst,
    );
  }
}

class GroupClinicalNotifier extends StateNotifier<GroupClinicalState> {
  final ClinicalTrainingRepository _repo;

  GroupClinicalNotifier(this._repo, String groupId)
      : super(GroupClinicalState(
          groupId: groupId,
          date: AppTimezoneHelper.serverNowUtc,
        )) {
    loadDailyData();
  }

  Future<void> loadDailyData([DateTime? date]) async {
    final targetDate = date ?? state.date;
    state = state.copyWith(isLoading: true, date: targetDate, clearError: true, clearSuccess: true);

    try {
      final res = await _repo.fetchGroupDailyData(
        groupId: state.groupId,
        date: targetDate,
      );

      state = state.copyWith(
        rawItems: res.items,
        departmentName: res.departmentName,
        departmentId: res.departmentId,
        doctorName: res.doctorName,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'تعذر تحميل بيانات المرور اليومي: $e',
      );
    }
  }

  void setSearchQuery(String q) {
    state = state.copyWith(searchQuery: q);
  }

  void setFilterShift(ShiftType? shift) {
    state = state.copyWith(
      filterShift: shift,
      clearFilterShift: shift == null,
    );
  }

  void setFilterState(ClinicalAttendanceState? status) {
    state = state.copyWith(
      filterState: status,
      clearFilterState: status == null,
    );
  }

  void toggleSortOrder() {
    state = state.copyWith(sortUnrecordedFirst: !state.sortUnrecordedFirst);
  }

  /// Single tap quick status change in-memory
  void updateStudentPendingState(String studentId, ClinicalAttendanceState newState) {
    final updated = state.rawItems.map((item) {
      if (item.studentId == studentId) {
        return item.copyWith(
          pendingState: newState,
          isDirty: true,
        );
      }
      return item;
    }).toList();

    state = state.copyWith(rawItems: updated);
  }

  /// Mark all unrecorded students as Present in memory (explicit save still required)
  void markAllUnrecordedAsPresent() {
    final updated = state.rawItems.map((item) {
      if (item.pendingState == ClinicalAttendanceState.unrecorded) {
        return item.copyWith(
          pendingState: ClinicalAttendanceState.present,
          isDirty: true,
        );
      }
      return item;
    }).toList();

    state = state.copyWith(
      rawItems: updated,
      successMessage: 'تم تحديد جميع غير المسجلين كـ "موجود". اضغط حفظ لتأكيد السجل.',
    );
  }

  /// Batch commit attendance modifications to database
  Future<bool> commitAttendanceBatch() async {
    state = state.copyWith(isSaving: true, clearError: true, clearSuccess: true);

    final modified = state.rawItems
        .where((i) => i.isDirty || i.pendingState != ClinicalAttendanceState.unrecorded)
        .toList();

    if (modified.isEmpty) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'لا توجد تعديلات جديدة لحفظها.',
      );
      return false;
    }

    final List<Map<String, dynamic>> recordsPayload = modified.map((i) {
      String statusStr = 'present';
      if (i.pendingState == ClinicalAttendanceState.absent) {
        statusStr = 'absent';
      } else if (i.pendingState == ClinicalAttendanceState.present) {
        statusStr = 'present';
      }

      return {
        'student_id': i.studentId,
        'status': statusStr,
        'department_id': state.departmentId ?? i.todayShift?.departmentId,
        'notes': 'مرور صباحي 8:30 معتمد',
      };
    }).toList();

    final success = await _repo.saveMorningAttendanceBatch(
      records: recordsPayload,
      date: state.date,
    );

    if (success) {
      await loadDailyData(state.date);
      state = state.copyWith(
        isSaving: false,
        successMessage: '✅ تم حفظ واعتماد كشف المرور بنجاح (${modified.length} طالب)',
      );
      return true;
    } else {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'حدث خطأ أثناء حفظ بيانات المرور. يرجى المحاولة ثانية.',
      );
      return false;
    }
  }

  /// Record clinical exception (عارضة)
  Future<bool> addException({
    required String studentId,
    String? note,
  }) async {
    try {
      await _repo.addClinicalException(
        studentId: studentId,
        date: state.date,
        note: note,
      );
      await loadDailyData(state.date);
      state = state.copyWith(
        successMessage: 'تم تسجيل العارضة واعتماد أثرها بنجاح ✅',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'تعذر إضافة العارضة: ${e.toString().replaceAll('Exception:', '')}',
      );
      return false;
    }
  }

  /// Record clinical early leave / permission (ترك عمل)
  Future<bool> addPermission({
    required String studentId,
    required String leaveTime,
    String? reason,
  }) async {
    try {
      await _repo.addClinicalPermission(
        studentId: studentId,
        date: state.date,
        leaveTime: leaveTime,
        reason: reason,
      );
      await loadDailyData(state.date);
      state = state.copyWith(
        successMessage: 'تم منح إذن ترك العمل بنجاح ✅',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'تعذر تسجيل إذن ترك العمل: $e',
      );
      return false;
    }
  }

  /// Record clinical compensation (تعويض)
  Future<bool> addCompensation({
    required String studentId,
    required DateTime compensationDate,
    required ShiftType shiftType,
    DateTime? originalDate,
    String? reason,
    String? notes,
  }) async {
    try {
      await _repo.addClinicalCompensation(
        studentId: studentId,
        compensationDate: compensationDate,
        shiftType: shiftType,
        originalDate: originalDate,
        reason: reason,
        notes: notes,
      );
      await loadDailyData(state.date);
      state = state.copyWith(
        successMessage: 'تم تسجيل التعويض وتحديده بالروستر بنجاح ✅',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'تعذر تسجيل التعويض: $e',
      );
      return false;
    }
  }
}

final groupClinicalProvider =
    StateNotifierProvider.family<GroupClinicalNotifier, GroupClinicalState, String>(
        (ref, groupId) {
  final repo = ref.watch(clinicalTrainingRepositoryProvider);
  return GroupClinicalNotifier(repo, groupId);
});

/// Family provider for student clinical profile
final studentClinicalProfileProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, studentId) async {
  final repo = ref.watch(clinicalTrainingRepositoryProvider);
  return await repo.fetchStudentClinicalProfile(studentId);
});

/// Query parameter object for monthly group reports provider
class GroupReportQuery {
  final String groupId;
  final int year;
  final int month;

  const GroupReportQuery({
    required this.groupId,
    required this.year,
    required this.month,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupReportQuery &&
          runtimeType == other.runtimeType &&
          groupId == other.groupId &&
          year == other.year &&
          month == other.month;

  @override
  int get hashCode => groupId.hashCode ^ year.hashCode ^ month.hashCode;
}

/// Family provider for monthly group reports
final groupReportsProvider =
    FutureProvider.family<Map<String, dynamic>, GroupReportQuery>(
        (ref, param) async {
  final repo = ref.watch(clinicalTrainingRepositoryProvider);
  return await repo.fetchGroupMonthlyReports(
    groupId: param.groupId,
    year: param.year,
    month: param.month,
  );
});
