import 'package:flutter/material.dart';

class AppColors {
  // Primary Palette
  static const Color background = Color(0xFF0F172A); // Slate 900
  static const Color surface = Color(0xFF1E293B);    // Slate 800
  static const Color surfaceLight = Color(0xFF334155); // Slate 700
  
  // Neon & Vivid Accents
  static const Color primaryBlue = Color(0xFF2563EB); // Vivid Blue
  static const Color primaryPurple = Color(0xFF7C3AED); // Deep Violet
  static const Color cyanGlow = Color(0xFF06B6D4);    // Cyan
  static const Color emeraldGreen = Color(0xFF10B981); // Emerald Green
  static const Color amberWarning = Color(0xFFF59E0B); // Amber
  static const Color roseError = Color(0xFFF43F5E);   // Rose

  // Glassmorphic Colors
  static const Color glassBackground = Color(0x1F1E293B); // Translucent surface
  static const Color glassBorder = Color(0x33FFFFFF);     // Subtle white highlight border
  static const Color glassBorderGlow = Color(0x402563EB); // Subtle blue glow border

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);   // White / Slate 50
  static const Color textSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color textMuted = Color(0xFF64748B);     // Slate 500

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryBlue, primaryPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanPurpleGradient = LinearGradient(
    colors: [cyanGlow, primaryPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldCyanGradient = LinearGradient(
    colors: [emeraldGreen, cyanGlow],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [
      Color(0x26FFFFFF),
      Color(0x0DFFFFFF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
