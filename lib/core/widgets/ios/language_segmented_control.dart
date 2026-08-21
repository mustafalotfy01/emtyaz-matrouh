import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../localization/locale_provider.dart';

/// Compact Minimalist iOS Segmented Control for Instant Language Switch: [ العربية | EN ]
class AppLanguageSegmentedControl extends ConsumerWidget {
  final double height;
  final double fontSize;

  const AppLanguageSegmentedControl({
    super.key,
    this.height = 32,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final isArabic = currentLocale.languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final containerBg = isDark ? AppColors.darkSecondarySurface : AppColors.surfaceMuted;
    final borderColor = isDark ? AppColors.darkDivider : AppColors.borderMedium;
    final selectedBg = isDark ? AppColors.darkSurface : Colors.white;
    final selectedText = AppColors.primaryTeal;
    final unselectedText = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Container(
      height: height,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Arabic Option
          GestureDetector(
            onTap: () {
              if (!isArabic) {
                HapticFeedback.lightImpact();
                ref.read(localeProvider.notifier).setLocale(const Locale('ar', 'EG'));
              }
            },
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isArabic ? selectedBg : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isArabic
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  'العربية',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: isArabic ? FontWeight.bold : FontWeight.w600,
                    color: isArabic ? selectedText : unselectedText,
                  ),
                ),
              ),
            ),
          ),

          // English Option
          GestureDetector(
            onTap: () {
              if (isArabic) {
                HapticFeedback.lightImpact();
                ref.read(localeProvider.notifier).setLocale(const Locale('en', 'US'));
              }
            },
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: !isArabic ? selectedBg : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: !isArabic
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  'EN',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: !isArabic ? FontWeight.bold : FontWeight.w600,
                    color: !isArabic ? selectedText : unselectedText,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
