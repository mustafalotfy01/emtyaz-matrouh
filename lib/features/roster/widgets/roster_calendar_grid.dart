import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.subtext(context),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),

        // Days Grid
        GridView.builder(
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

            final bool isAvailableForGroup = isPublishedView
                ? true
                : ShiftRulesHelper.isDayAvailableForGroup(
                    day: dayNumber,
                    isGroupA: studentGroup == StudentGroup.groupA,
                    daysInMonth: daysInMonth,
                  );

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

            return DayCell(
              dayNumber: dayNumber,
              isAvailableForGroup: isAvailableForGroup,
              preferenceType: prefType,
              shiftType: shiftTypeForDay,
              publishedShift: pubShift,
              isPublishedView: isPublishedView,
              onTap: onDayTap != null ? () => onDayTap!(date) : null,
            );
          },
        ),
      ],
    );
  }
}
