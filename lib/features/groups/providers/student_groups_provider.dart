import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/models/user_profile.dart';
import '../../departments/models/department.dart';
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

  Future<void> loadGroups() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _repository.fetchGroups();
      state = state.copyWith(groups: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createGroup({
    required String name,
    String? description,
    String? departmentId,
    String? supervisorDoctorId,
  }) async {
    try {
      final created = await _repository.createGroup(
        name: name,
        description: description,
        departmentId: departmentId,
        supervisorDoctorId: supervisorDoctorId,
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

  Future<bool> updateGroup({
    required String groupId,
    required String name,
    String? description,
    String? departmentId,
    String? supervisorDoctorId,
    bool? isActive,
  }) async {
    try {
      final success = await _repository.updateGroup(
        groupId: groupId,
        name: name,
        description: description,
        departmentId: departmentId,
        supervisorDoctorId: supervisorDoctorId,
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
