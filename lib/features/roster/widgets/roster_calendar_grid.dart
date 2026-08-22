import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_badge.dart';
import '../models/roster_entry.dart';
import '../models/roster_preference.dart';
import '../../auth/models/user_profile.dart';
import 'day_cell.dart';

class RosterCalendarGrid extends StatelessWidget {
  final int month;
  final int year;
  final StudentGroup studentGroup;
  final List<RosterPreference> preferences;
  final List<RosterEntry> publishedShifts;
  final bool isPublishedView;
  final Function(DateTime)? onDayTap;

  const RosterCalendarGrid({
    super.key,
    required this.month,
    required this.year,
    required this.studentGroup,
    required this.preferences,
    this.publishedShifts = const [],
    this.isPublishedView = false,
    this.onDayTap,
  });

  int _calculateWeeklyHours(List<DateTime> weekDates) {
    int totalHours = 0;
    for (final d in weekDates) {
      if (isPublishedView) {
        final match = publishedShifts.where((s) =>
            s.shiftDate.year == d.year &&
            s.shiftDate.month == d.month &&
            s.shiftDate.day == d.day).firstOrNull;
        if (match != null) {
          totalHours += match.shiftType == ShiftType.morning ? 6 : 12;
        }
      } else {
        final pref = preferences.where((p) =>
            p.preferenceDate.year == d.year &&
            p.preferenceDate.month == d.month &&
            p.preferenceDate.day == d.day).firstOrNull;
        if (pref != null) {
          totalHours += pref.preferenceShiftType.hours;
        }
      }
    }
    return totalHours;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDayOfMonth = DateTime(year, month, 1);
    final int startOffset = (firstDayOfMonth.weekday + 1) % 7; // Saturday = 0

    final weekDays = [l10n.sat, l10n.sun, l10n.mon, l10n.tue, l10n.wed, l10n.thu, l10n.fri];

    // Partition days into Saturday -> Friday weeks
    final List<List<int?>> weeks = [];
    List<int?> currentWeek = List.filled(startOffset, null, growable: true);

    for (int day = 1; day <= daysInMonth; day++) {
      currentWeek.add(day);
      if (currentWeek.length == 7) {
        weeks.add(currentWeek);
        currentWeek = [];
      }
    }
    if (currentWeek.isNotEmpty) {
      while (currentWeek.length < 7) {
        currentWeek.add(null);
      }
      weeks.add(currentWeek);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Weekday Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekDays.map((day) {
            return Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppDesignTokens.textSecondary(context),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),

        // Weeks List with 36-Hour Indicator per week (Saturday -> Friday)
        for (int weekIdx = 0; weekIdx < weeks.length; weekIdx++) ...[
          if (weekIdx > 0) const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final weekDaysList = weeks[weekIdx];
              final weekDates = weekDaysList
                  .where((d) => d != null)
                  .map((d) => DateTime(year, month, d!))
                  .toList();
              final weekHours = _calculateWeeklyHours(weekDates);
              final isOver36 = weekHours > 36;
              final isExact36 = weekHours == 36;

              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isOver36
                      ? AppDesignTokens.dangerBgLight.withValues(alpha: 0.4)
                      : AppDesignTokens.surface(context),
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
                  border: Border.all(
                    color: isOver36
                        ? AppDesignTokens.danger
                        : (isExact36 ? AppDesignTokens.success : AppDesignTokens.border(context)),
                    width: isOver36 || isExact36 ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Week Header Bar with 36h rule indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'الأسبوع ${weekIdx + 1} (السبت ← الجمعة)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AppDesignTokens.textPrimary(context),
                          ),
                        ),
                        AppBadge(
                          label: '$weekHours / 36 ساعة ${isExact36 ? "✓" : (isOver36 ? "⚠️ تجاوز" : "")}',
                          variant: isOver36
                              ? AppBadgeVariant.danger
                              : (isExact36 ? AppBadgeVariant.success : AppBadgeVariant.neutral),
                          size: AppBadgeSize.small,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 7 Days Grid for this specific week
                    Row(
                      children: weekDaysList.map((dayNumber) {
                        if (dayNumber == null) {
                          return const Expanded(child: SizedBox.shrink());
                        }

                        final date = DateTime(year, month, dayNumber);
                        // The entire month is open to all students
                        const bool isAvailableForGroup = true;

                        PreferenceShiftType? shiftTypeForDay;
                        PreferenceType? prefType;
                        try {
                          final p = preferences.firstWhere((pref) =>
                              pref.preferenceDate.year == year &&
                              pref.preferenceDate.month == month &&
                              pref.preferenceDate.day == dayNumber);
                          shiftTypeForDay = p.preferenceShiftType;
                          prefType = p.preferenceType;
                        } catch (_) {}

                        RosterEntry? pubShift;
                        try {
                          pubShift = publishedShifts.firstWhere((s) =>
                              s.shiftDate.year == year &&
                              s.shiftDate.month == month &&
                              s.shiftDate.day == dayNumber);
                        } catch (_) {}

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                            child: DayCell(
                              dayNumber: dayNumber,
                              isAvailableForGroup: isAvailableForGroup,
                              preferenceType: prefType,
                              shiftType: shiftTypeForDay,
                              publishedShift: pubShift,
                              isPublishedView: isPublishedView,
                              onTap: onDayTap != null ? () => onDayTap!(date) : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
