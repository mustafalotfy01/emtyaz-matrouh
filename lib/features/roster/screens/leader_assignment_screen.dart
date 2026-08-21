import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../auth/models/user_profile.dart';
import '../models/roster_entry.dart';
import '../models/roster_preference.dart';
import '../models/student_roster_summary.dart';
import '../providers/roster_provider.dart';
import '../services/suggestion_engine.dart';

class LeaderAssignmentScreen extends ConsumerStatefulWidget {
  final StudentRosterSummary summary;

  const LeaderAssignmentScreen({super.key, required this.summary});

  @override
  ConsumerState<LeaderAssignmentScreen> createState() => _LeaderAssignmentScreenState();
}

class _LeaderAssignmentScreenState extends ConsumerState<LeaderAssignmentScreen> {
  late List<RosterEntry> _workingShifts;

  @override
  void initState() {
    super.initState();
    _workingShifts = List.from(widget.summary.assignedShifts);
  }

  int get _nightCount => _workingShifts.where((s) => s.shiftType == ShiftType.night).length;
  int get _longCount => _workingShifts.where((s) => s.shiftType == ShiftType.long).length;
  int get _morningCount => _workingShifts.where((s) => s.shiftType == ShiftType.morning).length;
  int get _totalCount => _workingShifts.length;

  List<String> _getValidationWarnings(AppLocalizations l10n) {
    final warnings = <String>[];
    if (_totalCount < 12) {
      warnings.add(l10n.isArabic ? 'المجموع الحالي $_totalCount من 12 (ينقصك ${12 - _totalCount} شيفت).' : 'Current count $_totalCount of 12 (Need ${12 - _totalCount} more).');
    } else if (_totalCount > 12) {
      warnings.add(l10n.isArabic ? 'تنبيه: تم تجاوز النصاب المحدد ($_totalCount شيفت). المطلوب 12.' : 'Warning: Exceeded 12 shifts quota ($_totalCount).');
    }
    if (_nightCount < 2) {
      warnings.add(l10n.isArabic ? 'Night = $_nightCount (الحد الأدنى 2 شيفتات سهر).' : 'Night = $_nightCount (Minimum 2 night shifts).');
    }

    final sorted = List<RosterEntry>.from(_workingShifts)..sort((a, b) => a.shiftDate.compareTo(b.shiftDate));
    for (int i = 0; i < sorted.length - 1; i++) {
      final cur = sorted[i];
      final nxt = sorted[i + 1];
      if (nxt.shiftDate.difference(cur.shiftDate).inDays == 1) {
        if ((cur.shiftType == ShiftType.long || cur.shiftType == ShiftType.night) &&
            (nxt.shiftType == ShiftType.long || nxt.shiftType == ShiftType.night)) {
          warnings.add(l10n.isArabic ? 'تحذير راحة: شيفت ثقيل متتالي يوم ${cur.shiftDate.day} و ${nxt.shiftDate.day}' : 'Rest Warning: Consecutive heavy shifts on days ${cur.shiftDate.day} and ${nxt.shiftDate.day}');
        }
      }
    }
    return warnings;
  }

  void _applySuggestion() {
    final rosterMonth = ref.read(currentRosterMonthProvider);
    final suggested = SuggestionEngine.generateSuggestion1(
      studentId: widget.summary.studentId,
      studentName: widget.summary.studentName,
      studentGroup: widget.summary.studentGroup,
      rosterId: rosterMonth.id,
      month: rosterMonth.month,
      year: rosterMonth.year,
      preferences: widget.summary.preferences,
    );
    setState(() {
      _workingShifts = suggested;
    });
  }

