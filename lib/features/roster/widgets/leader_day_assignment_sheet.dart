import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/custom_card.dart';
import '../../auth/models/user_profile.dart';
import '../models/department.dart';
import '../models/roster_entry.dart';
import '../models/roster_preference.dart';
import '../models/student_roster_summary.dart';
import '../providers/roster_provider.dart';

class _StudentDatePreferenceInfo {
  final StudentRosterSummary summary;
  final PreferenceShiftType? requestedShiftType;
  final RosterEntry? assignedShift;

  _StudentDatePreferenceInfo({
    required this.summary,
    this.requestedShiftType,
    this.assignedShift,
  });
}

class LeaderDayAssignmentSheet extends ConsumerStatefulWidget {
  final DateTime date;
  final StudentGroup studentGroup;
  final List<StudentRosterSummary> allSummaries;

  const LeaderDayAssignmentSheet({
    super.key,
    required this.date,
    required this.studentGroup,
    required this.allSummaries,
  });

  @override
  ConsumerState<LeaderDayAssignmentSheet> createState() => _LeaderDayAssignmentSheetState();
}

class _LeaderDayAssignmentSheetState extends ConsumerState<LeaderDayAssignmentSheet> {
  ShiftType _selectedShiftType = ShiftType.night;
  String _selectedDeptId = 'a0000001-0000-0000-0000-000000000001';

