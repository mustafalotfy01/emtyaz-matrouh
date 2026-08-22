import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/roster_entry.dart';
import '../models/roster_month.dart';
import '../providers/final_roster_provider.dart';
import '../providers/roster_provider.dart';
import '../services/final_roster_service.dart';
import 'student_roster_screen.dart';

class FinalApprovedRosterScreen extends ConsumerWidget {
  final bool isEmbeddedInTabs;
  const FinalApprovedRosterScreen({super.key, this.isEmbeddedInTabs = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isLeader = user?.role == UserRole.leader || user?.role == UserRole.superAdmin;
    final l10n = context.l10n;

    final selectedMonth = ref.watch(activeFinalRosterMonthProvider);
    final monthMetaAsync = ref.watch(finalRosterMonthMetaProvider);

    final entriesAsync = isLeader
        ? ref.watch(finalApprovedRosterProvider)
        : ref.watch(studentFinalApprovedRosterProvider);

    final editState = ref.watch(finalRosterEditProvider);

    final content = RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(finalApprovedRosterProvider);
        ref.invalidate(studentFinalApprovedRosterProvider);
        ref.invalidate(finalRosterMonthMetaProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 1. Month Navigation Header ────────────────────────────────
          _buildMonthSelectorCard(context, selectedMonth, l10n, ref),

          const SizedBox(height: 12),

            // ── 2. Official Status Banner ──────────────────────────────────
            monthMetaAsync.when(
              data: (meta) {
                final isPublished = meta.isPublished;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isPublished ? const Color(0xFFECFDF5).withOpacity(0.9) : const Color(0xFFFFFBEB).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPublished ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPublished ? Icons.check_circle : Icons.hourglass_top,
                        color: isPublished ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isPublished
                              ? '🟢 ${l10n.approvedRosterBannerTitle} (${selectedMonth.month}/${selectedMonth.year})'
                              : l10n.notApprovedYet,
                          style: TextStyle(
                            color: isPublished ? const Color(0xFF065F46) : const Color(0xFF92400E),
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      if (isLeader && !editState.isEditMode)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.edit, size: 14),
                          label: Text(l10n.editApprovedRoster, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => entriesAsync.whenData((entries) {
                            _confirmAndEnterEditMode(context, entries, l10n, ref);
                          }),
                        ),
                      if (isLeader && editState.isEditMode)
                        TextButton(
                          onPressed: () => ref.read(finalRosterEditProvider.notifier).cancelEditMode(),
                          child: Text(l10n.cancelEditMode, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 12),

            // ── 3. Student Proposal Navigation Fallback Banner ─────────────
            if (!isLeader)
              monthMetaAsync.when(
                data: (meta) {
                  if (!meta.isPublished) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline, color: AppColors.primaryTeal, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.notApprovedYet,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text(context)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.notApprovedSub,
                            style: TextStyle(fontSize: 11.5, color: AppColors.subtext(context)),
                          ),
                          const SizedBox(height: 10),
                          CustomButton(
                            text: l10n.goToPreferences,
                            icon: Icons.edit_calendar,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const StudentRosterScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

            // ── 4. Main Calendar Surface ──────────────────────────────────
            entriesAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return CustomCard(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.event_busy, size: 54, color: AppColors.textMuted),
                          const SizedBox(height: 14),
                          Text(
                            l10n.notApprovedYet,
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isLeader
                                ? (l10n.isArabic ? 'يمكنك مراجعة رغبات الطلاب واعتماد الروستر عبر تبويب مراجعة التفضيلات.' : 'Review student proposals and approve the roster in the Preferences tab.')
                                : l10n.notApprovedSub,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11.5, color: AppColors.subtext(context)),
                          ),
                          // Leader-only: show sync button when roster is published but has no entries
                          if (isLeader)
                            monthMetaAsync.when(
                              data: (meta) {
                                if (meta.isPublished) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0F766E),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(Icons.sync, size: 16),
                                      label: Text(
                                        l10n.isArabic ? 'استيراد الرغبات للروستر المعتمد' : 'Sync Preferences to Approved Roster',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      onPressed: () async {
                                        if (user == null) return;
                                        final res = await FinalRosterService.syncAllStudentPreferencesToApprovedRoster(
                                          month: selectedMonth.month,
                                          year: selectedMonth.year,
                                          leaderId: user.id,
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(res['message'] ?? ''),
                                              backgroundColor: res['success'] == true ? AppColors.success : AppColors.danger,
                                            ),
                                          );
                                          if (res['success'] == true) {
                                            ref.invalidate(finalApprovedRosterProvider);
                                            ref.invalidate(studentFinalApprovedRosterProvider);
                                            ref.invalidate(finalRosterMonthMetaProvider);
                                          }
                                        }
                                      },
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) => const SizedBox.shrink(),
                            ),
                        ],
                      ),
                    ),
                  );
                }

