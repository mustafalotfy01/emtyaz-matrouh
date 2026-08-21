import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/disciplinary_action.dart';

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

class DisciplinaryNotifier extends StateNotifier<List<DisciplinaryAction>> {
  DisciplinaryNotifier() : super([]);

  void addAction(DisciplinaryAction action) {
    state = [action, ...state];
  }

  void approveAction(String actionId) {
    state = [
      for (final item in state)
        if (item.id == actionId) item.copyWith(status: ActionStatus.approved) else item
    ];
  }

  void cancelAction(String actionId) {
    state = [
      for (final item in state)
        if (item.id == actionId) item.copyWith(status: ActionStatus.cancelled) else item
    ];
  }

  DisciplineMetrics getStudentMetrics(String studentId) {
    final studentActions = state.where((a) => a.studentId == studentId && a.status != ActionStatus.cancelled).toList();

    final warnings = studentActions.where((a) => a.actionType == DisciplinaryActionType.warning || a.actionType == DisciplinaryActionType.finalWarning).length;
    final violations = studentActions.where((a) => a.actionType == DisciplinaryActionType.officialViolation || a.actionType == DisciplinaryActionType.behavioralViolation).length;
    final deductions = studentActions.where((a) => a.actionType == DisciplinaryActionType.deduction).length;
    final absences = studentActions.where((a) => a.actionType == DisciplinaryActionType.absence || a.actionType == DisciplinaryActionType.unexcusedAbsence).length;
    final lates = studentActions.where((a) => a.actionType == DisciplinaryActionType.lateCheckin).length;
    final rewards = studentActions.where((a) => a.actionType == DisciplinaryActionType.reward).length;

    // Calculate attendance percentage (e.g. 95%)
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

final disciplinaryProvider = StateNotifierProvider<DisciplinaryNotifier, List<DisciplinaryAction>>((ref) {
  return DisciplinaryNotifier();
});
