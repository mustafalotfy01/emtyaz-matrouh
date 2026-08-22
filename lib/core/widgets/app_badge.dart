import 'package:flutter/material.dart';
import '../theme/app_design_tokens.dart';

enum AppBadgeVariant {
  neutral,
  primary,
  success,
  warning,
  danger,
  info,
  shiftMorning,
  shiftLong,
  shiftNight,
}

enum AppBadgeSize {
  small,
  medium,
  large,
}

class AppBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final AppBadgeVariant variant;
  final AppBadgeSize size;
  final VoidCallback? onTap;

  const AppBadge({
    super.key,
    required this.label,
    this.icon,
    this.variant = AppBadgeVariant.neutral,
    this.size = AppBadgeSize.medium,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignTokens.isDark(context);

    Color bg;
    Color textColor;
    Color? borderColor;

    switch (variant) {
      case AppBadgeVariant.neutral:
        bg = isDark ? AppDesignTokens.surfaceMutedDark : AppDesignTokens.surfaceMutedLight;
        textColor = AppDesignTokens.textSecondary(context);
        borderColor = AppDesignTokens.border(context);
        break;
      case AppBadgeVariant.primary:
        bg = isDark ? AppDesignTokens.primaryDark.withOpacity(0.4) : AppDesignTokens.primaryLight;
        textColor = AppDesignTokens.primary;
        borderColor = AppDesignTokens.primary.withOpacity(0.3);
        break;
      case AppBadgeVariant.success:
        bg = isDark ? AppDesignTokens.successBgDark : AppDesignTokens.successBgLight;
        textColor = AppDesignTokens.success;
        borderColor = AppDesignTokens.success.withOpacity(0.3);
        break;
      case AppBadgeVariant.warning:
        bg = isDark ? AppDesignTokens.warningBgDark : AppDesignTokens.warningBgLight;
        textColor = AppDesignTokens.warning;
        borderColor = AppDesignTokens.warning.withOpacity(0.3);
        break;
      case AppBadgeVariant.danger:
        bg = isDark ? AppDesignTokens.dangerBgDark : AppDesignTokens.dangerBgLight;
        textColor = AppDesignTokens.danger;
        borderColor = AppDesignTokens.danger.withOpacity(0.3);
        break;
      case AppBadgeVariant.info:
        bg = isDark ? AppDesignTokens.infoBgDark : AppDesignTokens.infoBgLight;
        textColor = AppDesignTokens.info;
        borderColor = AppDesignTokens.info.withOpacity(0.3);
        break;
      case AppBadgeVariant.shiftMorning:
        bg = isDark ? AppDesignTokens.shiftMorningBgDark : AppDesignTokens.shiftMorningBgLight;
        textColor = AppDesignTokens.shiftMorning;
        borderColor = AppDesignTokens.shiftMorning.withOpacity(0.3);
        break;
      case AppBadgeVariant.shiftLong:
        bg = isDark ? AppDesignTokens.shiftLongBgDark : AppDesignTokens.shiftLongBgLight;
        textColor = AppDesignTokens.shiftLong;
        borderColor = AppDesignTokens.shiftLong.withOpacity(0.3);
        break;
      case AppBadgeVariant.shiftNight:
        bg = isDark ? AppDesignTokens.shiftNightBgDark : AppDesignTokens.shiftNightBgLight;
        textColor = isDark ? Colors.white : AppDesignTokens.shiftNight;
        borderColor = isDark ? AppDesignTokens.borderDark : AppDesignTokens.shiftNight.withOpacity(0.3);
        break;
    }

    double fontSize;
    double iconSize;
    EdgeInsetsGeometry padding;

    switch (size) {
      case AppBadgeSize.small:
        fontSize = 10.5;
        iconSize = 12.0;
        padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2);
        break;
      case AppBadgeSize.medium:
        fontSize = 11.5;
        iconSize = 14.0;
        padding = const EdgeInsets.symmetric(horizontal: 9, vertical: 4);
        break;
      case AppBadgeSize.large:
        fontSize = 13.0;
        iconSize = 16.0;
        padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
        break;
    }

    final badge = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.1,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusSm),
        child: badge,
      );
    }

    return badge;
  }
}
