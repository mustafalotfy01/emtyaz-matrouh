import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/roster_entry.dart';
import '../models/roster_month.dart';
import '../providers/roster_provider.dart';
import '../services/roster_service.dart';
import '../widgets/preference_counter_bar.dart';
import '../widgets/roster_calendar_grid.dart';

class StudentRosterScreen extends ConsumerWidget {
  final bool isEmbeddedInTabs;
  const StudentRosterScreen({super.key, this.isEmbeddedInTabs = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final rosterMonth = ref.watch(currentRosterMonthProvider);
    final prefState = ref.watch(studentPreferencesProvider);
    final publishedShiftsAsync = ref.watch(studentPublishedRosterProvider);
    final publishedShifts = publishedShiftsAsync.value ?? [];
    final isPublished = rosterMonth.isPublished || publishedShifts.isNotEmpty;
    final l10n = context.l10n;

    final content = RefreshIndicator(
      color: AppDesignTokens.primary,
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

            const SizedBox(height: 12),

            // Header Info Card
            AppCard(
              variant: prefState.isSubmitted ? AppCardVariant.standard : AppCardVariant.accentTeal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        prefState.isSubmitted ? Icons.verified_rounded : Icons.edit_calendar_rounded,
                        color: prefState.isSubmitted ? AppDesignTokens.success : AppDesignTokens.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          prefState.isSubmitted
                              ? (l10n.isArabic ? 'تم إرسال اقتراح الروستر للمشرف ✓' : 'Preferences Submitted ✓')
                              : (l10n.isArabic ? 'اقتراح وتفضيلات الروستر الشهري (36 ساعة/أسبوع)' : 'Monthly Preferences (36h/week)'),
                          style: TextStyle(
                            color: AppDesignTokens.textPrimary(context),
                            fontSize: 14.5,
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
                            ? 'تفضيلاتك مقفلة ومرسلة لليدر للاعتماد. سيظهر جدولك النهائي المعتمد بعد اكتمال المراجعة.'
                            : 'Your preferences are locked for review.')
                        : 'اختر 12 يوماً تدريبياً مع الالتزام بحد أقصى 36 ساعة لكل أسبوع (من السبت إلى الجمعة).',
                    style: TextStyle(color: AppDesignTokens.textSecondary(context), fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Error / Success Messages
            if (prefState.errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppDesignTokens.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                  border: Border.all(color: AppDesignTokens.danger.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppDesignTokens.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        prefState.errorMessage!,
                        style: const TextStyle(color: AppDesignTokens.danger, fontSize: 12, fontWeight: FontWeight.bold),
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
                  color: AppDesignTokens.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
                  border: Border.all(color: AppDesignTokens.success.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: AppDesignTokens.success, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        prefState.successMessage!,
                        style: const TextStyle(color: AppDesignTokens.success, fontSize: 12, fontWeight: FontWeight.bold),
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
              const SizedBox(height: 14),
            ],

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

            // Calendar Grid
            publishedShiftsAsync.when(
              data: (publishedShifts) {
                return AppCard(
                  padding: const EdgeInsets.all(12),
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
              loading: () => const Center(child: CircularProgressIndicator(color: AppDesignTokens.primary)),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 18),

            // Submit Button
            if (!isPublished) ...[
              if (prefState.isSubmitted)
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_rounded, color: AppDesignTokens.success, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        l10n.isArabic ? 'تم قفل وإرسال تفضيلاتك الرسمية لليدر بنجاح ✓' : 'Preferences submitted & locked ✓',
                        style: const TextStyle(
                          color: AppDesignTokens.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                )
              else
                AppButton(
                  text: prefState.isReadyToSubmit
                      ? 'إرسال اختيارات الروستر (12/12 ✓)'
                      : 'إرسال الاختيارات (${prefState.totalCount}/12 يوم)',
                  icon: Icons.send_rounded,
                  size: AppButtonSize.large,
                  isLoading: prefState.isLoading,
                  onPressed: prefState.isReadyToSubmit
                      ? () async {
                          final success = await ref
                              .read(studentPreferencesProvider.notifier)
                              .submitPreferences();
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.preferencesSubmittedSuccess),
                                backgroundColor: AppDesignTokens.success,
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
      );

    if (isEmbeddedInTabs) {
      return Material(
        color: AppDesignTokens.bg(context),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: AppDesignTokens.bg(context),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.preferencesTitle} — ${rosterMonth.title}',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppDesignTokens.textPrimary(context)),
            ),
            Text(
              l10n.studentPreferencesTitle,
              style: TextStyle(fontSize: 11, color: AppDesignTokens.textSecondary(context)),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: AppBadge(
              label: isPublished
                  ? 'جدول معتمد'
                  : (prefState.isSubmitted ? 'تم الإرسال' : 'مسودة'),
              variant: isPublished || prefState.isSubmitted
                  ? AppBadgeVariant.success
                  : AppBadgeVariant.warning,
              size: AppBadgeSize.small,
            ),
          ),
        ],
      ),
      body: content,
    );
  }

  void _showShiftDetailsSheet(BuildContext context, RosterEntry shift, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppDesignTokens.surface(context),
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
                  const Icon(Icons.verified_rounded, color: AppDesignTokens.success, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    '${shift.shiftDate.day}/${shift.shiftDate.month}/${shift.shiftDate.year}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppDesignTokens.textPrimary(context)),
                  ),
                ],
              ),
              Divider(height: 24, color: AppDesignTokens.borderSubtle(context)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_hospital_rounded, color: AppDesignTokens.primary, size: 20),
                ),
                title: Text('القسم المخصص', style: TextStyle(fontSize: 12, color: AppDesignTokens.textSecondary(context))),
                subtitle: Text(
                  shift.departmentName.isNotEmpty ? shift.departmentName : l10n.deptEmergencyShort,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppDesignTokens.textPrimary(context)),
                ),
              ),
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
  final Color? borderColor;

  const _LegendItem({
    required this.color,
    required this.label,
    this.borderColor,
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
            border: borderColor != null ? Border.all(color: borderColor!, width: 1.5) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppDesignTokens.textSecondary(context),
          ),
        ),
      ],
    );
  }
}
