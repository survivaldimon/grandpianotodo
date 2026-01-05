import 'package:flutter/material.dart';

/// Цветовая палитра приложения
class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════════════════════
  // PRIMARY (общие для обеих тем)
  // ═══════════════════════════════════════════════════════════════════
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);

  // ═══════════════════════════════════════════════════════════════════
  // STATUS (общие для обеих тем)
  // ═══════════════════════════════════════════════════════════════════
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ═══════════════════════════════════════════════════════════════════
  // LESSON TYPES (общие для обеих тем)
  // ═══════════════════════════════════════════════════════════════════
  static const Color lessonIndividual = Color(0xFF3B82F6);
  static const Color lessonGroup = Color(0xFF8B5CF6);

  // ═══════════════════════════════════════════════════════════════════
  // LIGHT THEME
  // ═══════════════════════════════════════════════════════════════════
  // Background
  static const Color background = Color(0xFFF9FAFB);
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF3F4F6);

  // Text
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  // Borders
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);

  // ═══════════════════════════════════════════════════════════════════
  // DARK THEME
  // ═══════════════════════════════════════════════════════════════════
  // Background
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceVariant = Color(0xFF2C2C2C);
  static const Color darkSurfaceElevated = Color(0xFF333333);

  // Text
  static const Color darkTextPrimary = Color(0xFFE1E1E1);
  static const Color darkTextSecondary = Color(0xFF9E9E9E);
  static const Color darkTextTertiary = Color(0xFF757575);

  // Borders
  static const Color darkBorder = Color(0xFF3D3D3D);
  static const Color darkBorderLight = Color(0xFF2C2C2C);
}
