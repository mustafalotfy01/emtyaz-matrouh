import 'package:flutter/material.dart';
import '../theme/app_design_tokens.dart';

/// Legacy AppColors wrapper maintaining full backwards-compatibility
/// while proxying to the new centralized AppDesignTokens.
class AppColors {
  AppColors._();

  // ── Brand Identity (Matrouh Nursing) ──────────────────────────────────────
  static const Color primaryTeal = AppDesignTokens.primary;
  static const Color deepNavy = AppDesignTokens.navyDark;
  static const Color secondaryTeal = AppDesignTokens.primaryAccent;
  static const Color accentCyan = Color(0xFF22D3EE);

  // ── Light Theme Tokens ────────────────────────────────────────────────────
  static const Color lightBg = AppDesignTokens.bgLight;
  static const Color surfaceWhite = AppDesignTokens.surfaceLight;
  static const Color surfaceCard = AppDesignTokens.surfaceLight;
  static const Color surfaceMuted = AppDesignTokens.surfaceMutedLight;
  static const Color textPrimary = AppDesignTokens.textLightPrimary;
  static const Color textSecondary = AppDesignTokens.textLightSecondary;
  static const Color textMuted = AppDesignTokens.textLightMuted;
  static const Color borderLight = AppDesignTokens.borderLight;
  static const Color borderMedium = AppDesignTokens.borderLight;

  // ── iOS Dark Theme Tokens ────────────────────────────────────────────────
  static const Color darkBg = AppDesignTokens.bgDark;
  static const Color darkSurface = AppDesignTokens.surfaceDark;
  static const Color darkElevated = AppDesignTokens.surfaceElevatedDark;
  static const Color darkSecondarySurface = AppDesignTokens.surfaceMutedDark;
  static const Color darkTextPrimary = AppDesignTokens.textDarkPrimary;
  static const Color darkTextSecondary = AppDesignTokens.textDarkSecondary;
  static const Color darkDivider = AppDesignTokens.borderDark;

  // ── Dynamic Color Resolvers ───────────────────────────────────────────────
  static Color bg(BuildContext context) => AppDesignTokens.bg(context);
  static Color card(BuildContext context) => AppDesignTokens.surface(context);
  static Color elevated(BuildContext context) => AppDesignTokens.surfaceElevated(context);
  static Color text(BuildContext context) => AppDesignTokens.textPrimary(context);
  static Color subtext(BuildContext context) => AppDesignTokens.textSecondary(context);
  static Color border(BuildContext context) => AppDesignTokens.border(context);
  static Color muted(BuildContext context) => AppDesignTokens.surfaceMuted(context);

  // ── State & Shift Colors (Subtle & Meaningful) ──────────────────────────────
  static const Color morningBlue = AppDesignTokens.shiftMorning;
  static const Color morningBlueBg = AppDesignTokens.shiftMorningBgLight;
  static const Color morningBlueDarkBg = AppDesignTokens.shiftMorningBgDark;

  static const Color longPurple = AppDesignTokens.shiftLong;
  static const Color longPurpleBg = AppDesignTokens.shiftLongBgLight;
  static const Color longPurpleDarkBg = AppDesignTokens.shiftLongBgDark;

  static const Color nightDark = AppDesignTokens.shiftNight;
  static const Color nightDarkBg = AppDesignTokens.shiftNightBgLight;
  static const Color nightDarkThemeBg = AppDesignTokens.shiftNightBgDark;

  // ── Quick Tile Tints ──────────────────────────────────────────────────────
  static const Color tilePurple = Color(0xFF7C3AED);
  static const Color tileTeal = Color(0xFF0D7E8A);
  static const Color tileOrange = Color(0xFFD97706);
  static const Color tileBlue = Color(0xFF0284C7);
  static const Color tilePink = Color(0xFFDB2777);

  // ── Status Accents ────────────────────────────────────────────────────────
  static const Color success = AppDesignTokens.success;
  static const Color successLight = AppDesignTokens.successBgLight;
  static const Color successDarkBg = AppDesignTokens.successBgDark;

  static const Color warning = AppDesignTokens.warning;
  static const Color warningLight = AppDesignTokens.warningBgLight;
  static const Color warningDarkBg = AppDesignTokens.warningBgDark;

  static const Color danger = AppDesignTokens.danger;
  static const Color dangerLight = AppDesignTokens.dangerBgLight;
  static const Color dangerDarkBg = AppDesignTokens.dangerBgDark;

  static const Color info = AppDesignTokens.info;
  static const Color infoLight = AppDesignTokens.infoBgLight;
  static const Color infoDarkBg = AppDesignTokens.infoBgDark;

  // ── Restrained Hero Gradient (Subtle depth, no rainbow blobs) ─────────────
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0A7B83), Color(0xFF075960)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroDarkGradient = LinearGradient(
    colors: [Color(0xFF075960), Color(0xFF121A22)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient quizBannerGradient = LinearGradient(
    colors: [Color(0xFF0A7B83), Color(0xFF149B9B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
