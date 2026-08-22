import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/disciplinary_action.dart';
import '../repositories/disciplinary_repository.dart';

final disciplinaryRepositoryProvider = Provider<DisciplinaryRepository>((ref) {
  return DisciplinaryRepository();
});

class DisciplineMetrics {
  final int totalWarnings;
  final int totalViolations;
  final int totalDeductions;
  final int totalAbsences;
  final int totalLates;
  final int totalRewards;
  final double attendancePercentage;

  DisciplineMetrics({
    required this.totalWarnings,
    required this.totalViolations,
    required this.totalDeductions,
    required this.totalAbsences,
    required this.totalLates,
    required this.totalRewards,
    required this.attendancePercentage,
  });
}

class DisciplinaryNotifier extends StateNotifier<AsyncValue<List<DisciplinaryAction>>> {
  final DisciplinaryRepository _repository;

  DisciplinaryNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadActions();
  }

  Future<void> loadActions() async {
    try {
      state = const AsyncValue.loading();
      final list = await _repository.fetchAllActions();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createDirectAdminAction({
    required String studentId,
    required String departmentId,
    required DisciplinaryActionType actionType,
    required String reason,
    required String description,
    required double deductionValue,
    String deductionUnit = 'points',
    int severity = 1,
    String? adminNote,
  }) async {
    await _repository.createDirectAdminAction(
      studentId: studentId,
      departmentId: departmentId,
      actionType: actionType,
      reason: reason,
      description: description,
      deductionValue: deductionValue,
      deductionUnit: deductionUnit,
      severity: severity,
      adminNote: adminNote,
    );
    await loadActions();
  }

  Future<void> createDoctorAction({
    required String studentId,
    required String departmentId,
    required DisciplinaryActionType actionType,
    required String reason,
    required String description,
    required double deductionValue,
    String deductionUnit = 'points',
    int severity = 1,
  }) async {
    await _repository.createDoctorAction(
      studentId: studentId,
      departmentId: departmentId,
      actionType: actionType,
      reason: reason,
      description: description,
      deductionValue: deductionValue,
      deductionUnit: deductionUnit,
      severity: severity,
    );
    await loadActions();
  }

  Future<void> approveAction(String actionId, {String? adminComment}) async {
    await _repository.approveAction(actionId: actionId, adminComment: adminComment);
    await loadActions();
  }

  Future<void> rejectAction(String actionId, String reason) async {
    await _repository.rejectAction(actionId: actionId, reason: reason);
    await loadActions();
  }

  DisciplineMetrics getStudentMetrics(String studentId) {
    final actions = state.maybeWhen(
      data: (list) => list.where((a) => a.studentId == studentId && a.status == ActionStatus.approved).toList(),
      orElse: () => <DisciplinaryAction>[],
    );

    final warnings = actions.where((a) => a.actionType == DisciplinaryActionType.warning || a.actionType == DisciplinaryActionType.finalWarning).length;
    final violations = actions.where((a) => a.actionType == DisciplinaryActionType.officialViolation || a.actionType == DisciplinaryActionType.behavioralViolation).length;
    final deductions = actions.where((a) => a.actionType == DisciplinaryActionType.deduction).length;
    final absences = actions.where((a) => a.actionType == DisciplinaryActionType.absence || a.actionType == DisciplinaryActionType.unexcusedAbsence).length;
    final lates = actions.where((a) => a.actionType == DisciplinaryActionType.lateCheckin).length;
    final rewards = actions.where((a) => a.actionType == DisciplinaryActionType.reward).length;

    final totalShifts = 12;
    final attendedShifts = totalShifts - absences;
    final attendancePct = (attendedShifts / totalShifts) * 100;

    return DisciplineMetrics(
      totalWarnings: warnings,
      totalViolations: violations,
      totalDeductions: deductions,
      totalAbsences: absences,
      totalLates: lates,
      totalRewards: rewards,
      attendancePercentage: attendancePct.clamp(0, 100),
    );
  }
}

final disciplinaryProvider =
    StateNotifierProvider<DisciplinaryNotifier, AsyncValue<List<DisciplinaryAction>>>((ref) {
  final repo = ref.watch(disciplinaryRepositoryProvider);
  return DisciplinaryNotifier(repo);
});

final studentDisciplinaryHistoryProvider =
    FutureProvider.family<List<DisciplinaryAction>, String>((ref, studentId) async {
  final repo = ref.watch(disciplinaryRepositoryProvider);
  return repo.fetchStudentActions(studentId);
});
