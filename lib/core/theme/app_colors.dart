import 'package:flutter/material.dart';

class AppColors {
  // Greek Pantheon Palette (Stygian Black, Olympian Gold, Imperial Crimson, Marble White, Olive Green)
  static const Color background = Color(0xFF000000);   // Stygian Black
  static const Color surface = Color(0xFF0A0A0C);      // Obsidian Dark
  static const Color surfaceLight = Color(0xFF141416);  // Deep Charcoal
  
  // Divine Accents (Muted metallic & natural colors - Less neon glowing)
  static const Color primaryBlue = Color(0xFFD4AF37);   // Olympian Gold (Hermes / Apollo)
  static const Color primaryPurple = Color(0xFF800020); // Imperial Crimson / Burgundy (Zeus / Ares)
  static const Color cyanGlow = Color(0xFFF5F5F0);      // Pure Pentelic Marble / Ivory (Athena)
  static const Color emeraldGreen = Color(0xFF556B2F);  // Sacred Olive Laurel Wreath (Demeter / Nike)
  static const Color amberWarning = Color(0xFFCD7F32);  // Hephaestus Bronze
  static const Color roseError = Color(0xFF9E2A2B);     // Volcanic Maroon (Hades)

  // Glassmorphic / Translucent Highlights
  static const Color glassBackground = Color(0x1F1A1A1A); 
  static const Color glassBorder = Color(0x22FFFFFF);     
  static const Color glassBorderGlow = Color(0x33D4AF37); // Subtle gold leaf highlight border

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);   
  static const Color textSecondary = Color(0xFFCCCCCC); 
  static const Color textMuted = Color(0xFF888888);     

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
      Color(0x1AFFFFFF),
      Color(0x08FFFFFF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
