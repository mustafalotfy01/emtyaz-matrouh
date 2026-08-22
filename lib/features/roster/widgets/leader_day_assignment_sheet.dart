import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../models/roster_entry.dart';
import '../models/roster_preference.dart';
import '../models/student_roster_summary.dart';
import '../providers/roster_provider.dart';

class _StudentDatePreferenceInfo {
  final StudentRosterSummary summary;
  final PreferenceShiftType? requestedShiftType;
  final RosterEntry? assignedShift;
  final int weeklyHours;

  _StudentDatePreferenceInfo({
    required this.summary,
    this.requestedShiftType,
    this.assignedShift,
    required this.weeklyHours,
  });
}

class LeaderDayAssignmentSheet extends ConsumerStatefulWidget {
  final DateTime date;
  final List<StudentRosterSummary> allSummaries;

  const LeaderDayAssignmentSheet({
    super.key,
    required this.date,
    required this.allSummaries,
  });

  @override
  ConsumerState<LeaderDayAssignmentSheet> createState() => _LeaderDayAssignmentSheetState();
}

class _LeaderDayAssignmentSheetState extends ConsumerState<LeaderDayAssignmentSheet> {
  ShiftType _selectedShiftType = ShiftType.night;
  String _selectedDeptId = 'a0000001-0000-0000-0000-000000000001';
  String _searchQuery = '';

