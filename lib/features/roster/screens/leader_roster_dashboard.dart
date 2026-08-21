import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/custom_card.dart';
import '../../auth/models/user_profile.dart';
import '../models/roster_entry.dart';
import '../models/roster_month.dart';
import '../models/roster_preference.dart';
import '../models/student_roster_summary.dart';
import '../providers/roster_provider.dart';
import '../widgets/leader_day_assignment_sheet.dart';
import 'leader_assignment_screen.dart';
import 'roster_overview_screen.dart';

class LeaderRosterDashboard extends ConsumerStatefulWidget {
  const LeaderRosterDashboard({super.key});

  @override
  ConsumerState<LeaderRosterDashboard> createState() => _LeaderRosterDashboardState();
}

class _LeaderRosterDashboardState extends ConsumerState<LeaderRosterDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openDayAssignmentSheet(DateTime date, StudentGroup group, List<StudentRosterSummary> summaries) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LeaderDayAssignmentSheet(
        date: date,
        studentGroup: group,
        allSummaries: summaries,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leaderState = ref.watch(leaderRosterProvider);
    final rosterMonth = ref.watch(currentRosterMonthProvider);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Text(l10n.leaderRosterManagementTitle, style: TextStyle(color: AppColors.text(context), fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: l10n.isArabic ? 'تحديث البيانات' : 'Refresh Data',
            icon: Icon(Icons.refresh, color: AppColors.text(context)),
            onPressed: () => ref.read(leaderRosterProvider.notifier).loadDashboard(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryTeal,
          labelColor: AppColors.primaryTeal,
          unselectedLabelColor: AppColors.subtext(context),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
          tabs: [
            Tab(icon: const Icon(Icons.calendar_month, size: 18), text: l10n.leaderCalendarSub),
            Tab(icon: const Icon(Icons.people_alt, size: 18), text: l10n.studentListFairnessTitle),
          ],
        ),
      ),
      body: leaderState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // ── TAB 1: Rapid Calendar Day Assignment View ─────────────────
                RefreshIndicator(
                  onRefresh: () => ref.read(leaderRosterProvider.notifier).loadDashboard(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Month Selector Card
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.history_toggle_off, color: AppColors.primaryTeal, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              l10n.isArabic ? 'الروستر المستهدف:' : 'Target Month:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.text(context)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: rosterMonth.id,
                                  isDense: true,
                                  isExpanded: true,
                                  dropdownColor: AppColors.card(context),
                                  items: RosterMonth.getAvailableMonths().map((m) {
                                    return DropdownMenuItem(
                                      value: m.id,
                                      child: Text(
                                        m.title,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: m.id == rosterMonth.id ? FontWeight.bold : FontWeight.normal,
                                          color: AppColors.text(context),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      final target = RosterMonth.getAvailableMonths().firstWhere((m) => m.id == val);
                                      ref.read(currentRosterMonthProvider.notifier).state = target;
                                      ref.read(leaderRosterProvider.notifier).loadDashboard();
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Month Status & Guidance Banner
                      CustomCard(
                        backgroundColor: AppColors.card(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  rosterMonth.title,
                                  style: TextStyle(
                                    color: AppColors.text(context),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.5,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: rosterMonth.isPublished ? AppColors.success : AppColors.primaryTeal,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    rosterMonth.isPublished ? l10n.statusApprovedShort : l10n.statusPending,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.isArabic
                                  ? '💡 اضغط على أي يوم في التقويم لتوزيع الشيفتات (سهر Night / طويل Long) ورؤية الطلاب الذين اختاروا اليوم.'
                                  : '💡 Tap any calendar day to assign shifts (Night / Long) and view student preferences.',
                              style: TextStyle(color: AppColors.subtext(context), fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Quick Action Buttons Row
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryTeal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.table_chart, size: 16),
                              label: Text(l10n.exportExcel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const RosterOverviewScreen()),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: rosterMonth.isPublished
                                ? ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFD97706),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.lock_open, size: 16),
                                    label: Text(l10n.editApprovedRoster, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: Text(l10n.editApprovedRoster),
                                          content: Text(
                                            l10n.isArabic
                                                ? 'هل أنت متأكد من فتح تعديل الروستر؟ سيتحول الروستر لحالة "مفتوح للتعديل" لتتمكن من تعديل التوزيعات.'
                                                : 'Are you sure you want to reopen the roster for editing?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: Text(l10n.cancel),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: Text(l10n.confirm, style: const TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm == true) {
                                        await ref.read(leaderRosterProvider.notifier).unpublishRoster();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(l10n.isArabic ? 'تم فتح تعديل الروستر بنجاح 🟡' : 'Roster reopened for edit 🟡'),
                                              backgroundColor: AppColors.warning,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  )
                                : ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.success,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.verified, size: 16),
                                    label: Text(l10n.approveAndPublishRoster, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: () async {
                                      final success = await ref
                                          .read(leaderRosterProvider.notifier)
                                          .publishRoster();
                                      if (context.mounted) {
                                        if (success) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(l10n.isArabic ? 'تم نشر واعتماد الروستر بنجاح 🟢' : 'Roster approved and published 🟢'),
                                              backgroundColor: AppColors.success,
                                            ),
                                          );
                                        } else if (leaderState.errorMessage != null) {
                                          showDialog(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: Text(l10n.isArabic ? 'تعذر نشر الروستر' : 'Publish Error', style: const TextStyle(color: AppColors.danger)),
                                              content: Text(leaderState.errorMessage!),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: Text(l10n.close),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Legend
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _CalendarLegendItem(color: const Color(0xFF0284C7), label: l10n.groupARange),
                          _CalendarLegendItem(color: const Color(0xFFF59E0B), label: l10n.groupBRange),
                          _CalendarLegendItem(color: const Color(0xFF10B981), label: l10n.isArabic ? '🟩 شيفتات معينة' : '🟩 Assigned'),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Interactive Calendar Grid for Leader
                      CustomCard(
                        padding: const EdgeInsets.all(12),
                        child: _buildLeaderCalendarGrid(context, rosterMonth.year, rosterMonth.month, leaderState.summaries, l10n),
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),

                // ── TAB 2: Students List & Fairness View ──────────────────────
                RefreshIndicator(
                  onRefresh: () => ref.read(leaderRosterProvider.notifier).loadDashboard(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(context, '${l10n.categoryAll} (${leaderState.summaries.length})', 'ALL', leaderState.filterGroup, (v) => ref.read(leaderRosterProvider.notifier).setFilterGroup(v)),
                            const SizedBox(width: 8),
                            _buildFilterChip(context, l10n.groupA, 'A', leaderState.filterGroup, (v) => ref.read(leaderRosterProvider.notifier).setFilterGroup(v)),
                            const SizedBox(width: 8),
                            _buildFilterChip(context, l10n.groupB, 'B', leaderState.filterGroup, (v) => ref.read(leaderRosterProvider.notifier).setFilterGroup(v)),
                            const SizedBox(width: 16),
                            _buildFilterChip(context, l10n.isArabic ? 'مكتمل الإرسال (12 يوم)' : 'Submitted (12 Days)', 'SUBMITTED', leaderState.filterStatus, (v) => ref.read(leaderRosterProvider.notifier).setFilterStatus(v)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      if (leaderState.filteredSummaries.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: AppColors.card(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border(context)),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.people_outline, size: 48, color: AppColors.textMuted),
                                const SizedBox(height: 10),
                                Text(
                                  l10n.isArabic ? 'لا يوجد طلاب مطابقين للفلتر الحالي' : 'No students match current filter',
                                  style: TextStyle(color: AppColors.text(context), fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.isArabic ? 'عند قيام الطلاب بالتسجيل واختيار المجموعات سيظهرون هنا تلقائياً.' : 'Registered students will automatically appear here.',
                                  style: TextStyle(color: AppColors.subtext(context), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...leaderState.filteredSummaries.map((summary) {
                          return _StudentSummaryCard(summary: summary);
                        }),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLeaderCalendarGrid(BuildContext context, int year, int month, List<StudentRosterSummary> summaries, AppLocalizations l10n) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDayOfMonth = DateTime(year, month, 1);
    final int startOffset = (firstDayOfMonth.weekday + 1) % 7;
    final weekDays = [l10n.sat, l10n.sun, l10n.mon, l10n.tue, l10n.wed, l10n.thu, l10n.fri];

    return Column(
      children: [
        // Weekday Headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekDays.map((day) {
            return Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.subtext(context),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 0.72,
          ),
          itemCount: startOffset + daysInMonth,
          itemBuilder: (context, index) {
            if (index < startOffset) return const SizedBox.shrink();

            final dayNumber = index - startOffset + 1;
            final date = DateTime(year, month, dayNumber);
            final isGroupA = dayNumber <= 15;
            final targetGroup = isGroupA ? StudentGroup.groupA : StudentGroup.groupB;

            int requestCount = 0;
            for (final s in summaries) {
              if (s.preferences.any((p) =>
                  p.preferenceDate.year == year &&
                  p.preferenceDate.month == month &&
                  p.preferenceDate.day == dayNumber)) {
                requestCount++;
              }
            }

            final List<RosterEntry> assignedEntriesOnDay = [];
            for (final s in summaries) {
              for (final e in s.assignedShifts) {
                if (e.shiftDate.year == year &&
                    e.shiftDate.month == month &&
                    e.shiftDate.day == dayNumber) {
                  assignedEntriesOnDay.add(e);
                }
              }
            }

            return InkWell(
              onTap: () => _openDayAssignmentSheet(date, targetGroup, summaries),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isGroupA ? const Color(0xFF0284C7).withOpacity(0.5) : const Color(0xFFF59E0B).withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Day Number + Group Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isGroupA ? const Color(0xFF0284C7) : const Color(0xFFB45309),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(
                            color: isGroupA ? const Color(0xFFE0F2FE) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            isGroupA ? 'A' : 'B',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: isGroupA ? const Color(0xFF0369A1) : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Assigned student names / summary indicator
                    if (assignedEntriesOnDay.isNotEmpty)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ...assignedEntriesOnDay.take(2).map((e) {
                              final firstName = e.studentName.split(' ').first;
                              final shiftInitial = e.shiftType == ShiftType.night
                                  ? l10n.shiftNightLetter
                                  : (e.shiftType == ShiftType.long ? l10n.shiftLongLetter : l10n.shiftMorningLetter);
                              return Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFF10B981), width: 0.5),
                                ),
                                child: Text(
                                  '$firstName ($shiftInitial)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              );
                            }),
                            if (assignedEntriesOnDay.length > 2)
                              Text(
                                '+${assignedEntriesOnDay.length - 2}',
                                style: const TextStyle(fontSize: 7, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '$requestCount ${l10n.isArabic ? "طلب" : "req"}',
                          style: TextStyle(fontSize: 8, color: AppColors.subtext(context), fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, String value, String current, Function(String) onSelect) {
    final isSelected = current == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : AppColors.text(context), fontSize: 12)),
      selected: isSelected,
      selectedColor: AppColors.primaryTeal,
      backgroundColor: AppColors.card(context),
      onSelected: (_) => onSelect(value),
    );
  }
}

class _CalendarLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _CalendarLegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.subtext(context))),
      ],
    );
  }
}

class _StudentSummaryCard extends ConsumerWidget {
  final StudentRosterSummary summary;

  const _StudentSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAssigned12 = summary.totalFinalShifts == ShiftRulesHelper.requiredDays;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primaryTeal.withOpacity(0.12),
                      child: Text(
                        summary.studentGroup.code,
                        style: const TextStyle(
                          color: AppColors.primaryTeal,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.studentName,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: AppColors.text(context)),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              summary.studentGroup == StudentGroup.groupA ? l10n.groupA : l10n.groupB,
                              style: TextStyle(fontSize: 12, color: AppColors.subtext(context)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: summary.isSubmitted ? AppColors.successLight : AppColors.warningLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                summary.isSubmitted
                                    ? (l10n.isArabic ? 'مكتمل الإرسال ✓' : 'Submitted ✓')
                                    : (l10n.isArabic ? 'مسودة قيد الاختيار ⏳' : 'Draft ⏳'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: summary.isSubmitted ? AppColors.success : AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: summary.fairnessLevel == FairnessLevel.fair
                        ? AppColors.successLight
                        : summary.fairnessLevel == FairnessLevel.needsReview
                            ? AppColors.warningLight
                            : AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    summary.fairnessLevel == FairnessLevel.fair
                        ? (l10n.isArabic ? 'عادل ومتوازن' : 'Fair')
                        : summary.fairnessLevel == FairnessLevel.needsReview
                            ? (l10n.isArabic ? 'يحتاج مراجعة' : 'Review')
                            : (l10n.isArabic ? 'غير مكتمل' : 'Incomplete'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: summary.fairnessLevel == FairnessLevel.fair
                          ? AppColors.success
                          : summary.fairnessLevel == FairnessLevel.needsReview
                              ? AppColors.warning
                              : AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Statistics Row: Shift breakdown Cards
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.muted(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatBadge('${l10n.shiftMorningLetter} ${l10n.shiftMorningShort}', '${summary.prefMorningCount}', const Color(0xFF0284C7), const Color(0xFFE0F2FE)),
                  _buildStatBadge('${l10n.shiftLongLetter} ${l10n.shiftLongShort}', '${summary.prefLongCount}', const Color(0xFF7C3AED), const Color(0xFFF3E8FF)),
                  _buildStatBadge('${l10n.shiftNightLetter} ${l10n.shiftNightShort}', '${summary.prefNightCount}', const Color(0xFF1E293B), const Color(0xFFE2E8F0)),
                  Container(width: 1, height: 32, color: AppColors.border(context)),
                  _buildStatBadge(l10n.isArabic ? 'معين سهر' : 'Night Set', '${summary.finalNightCount}', summary.meetsMinNight ? AppColors.success : AppColors.warning, summary.meetsMinNight ? AppColors.successLight : AppColors.warningLight),
                  _buildStatBadge(l10n.isArabic ? 'معين طويل' : 'Long Set', '${summary.finalLongCount}', AppColors.primaryTeal, AppColors.primaryTeal.withOpacity(0.12)),
                  _buildStatBadge(l10n.isArabic ? 'إجمالي المعين' : 'Total Set', '${summary.totalFinalShifts}/12', isAssigned12 ? AppColors.success : AppColors.danger, isAssigned12 ? AppColors.successLight : AppColors.dangerLight),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons Row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.auto_fix_high, size: 18),
                    label: Text(l10n.isArabic ? 'توزيع تلقائي مقترح' : 'Auto-Distribute', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      await ref
                          .read(leaderRosterProvider.notifier)
                          .applySuggestion1ForStudent(summary);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.isArabic ? 'تم تطبيق التوزيع المقترح لـ ${summary.studentName} بنجاح!' : 'Suggestion applied for ${summary.studentName}!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryTeal,
                      side: const BorderSide(color: AppColors.primaryTeal),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.edit_calendar, size: 16),
                    label: Text(l10n.isArabic ? 'توزيع يدوي' : 'Manual', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LeaderAssignmentScreen(summary: summary),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD97706),
                    side: const BorderSide(color: Color(0xFFD97706)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.lock_open, size: 16),
                  label: Text(l10n.reopenProposal, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l10n.reopenProposal),
                        content: Text(
                          l10n.isArabic
                              ? 'هل أنت متأكد من إعادة فتح اقتراح الطالب (${summary.studentName})؟ سيتمكن الطالب من تعديل اختياراته مرة أخرى.'
                              : 'Are you sure you want to reopen shift preferences for (${summary.studentName})?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(l10n.cancel),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(l10n.confirm, style: const TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      final res = await ref
                          .read(leaderRosterProvider.notifier)
                          .reopenStudentPreferences(summary.studentId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res['message'] ?? (l10n.isArabic ? 'تم فتح التفضيلات للتعديل بنجاح' : 'Preferences reopened successfully')),
                            backgroundColor: res['success'] == true ? AppColors.warning : AppColors.danger,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.85)),
          ),
        ],
      ),
    );
  }
}