                return CustomCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _buildWeekdayHeaders(context, l10n),
                      const SizedBox(height: 8),
                      _buildDaysGrid(
                        context,
                        month: selectedMonth.month,
                        year: selectedMonth.year,
                        entries: entries,
                        isLeader: isLeader,
                        isEditMode: editState.isEditMode,
                        l10n: l10n,
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => CustomCard(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text('${l10n.generalError}: $err', style: const TextStyle(color: AppColors.danger)),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── 5. Save & Re-approve Button in Edit Mode ───────────────────
            if (isLeader && editState.isEditMode)
              CustomButton(
                text: l10n.saveApprovedRoster,
                icon: Icons.save,
                isLoading: editState.isSaving,
                onPressed: () async {
                  final ok = await ref.read(finalRosterEditProvider.notifier).saveAndReapprove();
                  if (ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.saveSuccess),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
              ),

          ],
        ),
      );

    if (isEmbeddedInTabs) {
      return Material(
        color: AppColors.bg(context),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.approvedRosterTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5, color: AppColors.text(context))),
            Text(l10n.approvedRosterBannerTitle, style: TextStyle(fontSize: 10.5, color: AppColors.subtext(context))),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.isArabic ? 'تحديث الروستر من الخادم' : 'Refresh Roster',
            icon: Icon(Icons.refresh, color: AppColors.text(context)),
            onPressed: () {
              ref.invalidate(finalApprovedRosterProvider);
              ref.invalidate(studentFinalApprovedRosterProvider);
              ref.invalidate(finalRosterMonthMetaProvider);
            },
          ),
        ],
      ),
      body: content,
    );
  }

  // ── Month Selector Header ───────────────────────────────────────────────
  Widget _buildMonthSelectorCard(BuildContext context, RosterMonth current, AppLocalizations l10n, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month, color: AppColors.primaryTeal, size: 20),
          const SizedBox(width: 8),
          Text(
            l10n.isArabic ? 'الشهر المعتمد:' : 'Approved Month:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.text(context)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: current.month,
                isDense: true,
                isExpanded: true,
                dropdownColor: AppColors.card(context),
                items: [
                  for (int m = 1; m <= 12; m++)
                    DropdownMenuItem(
                      value: m,
                      child: Text(
                        '${l10n.isArabic ? "شهر" : "Month"} $m (${_getMonthName(m, l10n)}) ${current.year}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: m == current.month ? FontWeight.bold : FontWeight.normal,
                          color: AppColors.text(context),
                        ),
                      ),
                    ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    final target = RosterMonth.getAvailableMonths().firstWhere(
                      (m) => m.month == val && m.year == current.year,
                      orElse: () => RosterMonth(
                        id: '00000000-0000-0000-0000-${current.year.toString().padLeft(4, '0')}${val.toString().padLeft(2, '0')}000000',
                        title: 'روستر شهر $val ${current.year}',
                        month: val,
                        year: current.year,
                        status: RosterMonthStatus.published,
                        isPublished: true,
                      ),
                    );
                    ref.read(currentRosterMonthProvider.notifier).state = target;
                    ref.read(activeFinalRosterMonthProvider.notifier).state = target;
                    ref.read(leaderRosterProvider.notifier).loadDashboard();
                    ref.invalidate(finalApprovedRosterProvider);
                    ref.invalidate(studentFinalApprovedRosterProvider);
                    ref.invalidate(finalRosterMonthMetaProvider);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int m, AppLocalizations l10n) {
    const namesAr = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    const namesEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (m >= 1 && m <= 12) {
      return l10n.isArabic ? namesAr[m - 1] : namesEn[m - 1];
    }
    return '';
  }

  Widget _buildWeekdayHeaders(BuildContext context, AppLocalizations l10n) {
    final days = [l10n.sat, l10n.sun, l10n.mon, l10n.tue, l10n.wed, l10n.thu, l10n.fri];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: days.map((d) {
        return Expanded(
          child: Center(
            child: Text(
              d,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.subtext(context)),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Monthly Days Grid ───────────────────────────────────────────────────
  Widget _buildDaysGrid(
    BuildContext context, {
    required int month,
    required int year,
    required List<RosterEntry> entries,
    required bool isLeader,
    required bool isEditMode,
    required AppLocalizations l10n,
  }) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDayOfMonth = DateTime(year, month, 1);
    final int startOffset = (firstDayOfMonth.weekday + 1) % 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 0.85,
      ),
      itemCount: startOffset + daysInMonth,
      itemBuilder: (context, index) {
        if (index < startOffset) {
          return const SizedBox.shrink();
        }

        final dayNumber = index - startOffset + 1;
        final date = DateTime(year, month, dayNumber);

        final dayEntries = entries.where((e) =>
            e.shiftDate.year == year &&
            e.shiftDate.month == month &&
            e.shiftDate.day == dayNumber).toList();

        final hasShift = dayEntries.isNotEmpty;

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (isLeader) {
              _openLeaderDayHierarchySheet(context, date, dayEntries, l10n);
            } else if (hasShift) {
              _openStudentShiftDetailsSheet(context, dayEntries.first, l10n);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: hasShift
                  ? (isLeader ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFF10B981))
                  : AppColors.card(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasShift ? const Color(0xFF059669) : AppColors.border(context),
                width: hasShift ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dayNumber',
                  style: TextStyle(
                    color: hasShift
                        ? (isLeader ? const Color(0xFF10B981) : Colors.white)
                        : AppColors.text(context),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                if (hasShift) ...[
                  if (isLeader)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${dayEntries.length} ${l10n.isArabic ? "طلاب" : "std"}',
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        dayEntries.first.shiftType == ShiftType.night
                            ? l10n.shiftNightShort
                            : (dayEntries.first.shiftType == ShiftType.long ? l10n.shiftLongShort : l10n.shiftMorningShort),
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                ] else
                  Text(
                    l10n.shiftRest,
                    style: TextStyle(color: AppColors.subtext(context), fontSize: 8),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Leader Hierarchical Inspection: Day → Dept → Shift → Students ───────
  void _openLeaderDayHierarchySheet(
    BuildContext context,
    DateTime date,
    List<RosterEntry> entries,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final Map<String, List<RosterEntry>> deptGroups = {};
        for (final e in entries) {
          final deptName = e.departmentName.isNotEmpty ? e.departmentName : l10n.deptEmergencyShort;
          deptGroups.putIfAbsent(deptName, () => []).add(e);
        }

        return Container(
          padding: const EdgeInsets.all(20.0),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today, color: AppColors.primaryTeal, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    '${date.day} ${_getMonthName(date.month, l10n)} ${date.year}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text(context)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${l10n.isArabic ? "إجمالي الطلاب المعينين رسمياً:" : "Total Assigned Interns:"} ${entries.length}',
                style: TextStyle(fontSize: 12, color: AppColors.subtext(context)),
              ),
              Divider(height: 20, color: AppColors.border(context)),

              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Center(
                    child: Text(
                      l10n.isArabic ? 'لا يوجد طلاب معينين في هذا اليوم (يوم راحة عامة).' : 'No interns scheduled for this day (Rest Day).',
                      style: TextStyle(color: AppColors.subtext(context)),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    children: deptGroups.entries.map((deptEntry) {
                      final deptName = deptEntry.key;
                      final deptShifts = deptEntry.value;

                      final morningList = deptShifts.where((s) => s.shiftType == ShiftType.morning).toList();
                      final longList = deptShifts.where((s) => s.shiftType == ShiftType.long).toList();
                      final nightList = deptShifts.where((s) => s.shiftType == ShiftType.night).toList();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.primaryTeal,
                            foregroundColor: Colors.white,
                            radius: 16,
                            child: Icon(Icons.local_hospital, size: 18),
                          ),
                          title: Text(
                            deptName,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.text(context)),
                          ),
                          subtitle: Text(
                            '${deptShifts.length} ${l10n.isArabic ? "طلاب معينين" : "assigned"}',
                            style: TextStyle(fontSize: 11, color: AppColors.subtext(context)),
                          ),
                          children: [
                            Divider(height: 1, color: AppColors.border(context)),
                            if (morningList.isNotEmpty)
                              _buildShiftCategorySection(context, '${l10n.shiftMorningShort} (${l10n.shiftMorningTiming})', morningList, const Color(0xFF0284C7), l10n),
                            if (longList.isNotEmpty)
                              _buildShiftCategorySection(context, '${l10n.shiftLongShort} (${l10n.shiftLongTiming})', longList, const Color(0xFF7C3AED), l10n),
                            if (nightList.isNotEmpty)
                              _buildShiftCategorySection(context, '${l10n.shiftNightShort} (${l10n.shiftNightTiming})', nightList, const Color(0xFF1E293B), l10n),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShiftCategorySection(BuildContext context, String title, List<RosterEntry> students, Color color, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        border: Border(bottom: BorderSide(color: AppColors.border(context))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(
                '$title — (${students.length}):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: students.map((s) {
              return Chip(
                backgroundColor: AppColors.card(context),
                side: BorderSide(color: color.withOpacity(0.4)),
                label: Text(
                  s.studentName.isNotEmpty ? s.studentName : l10n.roleStudent,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Student Single Shift Inspection Bottom Sheet ───────────────────────
  void _openStudentShiftDetailsSheet(BuildContext context, RosterEntry shift, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card(context),
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: AppColors.border(context),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.verified_rounded, color: AppColors.success, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${shift.shiftDate.day} ${_getMonthName(shift.shiftDate.month, l10n)} ${shift.shiftDate.year}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.text(context)),
                      ),
                      Text(
                        l10n.statusApproved,
                        style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Department Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.muted(context),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_hospital_rounded, size: 20, color: AppColors.primaryTeal),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.isArabic ? 'القسم المعتمد' : 'Department', style: TextStyle(fontSize: 11.5, color: AppColors.subtext(context))),
                          Text(
                            shift.departmentName.isNotEmpty ? shift.departmentName : l10n.deptEmergencyShort,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.text(context)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Shift Timing Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.muted(context),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: shift.shiftType == ShiftType.night
                            ? AppColors.nightDarkBg
                            : (shift.shiftType == ShiftType.long ? AppColors.longPurpleBg : AppColors.morningBlueBg),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        shift.shiftType == ShiftType.night ? Icons.bedtime_rounded : Icons.wb_sunny_rounded,
                        size: 20,
                        color: shift.shiftType == ShiftType.night
                            ? AppColors.nightDark
                            : (shift.shiftType == ShiftType.long ? AppColors.longPurple : AppColors.morningBlue),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.isArabic ? 'نوع الشيفت والمواعيد' : 'Shift Type & Hours', style: TextStyle(fontSize: 11.5, color: AppColors.subtext(context))),
                          Text(
                            shift.shiftType == ShiftType.night ? l10n.shiftNightTiming : l10n.shiftLongTiming,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.text(context)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Attendance Status Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.primaryTeal, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.isArabic
                            ? 'يبدأ توثيق البصمة الجغرافية تلقائياً قبل موعد الشيفت بـ 30 دقيقة.'
                            : 'Geolocation check-in opens 30 minutes before shift start.',
                        style: const TextStyle(color: AppColors.primaryTeal, fontSize: 11.5, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Leader Confirmation Dialog to Enter Edit Mode ─────────────────────
  void _confirmAndEnterEditMode(BuildContext context, List<RosterEntry> currentEntries, AppLocalizations l10n, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            const SizedBox(width: 8),
            Text(l10n.editApprovedRoster),
          ],
        ),
        content: Text(
          l10n.isArabic
              ? 'أنت على وشك تعديل الروستر الرسمي المعتمد.\nهل تريد المتابعة في وضع التعديل؟'
              : 'You are about to edit the officially approved roster.\nDo you want to proceed?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ref.read(finalRosterEditProvider.notifier).enterEditMode(currentEntries);
    }
  }
}
