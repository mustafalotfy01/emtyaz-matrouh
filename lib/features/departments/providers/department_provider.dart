import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/models/user_profile.dart';
import '../models/department.dart';
import '../repositories/department_repository.dart';

final departmentRepositoryProvider = Provider<DepartmentRepository>((ref) {
  return DepartmentRepository();
});

class DepartmentsNotifier extends StateNotifier<AsyncValue<List<Department>>> {
  final DepartmentRepository _repository;

  DepartmentsNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadDepartments();
  }

  Future<void> loadDepartments() async {
    try {
      state = const AsyncValue.loading();
      final list = await _repository.fetchDepartments();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createDepartment({
    required String nameAr,
    required String nameEn,
    String? description,
    required int maleCapacity,
    required int femaleCapacity,
  }) async {
    await _repository.createDepartment(
      nameAr: nameAr,
      nameEn: nameEn,
      description: description,
      maleCapacity: maleCapacity,
      femaleCapacity: femaleCapacity,
    );
    await loadDepartments();
  }

  Future<void> updateDepartment(Department department) async {
    await _repository.updateDepartment(department);
    await loadDepartments();
  }

  Future<void> toggleStatus(String departmentId, bool isActive) async {
    await _repository.toggleDepartmentStatus(departmentId, isActive);
    await loadDepartments();
  }

  Future<void> deleteDepartment(String departmentId) async {
    await _repository.deleteDepartment(departmentId);
    await loadDepartments();
  }

  Future<void> assignDoctor({
    required String departmentId,
    required String doctorId,
    required int maleCapacity,
    required int femaleCapacity,
    String? assignedBy,
  }) async {
    await _repository.assignDoctorToDepartment(
      departmentId: departmentId,
      doctorId: doctorId,
      maleCapacity: maleCapacity,
      femaleCapacity: femaleCapacity,
      assignedBy: assignedBy,
    );
    await loadDepartments();
  }

  Future<void> removeDoctorAssignment(String supervisorId, String departmentId) async {
    await _repository.removeDoctorAssignment(supervisorId, departmentId);
    await loadDepartments();
  }
}

final departmentsProvider =
    StateNotifierProvider<DepartmentsNotifier, AsyncValue<List<Department>>>((ref) {
  final repo = ref.watch(departmentRepositoryProvider);
  return DepartmentsNotifier(repo);
});

final evaluatingDoctorsProvider = FutureProvider<List<UserProfile>>((ref) async {
  final repo = ref.watch(departmentRepositoryProvider);
  return repo.fetchEvaluatingDoctors();
});

final doctorDutiesProvider =
    FutureProvider.family<List<DoctorDepartmentDuty>, String>((ref, doctorId) async {
  final repo = ref.watch(departmentRepositoryProvider);
  return repo.fetchDoctorDuties(doctorId);
});

final distributionMatrixProvider =
    FutureProvider<List<DistributionMatrixRow>>((ref) async {
  final repo = ref.watch(departmentRepositoryProvider);
  return repo.fetchDistributionMatrix();
});
