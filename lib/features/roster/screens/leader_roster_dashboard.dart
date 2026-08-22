import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../models/roster_entry.dart';
import '../models/roster_month.dart';
import '../models/roster_preference.dart';
import '../models/student_roster_summary.dart';
import '../providers/roster_provider.dart';
import '../widgets/leader_day_assignment_sheet.dart';
import 'leader_assignment_screen.dart';
import 'roster_overview_screen.dart';

class LeaderRosterDashboard extends ConsumerStatefulWidget {
  final bool isEmbeddedInTabs;
  const LeaderRosterDashboard({super.key, this.isEmbeddedInTabs = false});

  @override
  ConsumerState<LeaderRosterDashboard> createState() => _LeaderRosterDashboardState();
}

class _LeaderRosterDashboardState extends ConsumerState<LeaderRosterDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openDayAssignmentSheet(DateTime date, List<StudentRosterSummary> summaries) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LeaderDayAssignmentSheet(
        date: date,
        allSummaries: summaries,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leaderState = ref.watch(leaderRosterProvider);
    final rosterMonth = ref.watch(currentRosterMonthProvider);
    final l10n = context.l10n;

    final content = leaderState.isLoading
        ? const Center(child: CircularProgressIndicator(color: AppDesignTokens.primary))
        : Column(
            children: [
              // Segmented Tab Selector Header
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                decoration: BoxDecoration(
                  color: AppDesignTokens.surfaceMuted(context),
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
                  border: Border.all(color: AppDesignTokens.border(context)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: AppDesignTokens.primary,
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppDesignTokens.textSecondary(context),
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(icon: const Icon(Icons.calendar_month_rounded, size: 16), text: l10n.isArabic ? 'تقويم الجدولة والتوزيع' : 'Schedule Calendar'),
                    Tab(icon: const Icon(Icons.people_alt_rounded, size: 16), text: l10n.isArabic ? 'قائمة الطلاب والالتزام' : 'Students & Compliance'),
                  ],
                ),
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // ── TAB 1: Rapid Calendar Day Assignment View ─────────────────
                    RefreshIndicator(
                      color: AppDesignTokens.primary,
                      onRefresh: () => ref.read(leaderRosterProvider.notifier).loadDashboard(),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Month Selector Card
                          AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.history_toggle_off_rounded, color: AppDesignTokens.primary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.isArabic ? 'الروستر المستهدف:' : 'Target Month:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppDesignTokens.textPrimary(context)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: rosterMonth.id,
                                      isDense: true,
                                      isExpanded: true,
                                      dropdownColor: AppDesignTokens.surface(context),
                                      items: RosterMonth.getAvailableMonths().map((m) {
                                        return DropdownMenuItem(
                                          value: m.id,
                                          child: Text(
                                            m.title,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: m.id == rosterMonth.id ? FontWeight.bold : FontWeight.normal,
                                              color: AppDesignTokens.textPrimary(context),
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

                          const SizedBox(height: 12),

                          // Month Status & Guidance Banner
                          AppCard(
                            variant: rosterMonth.isPublished ? AppCardVariant.standard : AppCardVariant.accentTeal,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      rosterMonth.title,
                                      style: TextStyle(
                                        color: AppDesignTokens.textPrimary(context),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15.5,
                                      ),
                                    ),
                                    AppBadge(
                                      label: rosterMonth.isPublished
                                          ? (l10n.isArabic ? 'الروستر معتمد ومنشور 🟢' : 'Approved & Published 🟢')
                                          : (l10n.isArabic ? 'قيد المراجعة والجدولة 🟡' : 'Under Review 🟡'),
                                      variant: rosterMonth.isPublished ? AppBadgeVariant.success : AppBadgeVariant.warning,
                                      size: AppBadgeSize.small,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.isArabic
                                      ? '💡 اضغط على أي يوم في التقويم لتوزيع الشيفتات (صباحي 6h / طويل 12h / ليلي 12h) ومراجعة رغبات الطلاب وفق قاعدة الـ 36 ساعة أسبوعياً.'
                                      : '💡 Tap any day to assign shifts (Morning 6h / Long 12h / Night 12h) and review student requests.',
                                  style: TextStyle(color: AppDesignTokens.textSecondary(context), fontSize: 12, height: 1.4),
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
                                    backgroundColor: AppDesignTokens.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm)),
                                  ),
                                  icon: const Icon(Icons.table_chart_rounded, size: 16),
                                  label: Text(l10n.exportExcel, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
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
                                          backgroundColor: AppDesignTokens.warning,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm)),
                                        ),
                                        icon: const Icon(Icons.lock_open_rounded, size: 16),
                                        label: Text(l10n.editApprovedRoster, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
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
                                                  style: ElevatedButton.styleFrom(backgroundColor: AppDesignTokens.warning),
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
                                                  backgroundColor: AppDesignTokens.warning,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      )
                                    : ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppDesignTokens.success,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm)),
                                        ),
                                        icon: const Icon(Icons.verified_rounded, size: 16),
                                        label: Text(l10n.approveAndPublishRoster, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                        onPressed: () async {
                                          final success = await ref
                                              .read(leaderRosterProvider.notifier)
                                              .publishRoster();
                                          if (context.mounted) {
                                            if (success) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(l10n.isArabic ? 'تم نشر واعتماد الروستر بنجاح 🟢' : 'Roster approved and published 🟢'),
                                                  backgroundColor: AppDesignTokens.success,
                                                ),
                                              );
                                            } else if (leaderState.errorMessage != null) {
                                              showDialog(
                                                context: context,
                                                builder: (_) => AlertDialog(
                                                  title: Text(l10n.isArabic ? 'تعذر نشر الروستر' : 'Publish Error', style: const TextStyle(color: AppDesignTokens.danger)),
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

                          const SizedBox(height: 14),

                          // Legend
                          AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _LegendItem(color: AppDesignTokens.shiftMorningBgLight, label: 'صباحي (6h)', borderColor: AppDesignTokens.shiftMorning),
                                _LegendItem(color: AppDesignTokens.shiftLongBgLight, label: 'طويل (12h)', borderColor: AppDesignTokens.shiftLong),
                                _LegendItem(color: AppDesignTokens.shiftNightBgLight, label: 'ليلي (12h)', borderColor: AppDesignTokens.shiftNight),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Interactive Calendar Grid for Leader
                          AppCard(
                            padding: const EdgeInsets.all(12),
                            child: _buildLeaderCalendarGrid(context, rosterMonth.year, rosterMonth.month, leaderState.summaries, l10n),
                          ),

                          const SizedBox(height: 30),
                        ],
                      ),
                    ),

                    // ── TAB 2: Students List & Fairness / Compliance View ─────────
                    RefreshIndicator(
                      color: AppDesignTokens.primary,
                      onRefresh: () => ref.read(leaderRosterProvider.notifier).loadDashboard(),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Search Bar
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppDesignTokens.surface(context),
                              borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
                              border: Border.all(color: AppDesignTokens.border(context)),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) {
                                ref.read(leaderRosterProvider.notifier).setSearchQuery(val.trim());
                              },
                              style: TextStyle(color: AppDesignTokens.textPrimary(context), fontSize: 13),
                              decoration: InputDecoration(
                                hintText: l10n.isArabic ? 'بحث باسم الطالب...' : 'Search student by name...',
                                hintStyle: TextStyle(color: AppDesignTokens.textSecondary(context), fontSize: 12.5),
                                prefixIcon: const Icon(Icons.search_rounded, color: AppDesignTokens.primary, size: 20),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          ref.read(leaderRosterProvider.notifier).setSearchQuery('');
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),

                          // Filter Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip(context, '${l10n.categoryAll} (${leaderState.summaries.length})', 'ALL', leaderState.filterStatus, (v) => ref.read(leaderRosterProvider.notifier).setFilterStatus(v)),
                                const SizedBox(width: 8),
                                _buildFilterChip(context, l10n.isArabic ? 'مكتمل 12 يوم' : 'Completed (12 Days)', 'COMPLETED', leaderState.filterStatus, (v) => ref.read(leaderRosterProvider.notifier).setFilterStatus(v)),
                                const SizedBox(width: 8),
                                _buildFilterChip(context, l10n.isArabic ? 'تم الإرسال' : 'Submitted', 'SUBMITTED', leaderState.filterStatus, (v) => ref.read(leaderRosterProvider.notifier).setFilterStatus(v)),
                                const SizedBox(width: 8),
                                _buildFilterChip(context, l10n.isArabic ? 'مسودة' : 'Draft', 'DRAFT', leaderState.filterStatus, (v) => ref.read(leaderRosterProvider.notifier).setFilterStatus(v)),
                                const SizedBox(width: 8),
                                _buildFilterChip(context, l10n.isArabic ? 'يحتاج مراجعة' : 'Needs Review', 'NEEDS_REVIEW', leaderState.filterStatus, (v) => ref.read(leaderRosterProvider.notifier).setFilterStatus(v)),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          if (leaderState.filteredSummaries.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: AppDesignTokens.surface(context),
                                borderRadius: BorderRadius.circular(AppDesignTokens.radiusLg),
                                border: Border.all(color: AppDesignTokens.border(context)),
                              ),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.people_outline_rounded, size: 48, color: AppDesignTokens.textMuted(context)),
                                    const SizedBox(height: 10),
                                    Text(
                                      l10n.isArabic ? 'لا يوجد طلاب مطابقين للفلتر أو البحث' : 'No students match filter or search',
                                      style: TextStyle(color: AppDesignTokens.textPrimary(context), fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      l10n.isArabic ? 'عند قيام الطلاب بالتسجيل سيظهرون هنا تلقائياً.' : 'Registered students will automatically appear here.',
                                      style: TextStyle(color: AppDesignTokens.textSecondary(context), fontSize: 11),
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
              ),
            ],
          );

    if (widget.isEmbeddedInTabs) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        backgroundColor: AppDesignTokens.surface(context),
        elevation: 0,
        title: Text(
          l10n.isArabic ? 'إدارة الجدولة والروستر الشهري' : 'Internship Roster Management',
          style: TextStyle(color: AppDesignTokens.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: l10n.isArabic ? 'تحديث البيانات' : 'Refresh Data',
            icon: Icon(Icons.refresh_rounded, color: AppDesignTokens.textPrimary(context)),
            onPressed: () => ref.read(leaderRosterProvider.notifier).loadDashboard(),
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildLeaderCalendarGrid(BuildContext context, int year, int month, List<StudentRosterSummary> summaries, AppLocalizations l10n) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDayOfMonth = DateTime(year, month, 1);
    final int startOffset = (firstDayOfMonth.weekday + 1) % 7; // Saturday = 0
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
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppDesignTokens.textSecondary(context),
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

            final hasAssignments = assignedEntriesOnDay.isNotEmpty;

            return InkWell(
              onTap: () => _openDayAssignmentSheet(date, summaries),
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppDesignTokens.surface(context),
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                  border: Border.all(
                    color: hasAssignments
                        ? AppDesignTokens.primary
                        : (requestCount > 0 ? AppDesignTokens.primary.withOpacity(0.3) : AppDesignTokens.border(context)),
                    width: hasAssignments ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Day Number + Request Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppDesignTokens.textPrimary(context),
                          ),
                        ),
                        if (requestCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppDesignTokens.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$requestCount',
                              style: const TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: AppDesignTokens.primary,
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
                                  ? 'ل'
                                  : (e.shiftType == ShiftType.long ? 'ط' : 'ص');
                              final shiftBg = e.shiftType == ShiftType.night
                                  ? AppDesignTokens.shiftNightBgLight
                                  : (e.shiftType == ShiftType.long ? AppDesignTokens.shiftLongBgLight : AppDesignTokens.shiftMorningBgLight);
                              final shiftColor = e.shiftType == ShiftType.night
                                  ? AppDesignTokens.shiftNight
                                  : (e.shiftType == ShiftType.long ? AppDesignTokens.shiftLong : AppDesignTokens.shiftMorning);

                              return Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                decoration: BoxDecoration(
                                  color: shiftBg,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: shiftColor.withOpacity(0.5), width: 0.5),
                                ),
                                child: Text(
                                  '$firstName ($shiftInitial)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: shiftColor,
                                  ),
                                ),
                              );
                            }),
                            if (assignedEntriesOnDay.length > 2)
                              Text(
                                '+${assignedEntriesOnDay.length - 2}',
                                style: const TextStyle(fontSize: 7.5, color: AppDesignTokens.primary, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          requestCount > 0 ? '$requestCount ${l10n.isArabic ? "طلب" : "req"}' : '-',
                          style: TextStyle(fontSize: 8.5, color: AppDesignTokens.textSecondary(context), fontWeight: FontWeight.w600),
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
    return FilterChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : AppDesignTokens.textPrimary(context), fontSize: 11.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: AppDesignTokens.primary,
      backgroundColor: AppDesignTokens.surface(context),
      onSelected: (_) => onSelect(value),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final Color? borderColor;

  const _LegendItem({required this.color, required this.label, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: borderColor ?? color),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppDesignTokens.textPrimary(context)),
        ),
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
    final rosterMonth = ref.watch(currentRosterMonthProvider);

    // Calculate weekly assigned hours for this student (Saturday -> Friday)
    final daysInMonth = DateTime(rosterMonth.year, rosterMonth.month + 1, 0).day;
    DateTime curSat = DateTime(rosterMonth.year, rosterMonth.month, 1);
    final int offset = (curSat.weekday + 1) % 7;
    curSat = curSat.subtract(Duration(days: offset));
    final List<int> weekHoursList = [];

    while (curSat.isBefore(DateTime(rosterMonth.year, rosterMonth.month, daysInMonth).add(const Duration(days: 1)))) {
      final curWeekEnd = curSat.add(const Duration(days: 6, hours: 23, minutes: 59));
      int weekHours = 0;
      for (final s in summary.assignedShifts) {
        if (!s.shiftDate.isBefore(curSat) && !s.shiftDate.isAfter(curWeekEnd)) {
          weekHours += (s.shiftType == ShiftType.morning ? 6 : 12);
        }
      }
      weekHoursList.add(weekHours);
      curSat = curSat.add(const Duration(days: 7));
    }

    final hasWeeklyViolation = weekHoursList.any((h) => h > 36);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    AppAvatar(
                      name: summary.studentName,
                      imageUrl: summary.avatarUrl,
                      size: AppAvatarSize.small,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.studentName,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppDesignTokens.textPrimary(context)),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: summary.isSubmitted ? AppDesignTokens.successBgLight : AppDesignTokens.warningBgLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                summary.isSubmitted
                                    ? (l10n.isArabic ? 'تم الإرسال للمراجعة ✓' : 'Submitted ✓')
                                    : (summary.totalPrefCount == 0
                                        ? (l10n.isArabic ? 'لم يبدأ الاختيار (0/12)' : 'Not Started (0/12)')
                                        : (l10n.isArabic ? 'مسودة (${summary.totalPrefCount}/12 شفت) 📝' : 'Draft (${summary.totalPrefCount}/12) 📝')),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: summary.isSubmitted ? AppDesignTokens.success : AppDesignTokens.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                AppBadge(
                  label: isAssigned12 && !hasWeeklyViolation
                      ? (l10n.isArabic ? 'مكتمل وملتزم 🟢' : 'Complete 🟢')
                      : (hasWeeklyViolation
                          ? (l10n.isArabic ? 'تجاوز ساعات ⚠️' : 'Over Limit ⚠️')
                          : (l10n.isArabic ? 'يحتاج استكمال (${summary.totalFinalShifts}/12)' : 'Incomplete (${summary.totalFinalShifts}/12)')),
                  variant: isAssigned12 && !hasWeeklyViolation
                      ? AppBadgeVariant.success
                      : (hasWeeklyViolation ? AppBadgeVariant.danger : AppBadgeVariant.warning),
                  size: AppBadgeSize.small,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Statistics Row: Shift breakdown Cards
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppDesignTokens.surfaceMuted(context),
                borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
                border: Border.all(color: AppDesignTokens.border(context)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatBadge('طلب صباحي', '${summary.prefMorningCount}', AppDesignTokens.shiftMorning, AppDesignTokens.shiftMorningBgLight),
                  _buildStatBadge('طلب طويل', '${summary.prefLongCount}', AppDesignTokens.shiftLong, AppDesignTokens.shiftLongBgLight),
                  _buildStatBadge('طلب ليلي', '${summary.prefNightCount}', AppDesignTokens.shiftNight, AppDesignTokens.shiftNightBgLight),
                  Container(width: 1, height: 28, color: AppDesignTokens.border(context)),
                  _buildStatBadge('معين ليلي', '${summary.finalNightCount}', summary.finalNightCount >= 2 ? AppDesignTokens.success : AppDesignTokens.warning, summary.finalNightCount >= 2 ? AppDesignTokens.successBgLight : AppDesignTokens.warningBgLight),
                  _buildStatBadge('معين طويل', '${summary.finalLongCount}', AppDesignTokens.shiftLong, AppDesignTokens.shiftLongBgLight),
                  _buildStatBadge('إجمالي المعين', '${summary.totalFinalShifts}/12', isAssigned12 ? AppDesignTokens.success : AppDesignTokens.danger, isAssigned12 ? AppDesignTokens.successBgLight : AppDesignTokens.dangerBgLight),
                ],
              ),
            ),

            // Weekly Hours Indicator (Saturday -> Friday)
            if (weekHoursList.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'ساعات الأسابيع (حد أقصى 36h):',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppDesignTokens.textSecondary(context)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (int i = 0; i < weekHoursList.length; i++) ...[
                            if (i > 0) const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: weekHoursList[i] > 36
                                    ? AppDesignTokens.dangerBgLight
                                    : (weekHoursList[i] == 36 ? AppDesignTokens.successBgLight : AppDesignTokens.surface(context)),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: weekHoursList[i] > 36
                                      ? AppDesignTokens.danger
                                      : (weekHoursList[i] == 36 ? AppDesignTokens.success : AppDesignTokens.border(context)),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                'أ${i + 1}: ${weekHoursList[i]}h',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: weekHoursList[i] > 36
                                      ? AppDesignTokens.danger
                                      : (weekHoursList[i] == 36 ? AppDesignTokens.success : AppDesignTokens.textSecondary(context)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Action Buttons Row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesignTokens.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm)),
                    ),
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                    label: Text(l10n.isArabic ? 'توزيع تلقائي مقترح' : 'Auto-Distribute', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      await ref
                          .read(leaderRosterProvider.notifier)
                          .applySuggestion1ForStudent(summary);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.isArabic ? 'تم تطبيق التوزيع المقترح لـ ${summary.studentName} بنجاح!' : 'Suggestion applied for ${summary.studentName}!'),
                            backgroundColor: AppDesignTokens.success,
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
                      foregroundColor: AppDesignTokens.primary,
                      side: const BorderSide(color: AppDesignTokens.primary),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm)),
                    ),
                    icon: const Icon(Icons.edit_calendar_rounded, size: 15),
                    label: Text(l10n.isArabic ? 'توزيع يدوي' : 'Manual', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
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
                    foregroundColor: AppDesignTokens.warning,
                    side: const BorderSide(color: AppDesignTokens.warning),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm)),
                  ),
                  icon: const Icon(Icons.lock_open_rounded, size: 15),
                  label: Text(l10n.reopenProposal, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
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
                            style: ElevatedButton.styleFrom(backgroundColor: AppDesignTokens.warning),
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
                            backgroundColor: res['success'] == true ? AppDesignTokens.warning : AppDesignTokens.danger,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.85)),
          ),
        ],
      ),
    );
  }
}