  @override
  Widget build(BuildContext context) {
    final depts = ref.watch(departmentsProvider);
    final leaderState = ref.watch(leaderRosterProvider);
    final selectedDept = depts.firstWhere((d) => d.id == _selectedDeptId, orElse: () => depts.first);
    final l10n = context.l10n;

    // Group students matching this day
    final groupStudents = leaderState.summaries.where((s) => s.studentGroup == widget.studentGroup).toList();

    // Separate students who selected this date from those who didn't
    final List<_StudentDatePreferenceInfo> requestingStudents = [];
    final List<StudentRosterSummary> otherStudents = [];

    for (final student in groupStudents) {
      final matchPref = student.preferences.cast<RosterPreference?>().firstWhere(
        (p) =>
            p?.preferenceDate.year == widget.date.year &&
            p?.preferenceDate.month == widget.date.month &&
            p?.preferenceDate.day == widget.date.day,
        orElse: () => null,
      );

      final currentShift = student.assignedShifts.cast<RosterEntry?>().firstWhere(
        (s) =>
            s?.shiftDate.year == widget.date.year &&
            s?.shiftDate.month == widget.date.month &&
            s?.shiftDate.day == widget.date.day,
        orElse: () => null,
      );

      if (matchPref != null) {
        requestingStudents.add(
          _StudentDatePreferenceInfo(
            summary: student,
            requestedShiftType: matchPref.preferenceShiftType,
            assignedShift: currentShift,
          ),
        );
      } else {
        otherStudents.add(student);
      }
    }

    // Sort requesting students so Night/Long come first, then alphabetical
    requestingStudents.sort((a, b) {
      final aType = a.requestedShiftType;
      final bType = b.requestedShiftType;
      if (aType == PreferenceShiftType.night && bType != PreferenceShiftType.night) return -1;
      if (aType != PreferenceShiftType.night && bType == PreferenceShiftType.night) return 1;
      return a.summary.studentName.compareTo(b.summary.studentName);
    });

    final totalAssignedOnDay = groupStudents
        .where((s) => s.assignedShifts.any((e) =>
            e.shiftDate.year == widget.date.year &&
            e.shiftDate.month == widget.date.month &&
            e.shiftDate.day == widget.date.day))
        .length;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      padding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header: Date + Group + Assigned Counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.date.day}/${widget.date.month}/${widget.date.year}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(context),
                    ),
                  ),
                  Text(
                    '${l10n.isArabic ? "المجموعة الأساسية:" : "Target Group:"} ${widget.studentGroup == StudentGroup.groupA ? l10n.groupA : l10n.groupB}',
                    style: TextStyle(fontSize: 11.5, color: AppColors.subtext(context)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryTeal),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people, size: 16, color: AppColors.primaryTeal),
                    const SizedBox(width: 4),
                    Text(
                      '${l10n.isArabic ? "المعينين:" : "Assigned:"} $totalAssignedOnDay',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryTeal,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Department Selector Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: depts.map((d) {
                final isSelected = d.id == _selectedDeptId;
                final deptStudentCount = groupStudents.where((s) => s.assignedShifts.any((e) =>
                    e.shiftDate.year == widget.date.year &&
                    e.shiftDate.month == widget.date.month &&
                    e.shiftDate.day == widget.date.day &&
                    e.departmentId == d.id)).length;

                return Padding(
                  padding: const EdgeInsets.only(left: 6.0),
                  child: FilterChip(
                    label: Text('${l10n.isArabic ? d.nameAr : (d.nameEn.isNotEmpty ? d.nameEn : d.nameAr)} ($deptStudentCount)'),
                    selected: isSelected,
                    selectedColor: AppColors.primaryTeal,
                    backgroundColor: AppColors.muted(context),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.text(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    onSelected: (_) {
                      setState(() => _selectedDeptId = d.id);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 10),

          // Department Shift Breakdown Card
          Builder(
            builder: (context) {
              final deptShifts = <RosterEntry>[];
              for (final s in groupStudents) {
                for (final e in s.assignedShifts) {
                  if (e.shiftDate.year == widget.date.year &&
                      e.shiftDate.month == widget.date.month &&
                      e.shiftDate.day == widget.date.day &&
                      e.departmentId == selectedDept.id) {
                    deptShifts.add(e);
                  }
                }
              }

              final morningStudents = deptShifts.where((e) => e.shiftType == ShiftType.morning).toList();
              final longStudents = deptShifts.where((e) => e.shiftType == ShiftType.long).toList();
              final nightStudents = deptShifts.where((e) => e.shiftType == ShiftType.night).toList();

              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.muted(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${l10n.isArabic ? selectedDept.nameAr : (selectedDept.nameEn.isNotEmpty ? selectedDept.nameEn : selectedDept.nameAr)} (${deptShifts.length}):',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.text(context)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDeptShiftSummary(context, '${l10n.shiftMorningShort} (08-14)', morningStudents, const Color(0xFF0284C7)),
                        _buildDeptShiftSummary(context, '${l10n.shiftLongShort} (08-20)', longStudents, const Color(0xFF7C3AED)),
                        _buildDeptShiftSummary(context, '${l10n.shiftNightShort} (20-08)', nightStudents, const Color(0xFF1E293B)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // Shift Type Selector Card
          CustomCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.isArabic ? 'الشيفت المراد تعيينه للطلاب عند الضغط:' : 'Select shift to assign on click:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.text(context)),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    _buildShiftChoice(
                      label: l10n.shiftNightShort,
                      sub: '20:00 - 08:00',
                      type: ShiftType.night,
                      icon: Icons.nightlight_round,
                      color: const Color(0xFF1E293B),
                    ),
                    const SizedBox(width: 8),
                    _buildShiftChoice(
                      label: l10n.shiftLongShort,
                      sub: '08:00 - 20:00',
                      type: ShiftType.long,
                      icon: Icons.timelapse,
                      color: const Color(0xFF7C3AED),
                    ),
                    const SizedBox(width: 8),
                    _buildShiftChoice(
                      label: l10n.shiftMorningShort,
                      sub: '08:00 - 14:00',
                      type: ShiftType.morning,
                      icon: Icons.wb_sunny,
                      color: const Color(0xFF0284C7),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Students List
          Expanded(
            child: ListView(
              children: [
                // SECTION 1: Students who specifically picked this day
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 6),
                    Text(
                      '${l10n.isArabic ? "الطلاب الذين اختاروا هذا اليوم" : "Requested this day"} (${requestingStudents.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.text(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                if (requestingStudents.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.muted(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: Center(
                      child: Text(
                        l10n.isArabic ? 'لا يوجد طلاب اختاروا هذا اليوم بشكل مسبق.' : 'No students requested this day.',
                        style: TextStyle(color: AppColors.subtext(context), fontSize: 11),
                      ),
                    ),
                  )
                else
                  ...requestingStudents.map((info) {
                    return _buildStudentTile(
                      context: context,
                      summary: info.summary,
                      requestedShiftType: info.requestedShiftType,
                      assignedShift: info.assignedShift,
                      deptId: selectedDept.id,
                      deptName: l10n.isArabic ? selectedDept.nameAr : (selectedDept.nameEn.isNotEmpty ? selectedDept.nameEn : selectedDept.nameAr),
                      l10n: l10n,
                    );
                  }),

                const SizedBox(height: 14),

                // SECTION 2: Other students in group
                Row(
                  children: [
                    Icon(Icons.group, size: 16, color: AppColors.subtext(context)),
                    const SizedBox(width: 6),
                    Text(
                      '${l10n.isArabic ? "باقي طلاب المجموعة" : "Other interns in group"} (${otherStudents.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.subtext(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                if (otherStudents.isNotEmpty)
                  ...otherStudents.map((summary) {
                    final currentShift = summary.assignedShifts.cast<RosterEntry?>().firstWhere(
                      (s) =>
                          s?.shiftDate.year == widget.date.year &&
                          s?.shiftDate.month == widget.date.month &&
                          s?.shiftDate.day == widget.date.day,
                      orElse: () => null,
                    );

                    return _buildStudentTile(
                      context: context,
                      summary: summary,
                      requestedShiftType: null,
                      assignedShift: currentShift,
                      deptId: selectedDept.id,
                      deptName: l10n.isArabic ? selectedDept.nameAr : (selectedDept.nameEn.isNotEmpty ? selectedDept.nameEn : selectedDept.nameAr),
                      l10n: l10n,
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftChoice({
    required String label,
    required String sub,
    required ShiftType type,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedShiftType == type;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedShiftType = type),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : color.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : color),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : color,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
              Text(
                sub,
                style: TextStyle(
                  color: isSelected ? Colors.white70 : color.withOpacity(0.7),
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentTile({
    required BuildContext context,
    required StudentRosterSummary summary,
    required PreferenceShiftType? requestedShiftType,
    required RosterEntry? assignedShift,
    required String deptId,
    required String deptName,
    required AppLocalizations l10n,
  }) {
    final isAssigned = assignedShift != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: CustomCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Preference Badge
            if (requestedShiftType == PreferenceShiftType.morning)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF0284C7)),
                ),
                child: Text('${l10n.shiftMorningLetter} ${l10n.shiftMorningShort}', style: const TextStyle(color: Color(0xFF0369A1), fontSize: 9, fontWeight: FontWeight.bold)),
              )
            else if (requestedShiftType == PreferenceShiftType.longShift)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF7C3AED)),
                ),
                child: Text('${l10n.shiftLongLetter} ${l10n.shiftLongShort}', style: const TextStyle(color: Color(0xFF5B21B6), fontSize: 9, fontWeight: FontWeight.bold)),
              )
            else if (requestedShiftType == PreferenceShiftType.night)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${l10n.shiftNightLetter} ${l10n.shiftNightShort}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.muted(context),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(l10n.isArabic ? 'غير مختار' : 'None', style: TextStyle(color: AppColors.subtext(context), fontSize: 9)),
              ),

            const SizedBox(width: 10),

            // Student Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.studentName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text(context)),
                  ),
                  Text(
                    '${l10n.isArabic ? "المعين:" : "Set:"} ${summary.totalFinalShifts}/12 (${l10n.shiftNightLetter}: ${summary.finalNightCount}، ${l10n.shiftLongLetter}: ${summary.finalLongCount})',
                    style: TextStyle(fontSize: 10, color: AppColors.subtext(context)),
                  ),
                ],
              ),
            ),

            // Action Button
            if (isAssigned) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  assignedShift.shiftType == ShiftType.night
                      ? l10n.shiftNightShort
                      : (assignedShift.shiftType == ShiftType.long ? l10n.shiftLongShort : l10n.shiftMorningShort),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: l10n.isArabic ? 'إلغاء الشيفت' : 'Delete',
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                onPressed: () async {
                  await ref.read(leaderRosterProvider.notifier).removeShiftFromStudentOnDate(
                    studentId: summary.studentId,
                    date: widget.date,
                  );
                },
              ),
            ] else ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add, size: 14),
                label: Text('+ ${_selectedShiftType == ShiftType.night ? l10n.shiftNightShort : (_selectedShiftType == ShiftType.long ? l10n.shiftLongShort : l10n.shiftMorningShort)}', style: const TextStyle(fontSize: 11)),
                onPressed: () async {
                  if (summary.totalFinalShifts >= 12) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.isArabic ? 'تنبيه: ${summary.studentName} وصل بالفعل لـ 12 شيفت!' : 'Alert: ${summary.studentName} already reached 12 shifts!'),
                        backgroundColor: AppColors.warning,
                      ),
                    );
                  }

                  await ref.read(leaderRosterProvider.notifier).assignShiftToStudentOnDate(
                    studentId: summary.studentId,
                    studentName: summary.studentName,
                    date: widget.date,
                    shiftType: _selectedShiftType == ShiftType.night
                        ? PreferenceShiftType.night
                        : _selectedShiftType == ShiftType.long
                            ? PreferenceShiftType.longShift
                            : PreferenceShiftType.morning,
                    departmentId: deptId,
                    departmentName: deptName,
                    preferenceType: requestedShiftType?.code,
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeptShiftSummary(BuildContext context, String label, List<RosterEntry> students, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(
                '$label: ${students.length}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color),
              ),
            ],
          ),
          if (students.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              students.map((e) => e.studentName.split(' ').first).join('، '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}
