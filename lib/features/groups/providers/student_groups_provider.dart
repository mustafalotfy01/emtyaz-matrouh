import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/models/user_profile.dart';
import '../../departments/models/department.dart';
import '../models/group_monthly_department.dart';
import '../models/student_group.dart';
import '../repositories/student_groups_repository.dart';

final studentGroupsRepositoryProvider = Provider<StudentGroupsRepository>((ref) {
  return StudentGroupsRepository();
});

class StudentGroupsState {
  final List<StudentGroupModel> groups;
  final bool isLoading;
  final String? error;

  const StudentGroupsState({
    this.groups = const [],
    this.isLoading = false,
    this.error,
  });

  StudentGroupsState copyWith({
    List<StudentGroupModel>? groups,
    bool? isLoading,
    String? error,
  }) {
    return StudentGroupsState(
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class StudentGroupsNotifier extends StateNotifier<StudentGroupsState> {
  final StudentGroupsRepository _repository;

  StudentGroupsNotifier(this._repository) : super(const StudentGroupsState()) {
    loadGroups();
  }

  Future<void> loadGroups({int? year, int? month}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _repository.fetchGroups(year: year, month: month);
      state = state.copyWith(groups: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Create group with name and description only
  Future<bool> createGroup({
    required String name,
    String? description,
  }) async {
    try {
      final created = await _repository.createGroup(
        name: name,
        description: description,
      );
      if (created != null) {
        await loadGroups();
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Assign evaluating doctor directly to group
  Future<bool> assignDoctor({
    required String groupId,
    required String? doctorId,
  }) async {
    try {
      final success = await _repository.assignDoctorToGroup(
        groupId: groupId,
        doctorId: doctorId,
      );
      if (success) {
        await loadGroups();
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Assign monthly department to group
  Future<bool> setMonthlyDepartment({
    required String groupId,
    required String departmentId,
    required int year,
    required int month,
  }) async {
    try {
      final success = await _repository.setGroupMonthlyDepartment(
        groupId: groupId,
        departmentId: departmentId,
        year: year,
        month: month,
      );
      if (success) {
        await loadGroups();
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Fetch monthly timeline for a group
  Future<List<GroupMonthlyDepartmentModel>> fetchTimeline(String groupId) async {
    return _repository.fetchGroupMonthlyTimeline(groupId);
  }

  Future<bool> updateGroup({
    required String groupId,
    required String name,
    String? description,
    bool? isActive,
  }) async {
    try {
      final success = await _repository.updateGroup(
        groupId: groupId,
        name: name,
        description: description,
        isActive: isActive,
      );
      if (success) {
        await loadGroups();
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> assignStudent({
    required String studentId,
    required String groupId,
  }) async {
    final success = await _repository.assignStudentToGroup(
      studentId: studentId,
      groupId: groupId,
    );
    if (success) {
      await loadGroups();
    }
    return success;
  }

  Future<bool> removeStudent(String studentId) async {
    final success = await _repository.removeStudentFromGroup(studentId);
    if (success) {
      await loadGroups();
    }
    return success;
  }

  Future<bool> batchAssign({
    required List<String> studentIds,
    required String groupId,
  }) async {
    final success = await _repository.batchAssignStudents(
      studentIds: studentIds,
      groupId: groupId,
    );
    if (success) {
      await loadGroups();
    }
    return success;
  }
}

final studentGroupsProvider = StateNotifierProvider<StudentGroupsNotifier, StudentGroupsState>((ref) {
  final repo = ref.watch(studentGroupsRepositoryProvider);
  return StudentGroupsNotifier(repo);
});

final evaluatingDoctorsProvider = FutureProvider<List<UserProfile>>((ref) async {
  final repo = ref.watch(studentGroupsRepositoryProvider);
  return repo.fetchEvaluatingDoctors();
});

final activeDepartmentsProvider = FutureProvider<List<Department>>((ref) async {
  final repo = ref.watch(studentGroupsRepositoryProvider);
  return repo.fetchActiveDepartments();
});