  int _calculateWeeklyHours(StudentRosterSummary student, DateTime date) {
    final int offsetToSat = (date.weekday + 1) % 7;
    final weekStart = DateTime(date.year, date.month, date.day).subtract(Duration(days: offsetToSat));
    final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59));

    int hours = 0;
    for (final s in student.assignedShifts) {
      if (!s.shiftDate.isBefore(weekStart) && !s.shiftDate.isAfter(weekEnd)) {
        hours += (s.shiftType == ShiftType.morning ? 6 : 12);
      }
    }
    return hours;
  }

  @override
  Widget build(BuildContext context) {
    final depts = ref.watch(departmentsProvider);
    final leaderState = ref.watch(leaderRosterProvider);
    final selectedDept = depts.firstWhere((d) => d.id == _selectedDeptId, orElse: () => depts.first);
    final l10n = context.l10n;

    final allStudents = leaderState.summaries;

    // Separate students who selected this date from those who didn't
    final List<_StudentDatePreferenceInfo> requestingStudents = [];
    final List<_StudentDatePreferenceInfo> otherStudents = [];

    for (final student in allStudents) {
      if (_searchQuery.isNotEmpty && !student.studentName.toLowerCase().contains(_searchQuery.toLowerCase())) {
        continue;
      }

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

      final weeklyHours = _calculateWeeklyHours(student, widget.date);

      final info = _StudentDatePreferenceInfo(
        summary: student,
        requestedShiftType: matchPref?.preferenceShiftType,
        assignedShift: currentShift,
        weeklyHours: weeklyHours,
      );

      if (matchPref != null) {
        requestingStudents.add(info);
      } else {
        otherStudents.add(info);
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

    final totalAssignedOnDay = allStudents
        .where((s) => s.assignedShifts.any((e) =>
            e.shiftDate.year == widget.date.year &&
            e.shiftDate.month == widget.date.month &&
            e.shiftDate.day == widget.date.day))
        .length;

    final dateFormatted = DateFormat('EEEE، d MMMM yyyy', l10n.isArabic ? 'ar' : 'en').format(widget.date);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
      padding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 24),
      decoration: BoxDecoration(
        color: AppDesignTokens.surface(context),
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
                color: AppDesignTokens.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header: Date + Assigned Counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateFormatted,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppDesignTokens.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'قاعدة الـ 36 ساعة أسبوعياً • إدارة التوزيع اليومي',
                    style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
                  ),
                ],
              ),
              AppBadge(
                label: '${l10n.isArabic ? "المعينين:" : "Assigned:"} $totalAssignedOnDay',
                variant: AppBadgeVariant.primary,
                size: AppBadgeSize.medium,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Department Selector Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: depts.map((d) {
                final isSelected = d.id == _selectedDeptId;
                final deptStudentCount = allStudents.where((s) => s.assignedShifts.any((e) =>
                    e.shiftDate.year == widget.date.year &&
                    e.shiftDate.month == widget.date.month &&
                    e.shiftDate.day == widget.date.day &&
                    e.departmentId == d.id)).length;

                return Padding(
                  padding: const EdgeInsets.only(left: 6.0),
                  child: FilterChip(
                    label: Text('${l10n.isArabic ? d.nameAr : (d.nameEn.isNotEmpty ? d.nameEn : d.nameAr)} ($deptStudentCount)'),
                    selected: isSelected,
                    selectedColor: AppDesignTokens.primary,
                    backgroundColor: AppDesignTokens.surfaceMuted(context),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppDesignTokens.textPrimary(context),
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
              for (final s in allStudents) {
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

              return AppCard(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${l10n.isArabic ? selectedDept.nameAr : (selectedDept.nameEn.isNotEmpty ? selectedDept.nameEn : selectedDept.nameAr)} (${deptShifts.length} معين):',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppDesignTokens.textPrimary(context)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDeptShiftSummary(context, 'صباحي (6h)', morningStudents, AppDesignTokens.shiftMorning),
                        _buildDeptShiftSummary(context, 'طويل (12h)', longStudents, AppDesignTokens.shiftLong),
                        _buildDeptShiftSummary(context, 'ليلي (12h)', nightStudents, AppDesignTokens.shiftNight),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          // Shift Type Selector Card
          AppCard(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.isArabic ? 'الشيفت المراد تعيينه للطلاب عند الضغط:' : 'Select shift to assign on click:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppDesignTokens.textPrimary(context)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildShiftChoice(
                      label: 'ليلي (Night)',
                      sub: '12 ساعة (20-08)',
                      type: ShiftType.night,
                      icon: Icons.nightlight_round,
                      color: AppDesignTokens.shiftNight,
                    ),
                    const SizedBox(width: 8),
                    _buildShiftChoice(
                      label: 'طويل (Long)',
                      sub: '12 ساعة (08-20)',
                      type: ShiftType.long,
                      icon: Icons.timelapse,
                      color: AppDesignTokens.shiftLong,
                    ),
                    const SizedBox(width: 8),
                    _buildShiftChoice(
                      label: 'صباحي (Morning)',
                      sub: '6 ساعات (08-14)',
                      type: ShiftType.morning,
                      icon: Icons.wb_sunny,
                      color: AppDesignTokens.shiftMorning,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

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
                        color: AppDesignTokens.textPrimary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                if (requestingStudents.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.surfaceMuted(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppDesignTokens.border(context)),
                    ),
                    child: Center(
                      child: Text(
                        l10n.isArabic ? 'لا يوجد طلاب اختاروا هذا اليوم في تفضيلاتهم.' : 'No students requested this day.',
                        style: TextStyle(color: AppDesignTokens.textSecondary(context), fontSize: 11),
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
                      weeklyHours: info.weeklyHours,
                      deptId: selectedDept.id,
                      deptName: l10n.isArabic ? selectedDept.nameAr : (selectedDept.nameEn.isNotEmpty ? selectedDept.nameEn : selectedDept.nameAr),
                      l10n: l10n,
                    );
                  }),

                const SizedBox(height: 14),

                // SECTION 2: Other students
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      Icon(Icons.group, size: 16, color: AppDesignTokens.textSecondary(context)),
                      const SizedBox(width: 6),
                      Text(
                        '${l10n.isArabic ? "باقي طلاب الدفعة" : "Other interns"} (${otherStudents.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppDesignTokens.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  children: otherStudents.map((info) {
                    return _buildStudentTile(
                      context: context,
                      summary: info.summary,
                      requestedShiftType: null,
                      assignedShift: info.assignedShift,
                      weeklyHours: info.weeklyHours,
                      deptId: selectedDept.id,
                      deptName: l10n.isArabic ? selectedDept.nameAr : (selectedDept.nameEn.isNotEmpty ? selectedDept.nameEn : selectedDept.nameAr),
                      l10n: l10n,
                    );
                  }).toList(),
                ),
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
    required int weeklyHours,
    required String deptId,
    required String deptName,
    required AppLocalizations l10n,
  }) {
    final isAssigned = assignedShift != null;
    final isOver36 = weeklyHours > 36;
    final isExact36 = weeklyHours == 36;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Preference Badge
            if (requestedShiftType == PreferenceShiftType.morning)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppDesignTokens.shiftMorningBgLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppDesignTokens.shiftMorning),
                ),
                child: const Text('طلب صباحي (6h)', style: TextStyle(color: AppDesignTokens.shiftMorning, fontSize: 9, fontWeight: FontWeight.bold)),
              )
            else if (requestedShiftType == PreferenceShiftType.longShift)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppDesignTokens.shiftLongBgLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppDesignTokens.shiftLong),
                ),
                child: const Text('طلب طويل (12h)', style: TextStyle(color: AppDesignTokens.shiftLong, fontSize: 9, fontWeight: FontWeight.bold)),
              )
            else if (requestedShiftType == PreferenceShiftType.night)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppDesignTokens.shiftNightBgLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppDesignTokens.shiftNight),
                ),
                child: const Text('طلب ليلي (12h)', style: TextStyle(color: AppDesignTokens.shiftNight, fontSize: 9, fontWeight: FontWeight.bold)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppDesignTokens.surfaceMuted(context),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(l10n.isArabic ? 'لم يطلب اليوم' : 'No Request', style: TextStyle(color: AppDesignTokens.textSecondary(context), fontSize: 9)),
              ),

            const SizedBox(width: 10),

            // Student Info & Weekly hours counter
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.studentName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppDesignTokens.textPrimary(context)),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'إجمالي: ${summary.totalFinalShifts}/12',
                        style: TextStyle(fontSize: 10, color: AppDesignTokens.textSecondary(context)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: isOver36
                              ? AppDesignTokens.dangerBgLight
                              : (isExact36 ? AppDesignTokens.successBgLight : AppDesignTokens.surfaceMuted(context)),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isOver36
                                ? AppDesignTokens.danger
                                : (isExact36 ? AppDesignTokens.success : AppDesignTokens.border(context)),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          'أسبوعياً: $weeklyHours/36h',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isOver36
                                ? AppDesignTokens.danger
                                : (isExact36 ? AppDesignTokens.success : AppDesignTokens.textSecondary(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Action Button
            if (isAssigned) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: assignedShift.shiftType == ShiftType.morning
                      ? AppDesignTokens.shiftMorning
                      : (assignedShift.shiftType == ShiftType.long ? AppDesignTokens.shiftLong : AppDesignTokens.shiftNight),
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
                icon: const Icon(Icons.delete_outline, size: 18, color: AppDesignTokens.danger),
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
                  backgroundColor: _selectedShiftType == ShiftType.morning
                      ? AppDesignTokens.shiftMorning
                      : (_selectedShiftType == ShiftType.long ? AppDesignTokens.shiftLong : AppDesignTokens.shiftNight),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add, size: 14),
                label: Text(
                  '+ ${_selectedShiftType == ShiftType.night ? l10n.shiftNightShort : (_selectedShiftType == ShiftType.long ? l10n.shiftLongShort : l10n.shiftMorningShort)}',
                  style: const TextStyle(fontSize: 11),
                ),
                onPressed: () async {
                  if (summary.totalFinalShifts >= 12) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.isArabic ? 'تنبيه: ${summary.studentName} وصل بالفعل لـ 12 شيفت!' : 'Alert: ${summary.studentName} already reached 12 shifts!'),
                        backgroundColor: AppDesignTokens.warning,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
              Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(
                '$label: ${students.length}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: color),
              ),
            ],
          ),
          if (students.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              students.map((e) => e.studentName.split(' ').first).take(3).join('، '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 8.5, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

