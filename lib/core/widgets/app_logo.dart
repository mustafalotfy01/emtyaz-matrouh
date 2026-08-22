import 'package:flutter/material.dart';
import '../constants/app_assets.dart';
import '../theme/app_design_tokens.dart';

/// Centralized adaptive App Logo widget.
/// Adapts color automatically based on Theme (turns into brand identity teal in Dark Mode)
/// or keeps crisp white on dark containers.
class AppLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool isHorizontal;
  final bool onDarkBackground;
  final Color? customColor;
  final Alignment alignment;

  const AppLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.isHorizontal = false,
    this.onDarkBackground = false,
    this.customColor,
    this.alignment = Alignment.center,
  });

  const AppLogo.horizontal({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.onDarkBackground = false,
    this.customColor,
    this.alignment = Alignment.center,
  }) : isHorizontal = true;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Resolve tint color based on theme and context:
    // 1. If custom color provided, use it.
    // 2. In Dark Mode, tint to brand identity teal.
    // 3. In Light Mode on dark/teal background, render native white.
    // 4. In Light Mode on light background, tint with primary teal for maximum clarity.
    Color? resolvedColor = customColor;
    if (resolvedColor == null) {
      if (isDarkMode) {
        resolvedColor = AppDesignTokens.primary;
      } else if (!onDarkBackground) {
        resolvedColor = AppDesignTokens.primary;
      }
    }

    final assetPath = isHorizontal ? AppAssets.logoHorizontal : AppAssets.logo;

    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      color: resolvedColor,
      colorBlendMode: resolvedColor != null ? BlendMode.srcIn : null,
    );
  }
}