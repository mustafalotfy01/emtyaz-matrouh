import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/roster_entry.dart';
import '../providers/roster_provider.dart';

class RosterOverviewScreen extends ConsumerWidget {
  const RosterOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderState = ref.watch(leaderRosterProvider);
    final rosterMonth = ref.watch(currentRosterMonthProvider);
    final daysInMonth = DateTime(rosterMonth.year, rosterMonth.month + 1, 0).day;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Text('${l10n.viewCombinedRoster} — ${rosterMonth.title}', style: TextStyle(color: AppColors.text(context), fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: leaderState.summaries.isEmpty
          ? Center(child: Text(l10n.noDataFound, style: TextStyle(color: AppColors.subtext(context))))
          : SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AppColors.card(context)),
                    headingTextStyle: TextStyle(color: AppColors.text(context), fontWeight: FontWeight.bold, fontSize: 11),
                    dataRowMinHeight: 36,
                    dataRowMaxHeight: 40,
                    horizontalMargin: 8,
                    columnSpacing: 10,
                    columns: [
                      DataColumn(label: Text(l10n.isArabic ? 'الطالب' : 'Student')),
                      DataColumn(label: Text(l10n.isArabic ? 'المجموعة' : 'Group')),
                      ...List.generate(daysInMonth, (i) {
                        return DataColumn(
                          label: Center(
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        );
                      }),
                      DataColumn(label: Text(l10n.isArabic ? 'الإجمالي' : 'Total')),
                      DataColumn(label: Text(l10n.shiftNightShort)),
                      DataColumn(label: Text(l10n.shiftLongShort)),
                      DataColumn(label: Text(l10n.shiftMorningShort)),
                    ],
                    rows: leaderState.summaries.map((summary) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              summary.studentName,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.text(context)),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryTeal.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                summary.studentGroup.code,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryTeal,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                          // Days cells
                          ...List.generate(daysInMonth, (dIndex) {
                            final day = dIndex + 1;
                            final shift = summary.assignedShifts.cast<RosterEntry?>().firstWhere(
                              (s) => s?.shiftDate.day == day,
                              orElse: () => null,
                            );

                            if (shift != null) {
                              String code = l10n.shiftMorningLetter;
                              Color cellColor = const Color(0xFF0284C7);
                              if (shift.shiftType == ShiftType.night) {
                                code = l10n.shiftNightLetter;
                                cellColor = const Color(0xFF1E293B);
                              } else if (shift.shiftType == ShiftType.long) {
                                code = l10n.shiftLongLetter;
                                cellColor = const Color(0xFF7C3AED);
                              }

                              return DataCell(
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: cellColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Center(
                                    child: Text(
                                      code,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              return DataCell(
                                Center(
                                  child: Text(
                                    l10n.shiftRest,
                                    style: TextStyle(color: AppColors.subtext(context), fontSize: 9),
                                  ),
                                ),
                              );
                            }
                          }),
                          DataCell(
                            Text(
                              '${summary.totalFinalShifts}/12',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: summary.totalFinalShifts == 12 ? AppColors.success : AppColors.danger,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${summary.finalNightCount}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: summary.meetsMinNight ? AppColors.success : AppColors.warning,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${summary.finalLongCount}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.text(context),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${summary.finalMorningCount}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
    );
  }
}
