import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/roster_entry.dart';
import '../models/roster_preference.dart';

class DayCell extends StatelessWidget {
  final int dayNumber;
  final bool isAvailableForGroup;
  final PreferenceType? preferenceType;
  final PreferenceShiftType? shiftType;
  final RosterEntry? publishedShift;
  final bool isPublishedView;
  final VoidCallback? onTap;

  const DayCell({
    super.key,
    required this.dayNumber,
    required this.isAvailableForGroup,
    this.preferenceType,
    this.shiftType,
    this.publishedShift,
    this.isPublishedView = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // ── 1. Published Official View ──────────────────────────────────────────
    if (isPublishedView) {
      if (publishedShift != null && publishedShift!.isApprovedOrPublished) {
        final shiftInitial = publishedShift!.shiftType == ShiftType.night
            ? l10n.shiftNightLetter
            : (publishedShift!.shiftType == ShiftType.long ? l10n.shiftLongLetter : l10n.shiftMorningLetter);

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF059669), width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$dayNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  shiftInitial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$dayNumber',
                  style: TextStyle(
                    color: AppColors.text(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.shiftRest,
                  style: TextStyle(color: AppColors.subtext(context), fontSize: 8),
                ),
              ],
            ),
          ),
        );
      }
    }

    // ── 2. Interactive Selection Phase ──────────────────────────────────────
    if (!isAvailableForGroup) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.muted(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$dayNumber',
                style: TextStyle(
                  color: AppColors.subtext(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.isArabic ? 'خارج نطاقك' : 'Out of group',
                style: TextStyle(color: AppColors.subtext(context), fontSize: 7),
              ),
            ],
          ),
        ),
      );
    }

    final effectiveShift = shiftType ??
        (preferenceType == PreferenceType.optionB
            ? PreferenceShiftType.night
            : (preferenceType == PreferenceType.optionA ? PreferenceShiftType.morning : null));

    // ── Morning Cell 🔵 ─────────────────────────────────────────────────────
    if (effectiveShift == PreferenceShiftType.morning) {
      return _buildShiftCell(
        dayNumber: dayNumber,
        bgColor: const Color(0xFFE0F2FE),
        borderColor: const Color(0xFF0284C7),
        textColor: const Color(0xFF0369A1),
        labelColor: const Color(0xFF0284C7),
        label: '${l10n.shiftMorningLetter} ${l10n.shiftMorningShort}',
        hint: l10n.isArabic ? 'اضغط ← ط' : 'Tap → L',
        onTap: onTap,
      );
    }

    // ── Long Cell 🟣 ────────────────────────────────────────────────────────
    if (effectiveShift == PreferenceShiftType.longShift) {
      return _buildShiftCell(
        dayNumber: dayNumber,
        bgColor: const Color(0xFFF3E8FF),
        borderColor: const Color(0xFF7C3AED),
        textColor: const Color(0xFF5B21B6),
        labelColor: const Color(0xFF7C3AED),
        label: '${l10n.shiftLongLetter} ${l10n.shiftLongShort}',
        hint: l10n.isArabic ? 'اضغط ← ل' : 'Tap → N',
        onTap: onTap,
      );
    }

    // ── Night Cell 🌙 ────────────────────────────────────────────────────────
    if (effectiveShift == PreferenceShiftType.night) {
      return _buildShiftCell(
        dayNumber: dayNumber,
        bgColor: const Color(0xFF1E293B),
        borderColor: const Color(0xFF0F172A),
        textColor: Colors.white,
        labelColor: const Color(0xFF94A3B8),
        label: '${l10n.shiftNightLetter} ${l10n.shiftNightShort} 🌙',
        hint: l10n.isArabic ? 'اضغط ← إلغاء' : 'Tap → Clear',
        isDark: true,
        onTap: onTap,
      );
    }

    // ── Default / Empty Selectable Cell ⬜ ──────────────────────────────────
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primaryTeal.withOpacity(0.35)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$dayNumber',
                style: TextStyle(
                  color: AppColors.text(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.isArabic ? 'اضغط للاختيار' : 'Tap to set',
                style: const TextStyle(
                  color: AppColors.primaryTeal,
                  fontSize: 7,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShiftCell({
    required int dayNumber,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
    required Color labelColor,
    required String label,
    required String hint,
    bool isDark = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$dayNumber',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isDark ? Colors.white12 : borderColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white : textColor,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              hint,
              style: TextStyle(
                color: isDark ? Colors.white54 : labelColor,
                fontSize: 6.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
