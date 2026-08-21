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
import '../providers/roster_provider.dart';
import '../services/roster_service.dart';
import '../widgets/preference_counter_bar.dart';
import '../widgets/roster_calendar_grid.dart';

class StudentRosterScreen extends ConsumerWidget {
  const StudentRosterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final rosterMonth = ref.watch(currentRosterMonthProvider);
    final prefState = ref.watch(studentPreferencesProvider);
    final publishedShiftsAsync = ref.watch(studentPublishedRosterProvider);
    final publishedShifts = publishedShiftsAsync.value ?? [];
    final isPublished = rosterMonth.isPublished || publishedShifts.isNotEmpty;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.preferencesTitle} — ${rosterMonth.title}',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text(context)),
            ),
            Text(
              l10n.studentPreferencesTitle,
              style: TextStyle(fontSize: 10.5, color: AppColors.subtext(context)),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: prefState.isSubmitted ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              user?.studentGroup == StudentGroup.groupB ? l10n.groupB : l10n.groupA,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(studentPreferencesProvider.notifier).loadPreferences();
          ref.invalidate(studentPublishedRosterProvider);
          final updated = await RosterService.fetchRosterMonthFromSupabase(rosterMonth.month, rosterMonth.year);
          ref.read(currentRosterMonthProvider.notifier).state = updated;
        },
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
                            ref.read(studentPreferencesProvider.notifier).loadPreferences();
                            ref.invalidate(studentPublishedRosterProvider);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Header Info Banner
            CustomCard(
              backgroundColor: AppColors.card(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.edit_calendar,
                        color: Color(0xFFFBBF24),
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          prefState.isSubmitted
                              ? (l10n.isArabic ? 'تم إرسال اقتراح الروستر للمشرف ✓' : 'Preferences Submitted to Supervisor ✓')
                              : (l10n.isArabic ? 'اقتراح وتفضيلات الروستر الشهري 🟡' : 'Monthly Shift Preferences Proposal 🟡'),
                          style: TextStyle(
                            color: AppColors.text(context),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    prefState.isSubmitted
                        ? (l10n.isArabic
                            ? 'تفضيلاتك مقفلة ومرسلة للمنسق للاعتماد. بعد اعتماد المشرف سيظهر جدولك النهائي في تبويب "الروستر المعتمد".'
                            : 'Your preferences are submitted and locked for review. Approved shifts will appear in Approved Roster.')
                        : l10n.preferencesInstructions,
                    style: TextStyle(color: AppColors.subtext(context), fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Error / Success Snack Messages
            if (prefState.errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.danger),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        prefState.errorMessage!,
                        style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            if (prefState.successMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.success),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        prefState.successMessage!,
                        style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            // Preference Counter Bar (Hidden if published)
            if (!isPublished) ...[
              PreferenceCounterBar(
                optionACount: prefState.optionACount,
                optionBCount: prefState.optionBCount,
                totalCount: prefState.totalCount,
                isSubmitted: prefState.isSubmitted,
                morningCount: prefState.morningCount,
                longCount: prefState.longCount,
                nightCount: prefState.nightCount,
                validationResult: prefState.validationResult,
              ),
              const SizedBox(height: 16),
            ],

            // Calendar Legend Card
            CustomCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: isPublished
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _LegendItem(color: const Color(0xFF10B981), label: l10n.isArabic ? 'شيفت عمل معتمد 🟩' : 'Approved Shift 🟩'),
                        _LegendItem(color: AppColors.card(context), label: l10n.isArabic ? 'يوم راحة (OFF) ⬜' : 'Off Day ⬜', hasBorder: true),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _LegendItem(color: const Color(0xFFE0F2FE), label: '${l10n.shiftMorningLetter} ${l10n.shiftMorningShort} 🔵', borderColor: const Color(0xFF0284C7)),
                        _LegendItem(color: const Color(0xFFF3E8FF), label: '${l10n.shiftLongLetter} ${l10n.shiftLongShort} 🟣', borderColor: const Color(0xFF7C3AED)),
                        _LegendItem(color: const Color(0xFF1E293B), label: '${l10n.shiftNightLetter} ${l10n.shiftNightShort} 🌙', isDark: true),
                        _LegendItem(color: AppColors.muted(context), label: l10n.isArabic ? 'خارج نطاقك ⬛' : 'Out of range ⬛', hasBorder: true),
                      ],
                    ),
            ),

            const SizedBox(height: 16),

            // The Monthly Calendar Grid
            publishedShiftsAsync.when(
              data: (publishedShifts) {
                return CustomCard(
                  padding: const EdgeInsets.all(14),
                  child: RosterCalendarGrid(
                    month: rosterMonth.month,
                    year: rosterMonth.year,
                    studentGroup: user?.studentGroup ?? StudentGroup.groupA,
                    preferences: prefState.preferences,
                    publishedShifts: publishedShifts,
                    isPublishedView: isPublished,
                    onDayTap: isPublished
                        ? (date) {
                            final match = publishedShifts.where((s) =>
                                s.shiftDate.year == date.year &&
                                s.shiftDate.month == date.month &&
                                s.shiftDate.day == date.day).firstOrNull;
                            if (match != null) {
                              _showShiftDetailsSheet(context, match, l10n);
                            }
                          }
                        : (prefState.isSubmitted
                            ? null
                            : (date) {
                                ref
                                    .read(studentPreferencesProvider.notifier)
                                    .toggleDatePreference(
                                      date,
                                      user?.studentGroup ?? StudentGroup.groupA,
                                    );
                              }),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 20),

            // Submit Button (only when not published)
            if (!isPublished) ...[
              if (prefState.isSubmitted)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock, color: AppColors.success),
                      const SizedBox(width: 8),
                      Text(
                        l10n.isArabic ? 'تم قفل وإرسال تفضيلاتك الرسمية للمنسق بنجاح ✓' : 'Preferences submitted & locked for review ✓',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                )
              else
                CustomButton(
                  text: prefState.isReadyToSubmit
                      ? (l10n.isArabic ? 'إرسال اختيارات الروستر (12/12 ✓)' : 'Submit Preferences (12/12 ✓)')
                      : (l10n.isArabic ? 'إرسال الاختيارات (${prefState.totalCount}/12 يوم)' : 'Submit (${prefState.totalCount}/12 Days)'),
                  icon: Icons.send,
                  isLoading: prefState.isLoading,
                  onPressed: prefState.isReadyToSubmit
                      ? () async {
                          final success = await ref
                              .read(studentPreferencesProvider.notifier)
                              .submitPreferences();
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.preferencesSubmittedSuccess,
                                ),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        }
                      : null,
                ),
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showShiftDetailsSheet(BuildContext context, RosterEntry shift, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified, color: AppColors.success, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    '${shift.shiftDate.day}/${shift.shiftDate.month}/${shift.shiftDate.year}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text(context)),
                  ),
                ],
              ),
              Divider(height: 24, color: AppColors.border(context)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  child: Icon(Icons.local_hospital, size: 20),
                ),
                title: Text(l10n.isArabic ? 'القسم المخصص' : 'Department', style: TextStyle(fontSize: 12, color: AppColors.subtext(context))),
                subtitle: Text(
                  shift.departmentName.isNotEmpty ? shift.departmentName : l10n.deptEmergencyShort,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.text(context)),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: shift.shiftType == ShiftType.night ? Colors.indigo : const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  child: Icon(shift.shiftType == ShiftType.night ? Icons.nightlight_round : Icons.wb_sunny, size: 20),
                ),
                title: Text(l10n.isArabic ? 'نوع الشيفت والمواعيد' : 'Shift & Timing', style: TextStyle(fontSize: 12, color: AppColors.subtext(context))),
                subtitle: Text(
                  shift.shiftType == ShiftType.night ? l10n.shiftNightTiming : l10n.shiftLongTiming,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.text(context)),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.studentAttendanceConfirmed,
                        style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool hasBorder;
  final Color? borderColor;
  final bool isDark;

  const _LegendItem({
    required this.color,
    required this.label,
    this.hasBorder = false,
    this.borderColor,
    this.isDark = false,
  });

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
            border: (hasBorder || borderColor != null)
                ? Border.all(color: borderColor ?? AppColors.border(context), width: 1.5)
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.subtext(context),
          ),
        ),
      ],
    );
  }
}
