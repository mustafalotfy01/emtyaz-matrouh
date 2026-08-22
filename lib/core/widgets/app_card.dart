import 'package:flutter/material.dart';
import '../theme/app_design_tokens.dart';

enum AppCardVariant {
  standard,
  outlined,
  elevated,
  accentTeal,
  accentWarning,
  accentDanger,
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderRadius;
  final VoidCallback? onTap;
  final AppCardVariant variant;
  final double? width;
  final double? height;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.onTap,
    this.variant = AppCardVariant.standard,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignTokens.isDark(context);
    final effectiveRadius = borderRadius ?? AppDesignTokens.radiusLg;

    Color bg;
    Color border;
    List<BoxShadow>? shadows;

    switch (variant) {
      case AppCardVariant.standard:
        bg = backgroundColor ?? AppDesignTokens.surface(context);
        border = borderColor ?? AppDesignTokens.border(context);
        shadows = AppDesignTokens.cardShadow(context);
        break;
      case AppCardVariant.outlined:
        bg = backgroundColor ?? Colors.transparent;
        border = borderColor ?? AppDesignTokens.border(context);
        shadows = null;
        break;
      case AppCardVariant.elevated:
        bg = backgroundColor ?? AppDesignTokens.surfaceElevated(context);
        border = borderColor ?? AppDesignTokens.border(context);
        shadows = [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ];
        break;
      case AppCardVariant.accentTeal:
        bg = backgroundColor ?? (isDark ? AppDesignTokens.surfaceDark : AppDesignTokens.primaryLight.withOpacity(0.5));
        border = borderColor ?? AppDesignTokens.primary.withOpacity(0.35);
        shadows = AppDesignTokens.cardShadow(context);
        break;
      case AppCardVariant.accentWarning:
        bg = backgroundColor ?? (isDark ? AppDesignTokens.warningBgDark : AppDesignTokens.warningBgLight);
        border = borderColor ?? AppDesignTokens.warning.withOpacity(0.4);
        shadows = null;
        break;
      case AppCardVariant.accentDanger:
        bg = backgroundColor ?? (isDark ? AppDesignTokens.dangerBgDark : AppDesignTokens.dangerBgLight);
        border = borderColor ?? AppDesignTokens.danger.withOpacity(0.4);
        shadows = null;
        break;
    }

    final cardContent = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: Border.all(color: border, width: 1),
        boxShadow: shadows,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(effectiveRadius),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