  void _openAddShiftDialog(AppLocalizations l10n) {
    final depts = ref.read(departmentsProvider);
    final rosterMonth = ref.read(currentRosterMonthProvider);
    final isGroupA = widget.summary.studentGroup == StudentGroup.groupA;

    DateTime selectedDate = isGroupA
        ? DateTime(rosterMonth.year, rosterMonth.month, 1)
        : DateTime(rosterMonth.year, rosterMonth.month, 16);

    ShiftType selectedShift = ShiftType.night;
    String selectedDeptId = depts.first.id;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: AppColors.card(context),
              title: Text(l10n.isArabic ? 'إضافة شيفت للطالب' : 'Add Intern Shift', style: TextStyle(color: AppColors.text(context))),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: Text(l10n.isArabic ? 'اليوم المحدد' : 'Selected Date', style: TextStyle(color: AppColors.text(context))),
                      subtitle: Text(DateFormat('yyyy-MM-dd (EEEE)').format(selectedDate), style: TextStyle(color: AppColors.subtext(context))),
                      trailing: const Icon(Icons.calendar_today, color: AppColors.primaryTeal),
                      onTap: () async {
                        final daysInMonth = DateTime(rosterMonth.year, rosterMonth.month + 1, 0).day;
                        final firstD = isGroupA ? 1 : 16;
                        final lastD = isGroupA ? 15 : daysInMonth;

                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(rosterMonth.year, rosterMonth.month, firstD),
                          lastDate: DateTime(rosterMonth.year, rosterMonth.month, lastD),
                        );
                        if (picked != null) {
                          setDlgState(() => selectedDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedDeptId,
                      dropdownColor: AppColors.card(context),
                      decoration: InputDecoration(labelText: l10n.isArabic ? 'القسم' : 'Department'),
                      items: depts.map((d) => DropdownMenuItem(value: d.id, child: Text(l10n.isArabic ? d.nameAr : (d.nameEn.isNotEmpty ? d.nameEn : d.nameAr), style: TextStyle(color: AppColors.text(context))))).toList(),
                      onChanged: (val) {
                        if (val != null) setDlgState(() => selectedDeptId = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<ShiftType>(
                      value: selectedShift,
                      dropdownColor: AppColors.card(context),
                      decoration: InputDecoration(labelText: l10n.isArabic ? 'نوع الشيفت' : 'Shift Type'),
                      items: [ShiftType.night, ShiftType.long, ShiftType.morning, ShiftType.evening]
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(
                                  s == ShiftType.night
                                      ? l10n.shiftNightShort
                                      : (s == ShiftType.long ? l10n.shiftLongShort : l10n.shiftMorningShort),
                                  style: TextStyle(color: AppColors.text(context)),
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setDlgState(() => selectedShift = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
                  onPressed: () {
                    final dept = depts.firstWhere((d) => d.id == selectedDeptId);
                    setState(() {
                      _workingShifts.removeWhere((s) =>
                          s.shiftDate.year == selectedDate.year &&
                          s.shiftDate.month == selectedDate.month &&
                          s.shiftDate.day == selectedDate.day);

                      _workingShifts.add(
                        RosterEntry(
                          id: 'entry-${DateTime.now().millisecondsSinceEpoch}',
                          rosterId: rosterMonth.id,
                          studentId: widget.summary.studentId,
                          studentName: widget.summary.studentName,
                          departmentId: dept.id,
                          departmentName: l10n.isArabic ? dept.nameAr : (dept.nameEn.isNotEmpty ? dept.nameEn : dept.nameAr),
                          shiftDate: selectedDate,
                          shiftType: selectedShift,
                          status: ShiftStatus.approved,
                        ),
                      );
                    });
                    Navigator.pop(ctx);
                  },
                  child: Text(l10n.isArabic ? 'إضافة' : 'Add', style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final warnings = _getValidationWarnings(l10n);
    final rosterMonth = ref.watch(currentRosterMonthProvider);

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Text('${l10n.isArabic ? "توزيع" : "Assign"}: ${widget.summary.studentName}', style: TextStyle(color: AppColors.text(context), fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: l10n.isArabic ? 'تطبيق التوزيع المقترح' : 'Apply Auto-Distribution',
            icon: const Icon(Icons.auto_fix_high, color: AppColors.primaryTeal),
            onPressed: _applySuggestion,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Rules Engine Live Compliance Card
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.isArabic ? 'محرك القواعد والامتثال (Rules Engine)' : 'Shift Compliance Engine',
                      style: TextStyle(color: AppColors.text(context), fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    Text(
                      '$_totalCount / 12 ${l10n.isArabic ? "شيفت" : "shifts"}',
                      style: TextStyle(
                        color: _totalCount == 12 ? AppColors.success : AppColors.warning,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetric(context, '${l10n.shiftNightLetter} ${l10n.shiftNightShort}', _nightCount, 2),
                    _buildMetric(context, '${l10n.shiftLongLetter} ${l10n.shiftLongShort}', _longCount, null),
                    _buildMetric(context, '${l10n.shiftMorningLetter} ${l10n.shiftMorningShort}', _morningCount, null),
                  ],
                ),
                if (warnings.isNotEmpty) ...[
                  Divider(color: AppColors.border(context), height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: warnings.map((w) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16),
                            const SizedBox(width: 6),
                            Expanded(child: Text(w, style: const TextStyle(color: AppColors.warning, fontSize: 11))),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Student Preference Dates Palette
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.isArabic ? 'التواريخ المفضلة للطالب (اضغط لتعيين شيفت سريع):' : 'Preferred Intern Dates (Tap to quick assign):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text(context)),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.summary.preferences.map((p) {
                    final isAssigned = _workingShifts.any((s) =>
                        s.shiftDate.year == p.preferenceDate.year &&
                        s.shiftDate.month == p.preferenceDate.month &&
                        s.shiftDate.day == p.preferenceDate.day);

                    final chipColor = p.preferenceShiftType == PreferenceShiftType.morning
                        ? const Color(0xFFE0F2FE)
                        : p.preferenceShiftType == PreferenceShiftType.longShift
                            ? const Color(0xFFF3E8FF)
                            : const Color(0xFF1E293B);

                    final textColor = p.preferenceShiftType == PreferenceShiftType.morning
                        ? const Color(0xFF0369A1)
                        : p.preferenceShiftType == PreferenceShiftType.longShift
                            ? const Color(0xFF5B21B6)
                            : Colors.white;

                    final shiftLetter = p.preferenceShiftType == PreferenceShiftType.morning
                        ? l10n.shiftMorningLetter
                        : (p.preferenceShiftType == PreferenceShiftType.longShift ? l10n.shiftLongLetter : l10n.shiftNightLetter);

                    return ActionChip(
                      backgroundColor: isAssigned ? AppColors.success : chipColor,
                      label: Text(
                        '${p.preferenceDate.day} ($shiftLetter)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isAssigned ? Colors.white : textColor,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          final existsIndex = _workingShifts.indexWhere((s) =>
                              s.shiftDate.year == p.preferenceDate.year &&
                              s.shiftDate.month == p.preferenceDate.month &&
                              s.shiftDate.day == p.preferenceDate.day);

                          if (existsIndex >= 0) {
                            _workingShifts.removeAt(existsIndex);
                          } else {
                            final targetShift = p.preferenceShiftType == PreferenceShiftType.night
                                ? ShiftType.night
                                : p.preferenceShiftType == PreferenceShiftType.longShift
                                    ? ShiftType.long
                                    : ShiftType.morning;

                            _workingShifts.add(
                              RosterEntry(
                                id: 'entry-${DateTime.now().millisecondsSinceEpoch}',
                                rosterId: rosterMonth.id,
                                studentId: widget.summary.studentId,
                                studentName: widget.summary.studentName,
                                departmentId: 'a0000001-0000-0000-0000-000000000001',
                                departmentName: l10n.deptEmergencyShort,
                                shiftDate: p.preferenceDate,
                                shiftType: targetShift,
                                status: ShiftStatus.approved,
                              ),
                            );
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Working Shifts List
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${l10n.isArabic ? "الشيفتات المعينة" : "Assigned Shifts"} ($_totalCount / 12)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.text(context)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(l10n.isArabic ? 'إضافة شيفت يدوي' : 'Add Manual', style: const TextStyle(fontSize: 11)),
                      onPressed: () => _openAddShiftDialog(l10n),
                    ),
                  ],
                ),
                Divider(height: 20, color: AppColors.border(context)),

                if (_workingShifts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Center(
                      child: Text(
                        l10n.isArabic
                            ? 'لم يتم تعيين أي شيفتات بعد. اضغط على التواريخ أعلاه أو استخدم الاقتراح التلقائي.'
                            : 'No shifts assigned yet. Tap dates above or use auto-suggestion.',
                        style: TextStyle(color: AppColors.subtext(context), fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ..._workingShifts.map((entry) {
                    final shiftName = entry.shiftType == ShiftType.night
                        ? l10n.shiftNightShort
                        : (entry.shiftType == ShiftType.long ? l10n.shiftLongShort : l10n.shiftMorningShort);
                    final shiftLetter = entry.shiftType == ShiftType.night
                        ? l10n.shiftNightLetter
                        : (entry.shiftType == ShiftType.long ? l10n.shiftLongLetter : l10n.shiftMorningLetter);

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: entry.shiftType == ShiftType.night
                            ? const Color(0xFF1E293B)
                            : entry.shiftType == ShiftType.long
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFF0284C7),
                        child: Text(
                          shiftLetter,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      title: Text(
                        '${DateFormat('yyyy-MM-dd (EEEE)').format(entry.shiftDate)} — $shiftName',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.text(context)),
                      ),
                      subtitle: Text(entry.departmentName, style: TextStyle(fontSize: 10, color: AppColors.subtext(context))),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                        onPressed: () {
                          setState(() {
                            _workingShifts.removeWhere((s) => s.id == entry.id || (s.shiftDate == entry.shiftDate && s.studentId == entry.studentId));
                          });
                        },
                      ),
                    );
                  }),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Save Final Assignment Button
          CustomButton(
            text: '${l10n.isArabic ? "حفظ وتثبيت الشيفتات" : "Save & Lock Shifts"} ($_totalCount / 12)',
            icon: Icons.save,
            onPressed: () async {
              await ref.read(leaderRosterProvider.notifier).saveStudentAssignments(
                    widget.summary.studentId,
                    _workingShifts,
                  );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.saveSuccess),
                    backgroundColor: AppColors.success,
                  ),
                );
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildMetric(BuildContext context, String title, int count, int? target) {
    final isDone = target != null ? count >= target : count > 0;
    return Column(
      children: [
        Text(
          target != null ? '$count / $target' : '$count',
          style: TextStyle(
            color: isDone ? AppColors.success : AppColors.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(title, style: TextStyle(color: AppColors.subtext(context), fontSize: 10)),
      ],
    );
  }
}
