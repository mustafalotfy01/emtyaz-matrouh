import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/roster_preference.dart';

class PreferenceCounterBar extends StatelessWidget {
  final int optionACount;
  final int optionBCount;
  final int totalCount;
  final bool isSubmitted;

  final int morningCount;
  final int longCount;
  final int nightCount;
  final ShiftValidationResult? validationResult;

  const PreferenceCounterBar({
    super.key,
    required this.optionACount,
    required this.optionBCount,
    required this.totalCount,
    this.isSubmitted = false,
    this.morningCount = 0,
    this.longCount = 0,
    this.nightCount = 0,
    this.validationResult,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final totalRequired = ShiftRulesHelper.requiredDaysForMorning(morningCount);
    final totalComplete = totalCount == totalRequired;
    final isValid = validationResult?.canSubmit ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        children: [
          // Shift counters row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPill(
                context: context,
                label: l10n.shiftMorningShort,
                emoji: l10n.shiftMorningLetter,
                count: morningCount,
                activeColor: const Color(0xFF0284C7),
              ),
              Container(width: 1, height: 36, color: AppColors.border(context)),
              _buildPill(
                context: context,
                label: l10n.shiftLongShort,
                emoji: l10n.shiftLongLetter,
                count: longCount,
                activeColor: const Color(0xFF7C3AED),
              ),
              Container(width: 1, height: 36, color: AppColors.border(context)),
              _buildPill(
                context: context,
                label: l10n.shiftNightShort,
                emoji: l10n.shiftNightLetter,
                count: nightCount,
                target: ShiftRulesHelper.minNightIfNoNight,
                activeColor: const Color(0xFF6366F1),
              ),
              Container(width: 1, height: 36, color: AppColors.border(context)),
              _buildPill(
                context: context,
                label: l10n.isArabic ? 'الإجمالي' : 'Total',
                count: totalCount,
                target: totalRequired,
                activeColor: totalComplete ? AppColors.success : AppColors.warning,
                isTotal: true,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (totalCount / totalRequired).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.muted(context),
              valueColor: AlwaysStoppedAnimation<Color>(
                isValid ? AppColors.success : (totalCount > totalRequired ? AppColors.danger : AppColors.primaryTeal),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Dynamic Validation / Status Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isValid
                  ? AppColors.success.withOpacity(0.15)
                  : (totalCount == totalRequired
                      ? AppColors.warning.withOpacity(0.15)
                      : AppColors.muted(context)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isValid
                    ? AppColors.success.withOpacity(0.4)
                    : (totalCount == totalRequired ? AppColors.warning.withOpacity(0.4) : AppColors.border(context)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isValid
                      ? Icons.check_circle
                      : (totalCount == totalRequired ? Icons.warning_amber_rounded : Icons.info_outline),
                  size: 14,
                  color: isValid
                      ? AppColors.success
                      : (totalCount == totalRequired ? AppColors.warning : AppColors.subtext(context)),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    validationResult?.message ?? (l10n.isArabic ? 'اختر 12 يوماً موزعة على الشيفتات' : 'Select 12 days distributed across shifts'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isValid
                          ? AppColors.success
                          : (totalCount == totalRequired ? AppColors.warning : AppColors.subtext(context)),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill({
    required BuildContext context,
    required String label,
    String? emoji,
    required int count,
    int? target,
    required Color activeColor,
    bool isTotal = false,
  }) {
    final bool isDone = target != null ? count >= target : count > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (isDone)
              const Padding(
                padding: EdgeInsets.only(left: 2),
                child: Icon(Icons.check, size: 12, color: AppColors.success),
              ),
            Text(
              '$count',
              style: TextStyle(
                color: isDone ? AppColors.text(context) : AppColors.subtext(context),
                fontSize: isTotal ? 16 : 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (target != null)
              Text(
                '/$target',
                style: TextStyle(
                  color: AppColors.subtext(context).withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(left: 3),
                decoration: BoxDecoration(
                  color: activeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Center(
                  child: Text(
                    emoji,
                    style: TextStyle(
                      color: activeColor,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
            Text(
              label,
              style: TextStyle(
                color: AppColors.subtext(context),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
