import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';

/// Premium iOS Squircle Card with soft shadows, dynamic Dark Mode surface & border
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final double borderRadius;
  final Border? border;
  final List<BoxShadow>? shadows;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.gradient,
    this.onTap,
    this.borderRadius = AppTheme.radiusLg,
    this.border,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg = gradient == null
        ? (backgroundColor ?? AppColors.card(context))
        : null;
    final effectiveBorder = border ?? Border.all(color: AppColors.border(context), width: 1);
    final effectiveShadows = shadows ?? AppTheme.iosCardShadow(context);

    Widget cardContent = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveBg,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: effectiveBorder,
        boxShadow: effectiveShadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
