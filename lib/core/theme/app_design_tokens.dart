import 'package:flutter/material.dart';

/// Centralized Design Tokens for the Matrouh Nursing System
class AppDesignTokens {
  AppDesignTokens._();

  // ── Brand Archetype (Clinical Teal & Deep Slate Navy) ────────────────────
  static const Color primary = Color(0xFF0A7B83);
  static const Color primaryDark = Color(0xFF075960);
  static const Color primaryLight = Color(0xFFE6F4F5);
  static const Color primaryAccent = Color(0xFF149B9B);
  static const Color accentGold = Color(0xFFF59E0B);

  static const Color navyDark = Color(0xFF0E3B43);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMedium = Color(0xFF334155);
  static const Color slateMuted = Color(0xFF64748B);

  // ── Light Theme Surfaces & Neutrals ───────────────────────────────────────
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceMutedLight = Color(0xFFF1F5F9);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderSubtleLight = Color(0xFFF1F5F9);

  // ── Dark Theme Surfaces & Neutrals ────────────────────────────────────────
  static const Color bgDark = Color(0xFF0B1117);
  static const Color surfaceDark = Color(0xFF121A22);
  static const Color surfaceElevatedDark = Color(0xFF18232D);
  static const Color surfaceMutedDark = Color(0xFF1D2A35);
  static const Color borderDark = Color(0xFF26333E);
  static const Color borderSubtleDark = Color(0xFF1B242D);

  // ── Text Tokens ───────────────────────────────────────────────────────────
  static const Color textLightPrimary = Color(0xFF0F172A);
  static const Color textLightSecondary = Color(0xFF475569);
  static const Color textLightMuted = Color(0xFF94A3B8);

  static const Color textDarkPrimary = Color(0xFFF8FAFC);
  static const Color textDarkSecondary = Color(0xFFAAB6C2);
  static const Color textDarkMuted = Color(0xFF64748B);

  // ── Shift Indicators (Restrained & Functional Tints) ─────────────────────
  // Morning (8h)
  static const Color shiftMorning = Color(0xFF0284C7);
  static const Color shiftMorningBgLight = Color(0xFFE0F2FE);
  static const Color shiftMorningBgDark = Color(0xFF0C2740);

  // Long (12h)
  static const Color shiftLong = Color(0xFF7C3AED);
  static const Color shiftLongBgLight = Color(0xFFEDE9FE);
  static const Color shiftLongBgDark = Color(0xFF241442);

  // Night (12h)
  static const Color shiftNight = Color(0xFF0E3B43);
  static const Color shiftNightBgLight = Color(0xFFE2E8F0);
  static const Color shiftNightBgDark = Color(0xFF132832);

  // ── Semantic Feedback ─────────────────────────────────────────────────────
  static const Color success = Color(0xFF059669);
  static const Color successBgLight = Color(0xFFECFDF5);
  static const Color successBgDark = Color(0xFF063124);

  static const Color warning = Color(0xFFD97706);
  static const Color warningBgLight = Color(0xFFFFFBEB);
  static const Color warningBgDark = Color(0xFF332005);

  static const Color danger = Color(0xFFDC2626);
  static const Color dangerBgLight = Color(0xFFFEF2F2);
  static const Color dangerBgDark = Color(0xFF360C16);

  static const Color info = Color(0xFF2563EB);
  static const Color infoBgLight = Color(0xFFEFF6FF);
  static const Color infoBgDark = Color(0xFF0D2552);

  // ── Spacing Scale (Grid: 4px) ─────────────────────────────────────────────
  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;

  // ── Border Radii Scale ────────────────────────────────────────────────────
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusFull = 999.0;

  // ── Responsive Breakpoints ────────────────────────────────────────────────
  static const double breakpointMobile = 640.0;
  static const double breakpointTablet = 1024.0;

  // ── Dynamic Context Helpers ───────────────────────────────────────────────
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) =>
      isDark(context) ? bgDark : bgLight;

  static Color surface(BuildContext context) =>
      isDark(context) ? surfaceDark : surfaceLight;

  static Color surfaceElevated(BuildContext context) =>
      isDark(context) ? surfaceElevatedDark : surfaceLight;

  static Color surfaceMuted(BuildContext context) =>
      isDark(context) ? surfaceMutedDark : surfaceMutedLight;

  static Color border(BuildContext context) =>
      isDark(context) ? borderDark : borderLight;

  static Color borderSubtle(BuildContext context) =>
      isDark(context) ? borderSubtleDark : borderSubtleLight;

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? textDarkPrimary : textLightPrimary;

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? textDarkSecondary : textLightSecondary;

  static Color textMuted(BuildContext context) =>
      isDark(context) ? textDarkMuted : textLightMuted;

  // Subtle Clinical Box Shadow (Never heavy or multi-layer colorful)
  static List<BoxShadow> cardShadow(BuildContext context) {
    if (isDark(context)) {
      return [
        BoxShadow(
          color: Colors.black.withOpacity(0.20),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
    }
    return [
      BoxShadow(
        color: const Color(0xFF0F172A).withOpacity(0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }
}
