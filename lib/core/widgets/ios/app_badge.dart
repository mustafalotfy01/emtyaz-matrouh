import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// Clean iOS Status & Shift Pill Badges
class AppBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;
  final double fontSize;
  final EdgeInsetsGeometry? padding;

  const AppBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
    this.fontSize = 11.5,
    this.padding,
  });

  factory AppBadge.success({required String label, IconData? icon}) {
    return AppBadge(
      label: label,
      backgroundColor: AppColors.successLight,
      textColor: AppColors.success,
      icon: icon ?? Icons.check_circle_outline,
    );
  }

  factory AppBadge.warning({required String label, IconData? icon}) {
    return AppBadge(
      label: label,
      backgroundColor: AppColors.warningLight,
      textColor: AppColors.warning,
      icon: icon ?? Icons.schedule,
    );
  }

  factory AppBadge.danger({required String label, IconData? icon}) {
    return AppBadge(
      label: label,
      backgroundColor: AppColors.dangerLight,
      textColor: AppColors.danger,
      icon: icon ?? Icons.error_outline,
    );
  }

  factory AppBadge.longShift() {
    return const AppBadge(
      label: 'Long (12h)',
      backgroundColor: AppColors.longPurpleBg,
      textColor: AppColors.longPurple,
      icon: Icons.wb_sunny_outlined,
    );
  }

  factory AppBadge.nightShift() {
    return const AppBadge(
      label: 'Night (12h)',
      backgroundColor: AppColors.nightDarkBg,
      textColor: AppColors.nightDark,
      icon: Icons.bedtime_outlined,
    );
  }

  factory AppBadge.morningShift() {
    return const AppBadge(
      label: 'Morning (6h)',
      backgroundColor: AppColors.morningBlueBg,
      textColor: AppColors.morningBlue,
      icon: Icons.light_mode_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
