import 'package:flutter/material.dart';

/// Semantic color design tokens for the Famli application.
/// Ensures consistent brand identity, gamification tones, and accessible contrast
/// across both light and dark themes.
class AppColors {
  AppColors._();

  // --- Brand Core ---
  static const Color brandPrimary = Color(0xFF6C63FF);
  static const Color brandSecondary = Color(0xFF8B5CF6);
  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandPrimary, brandSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // --- Semantic Gamification & Activity ---
  /// Streaks, flame milestones, and warmth
  static const Color streakAmber = Color(0xFFF59E0B);
  static const Color streakAmberDark = Color(0xFFD97706);

  /// Seeds balance, coins, and tangible rewards
  static const Color seedGold = Color(0xFFEAB308);
  static const Color seedGoldDark = Color(0xFFCA8A04);

  /// Completed tasks, achievements, and positive success
  static const Color progressEmerald = Color(0xFF10B981);
  static const Color progressEmeraldDark = Color(0xFF059669);

  /// Nudges, reminders, and gentle alerts
  static const Color nudgeSky = Color(0xFF0EA5E9);
  static const Color nudgeSkyDark = Color(0xFF0284C7);

  /// Privilege tickets, rewards, and joy
  static const Color privilegeViolet = Color(0xFF8B5CF6);
  static const Color privilegeVioletDark = Color(0xFF7C3AED);

  /// Penalties, seed deductions, and warnings
  static const Color penaltyCoral = Color(0xFFEF4444);
  static const Color penaltyCoralDark = Color(0xFFDC2626);

  // --- Surfaces & Neutrals ---
  static const Color lightScaffold = Color(0xFFF8F5FF);
  static const Color darkScaffold = Color(0xFF0F172A);

  static const Color lightCard = Colors.white;
  static const Color darkCard = Color(0xFF1E293B);

  static const Color lightBorder = Color(0xFFF1F5F9);
  static const Color darkBorder = Color(0xFF334155);

  static const Color textPrimaryLight = Color(0xFF111827);
  static const Color textPrimaryDark = Colors.white;

  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // --- Pill Background Helpers (with high contrast) ---
  static Color softBackground(Color color, bool isDark) {
    return color.withValues(alpha: isDark ? 0.20 : 0.12);
  }

  static Color accessibleTextColor(Color color, bool isDark) {
    if (isDark) {
      // Lighten the color slightly for dark background legibility
      return Color.lerp(color, Colors.white, 0.25) ?? color;
    }
    // Darken the color slightly for light background legibility
    return Color.lerp(color, Colors.black, 0.20) ?? color;
  }
}
