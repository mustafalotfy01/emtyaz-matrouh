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
  final bool tinted;
  final Alignment alignment;

  const AppLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.isHorizontal = false,
    this.onDarkBackground = false,
    this.customColor,
    this.tinted = false,
    this.alignment = Alignment.center,
  });

  const AppLogo.horizontal({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.onDarkBackground = false,
    this.customColor,
    this.tinted = true,
    this.alignment = Alignment.center,
  }) : isHorizontal = true;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    Color? resolvedColor = customColor;
    if (resolvedColor == null && tinted) {
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