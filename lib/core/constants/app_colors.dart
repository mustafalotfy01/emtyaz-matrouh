import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Brand Identity (Matrouh Nursing) ──────────────────────────────────────
  static const Color primaryTeal = Color(0xFF0A7B83);
  static const Color deepNavy = Color(0xFF0E3B43);
  static const Color secondaryTeal = Color(0xFF149B9B);
  static const Color accentCyan = Color(0xFF22D3EE);

  // ── Light Theme Tokens ────────────────────────────────────────────────────
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color borderMedium = Color(0xFFE2E8F0);

  // ── iOS Dark Theme Tokens (Required Specification) ────────────────────────
  static const Color darkBg = Color(0xFF0B1117);
  static const Color darkSurface = Color(0xFF121A22);
  static const Color darkElevated = Color(0xFF18232D);
  static const Color darkSecondarySurface = Color(0xFF1D2A35);
  static const Color darkTextPrimary = Color(0xFFF5F7F9);
  static const Color darkTextSecondary = Color(0xFFAAB6C2);
  static const Color darkDivider = Color(0xFF26333E);

  // ── Dynamic Color Resolvers ───────────────────────────────────────────────
  static Color bg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBg : lightBg;

  static Color card(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurface : surfaceCard;

  static Color elevated(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkElevated : surfaceWhite;

  static Color text(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextPrimary : textPrimary;

  static Color subtext(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextSecondary : textSecondary;

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkDivider : borderLight;

  static Color muted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSecondarySurface : surfaceMuted;

  // ── State & Shift Colors (Subtle & Meaningful) ──────────────────────────────
  static const Color morningBlue = Color(0xFF0284C7);
  static const Color morningBlueBg = Color(0xFFE0F2FE);
  static const Color morningBlueDarkBg = Color(0xFF0C2740);

  static const Color longPurple = Color(0xFF7C3AED);
  static const Color longPurpleBg = Color(0xFFEDE9FE);
  static const Color longPurpleDarkBg = Color(0xFF241442);

  static const Color nightDark = Color(0xFF0E3B43);
  static const Color nightDarkBg = Color(0xFFE2E8F0);
  static const Color nightDarkThemeBg = Color(0xFF132832);

  // ── Quick Tile Tints ──────────────────────────────────────────────────────
  static const Color tilePurple = Color(0xFF8B5CF6);
  static const Color tileTeal = Color(0xFF10B981);
  static const Color tileOrange = Color(0xFFF97316);
  static const Color tileBlue = Color(0xFF0EA5E9);
  static const Color tilePink = Color(0xFFEC4899);

  // ── Status Accents ────────────────────────────────────────────────────────
  static const Color success = Color(0xFF059669);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color successDarkBg = Color(0xFF063124);

  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningDarkBg = Color(0xFF332005);

  static const Color danger = Color(0xFFE11D48);
  static const Color dangerLight = Color(0xFFFFE4E6);
  static const Color dangerDarkBg = Color(0xFF360C16);

  static const Color info = Color(0xFF2563EB);
  static const Color infoLight = Color(0xFFDBEAFE);
  static const Color infoDarkBg = Color(0xFF0D2552);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0A7B83), Color(0xFF0E3B43)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroDarkGradient = LinearGradient(
    colors: [Color(0xFF0A7B83), Color(0xFF121A22)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient quizBannerGradient = LinearGradient(
    colors: [Color(0xFFFB923C), Color(0xFFEA580C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
