import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Primary & Vibrant Blues (Infinity Brand)
  // ---------------------------------------------------------------------------
  static const Color primary = Color(0xFF00A3FF);
  static const Color primaryDark = Color(0xFF005C99);
  static const Color primaryDarkBlue = Color(0xFF0084D1);
  static const Color primaryVibrant = Color(0xFF0089D8);
  static const Color primaryDeep = Color(0xFF0077BE);
  static const Color primarySoft = Color(0xFFE0F7FF);
  static const Color accent = Color(0xFF00A3FF);
  static const Color accentSoft = Color(0xFFE0F7FF);

  // ---------------------------------------------------------------------------
  // Backgrounds & Gradients
  // ---------------------------------------------------------------------------
  static const Color ambientGradientStart = Color.fromARGB(255, 19, 161, 237);
  static const Color ambientGradientMiddle = Color.fromARGB(255, 4, 104, 233);
  static const Color ambientGradientEnd = Color.fromARGB(255, 37, 92, 115);
  static const Color background = Color(0xFFEFF0F2);
  static const Color surface = Color(0xFFFFFFFF);

  static const List<Color> ambientGradientColors = [
    ambientGradientStart,
    ambientGradientMiddle,
    ambientGradientEnd,
  ];

  static const List<Color> bannerBlueGradient = [primaryVibrant, primaryDeep];

  // ---------------------------------------------------------------------------
  // Cyan & Ice-Blue Tints (Badges, Pills, Cards, Gauges)
  // ---------------------------------------------------------------------------
  static const Color cyanBadgeBg = Color(0xFFD6F2FE);
  static const Color cyanPillBg = Color(0xFFE2F4FC);
  static const Color cyanPillBgSoft = Color(0xFFE5F5FD);
  static const Color cyanPillBorder = Color(0xFFBCE3F7);
  static const Color cyanActiveChip = Color(0xFFB8F5FF);
  static const Color cyanToggleBg = Color(0xFFD9F4FF);
  static const Color iceBlueBg = Color(0xFFF0F9FD);
  static const Color iceBlueBgSoft = Color(0xFFEAF8FE);
  static const Color iceBlueBorder = Color(0xFFE2F3FC);
  static const Color gaugeTrack = Color(0xFFE2F3FC);
  static const Color mintSoft = Color(0xFFE2F6F5);

  // ---------------------------------------------------------------------------
  // Gauge Colors
  // ---------------------------------------------------------------------------
  static const Color gaugeGradientStart = Color(0xFF38B6FF);
  static const Color gaugeGradientMiddle = Color(0xFF00A3FF);
  static const Color gaugeGradientEnd = Color(0xFF0077E6);

  static const List<Color> gaugeGradientColors = [
    gaugeGradientStart,
    gaugeGradientMiddle,
    gaugeGradientEnd,
  ];

  // ---------------------------------------------------------------------------
  // Calendar Strip
  // ---------------------------------------------------------------------------
  static const Color calendarDate = Color(0xFF8897E6);
  static const Color calendarWeekday = Color(0xFFA0AEF5);

  // ---------------------------------------------------------------------------
  // Typography
  // ---------------------------------------------------------------------------
  static const Color textDark = Color(0xFF111827);
  static const Color textSubtitle = Color(0xFF1F2937);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textBody = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF5D6976);
  static const Color textSlate = Color(0xFF7B8FA6);
  static const Color textLight = Color(0xFF9EACB7);

  // ---------------------------------------------------------------------------
  // Borders, Dividers & Neutral Surfaces
  // ---------------------------------------------------------------------------
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderSubtle = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF1F5F9);
  static const Color disabled = Color(0xFF94A3B8);
  static const Color neutralSurface = Color(0xFFF8FAFC);
  static const Color navPillSelected = Color(0xFFF1F5F9);
  static const Color barrier = Color(0x33000000);

  // ---------------------------------------------------------------------------
  // Status, Accents & Badges (Red, Orange, Green, Purple)
  // ---------------------------------------------------------------------------
  static const Color redBadge = Color(0xFFE53935);
  static const Color redAccent = Color(0xFFFF5252);
  static const Color mythRed = Color(0xFFD32F2F);
  static const Color mythBg = Color(0xFFFFEBEE);
  static const Color error = Color(0xFFB91C1C);
  static const Color errorSoft = Color(0xFFFEE2E2);
  static const Color errorBorder = Color(0xFFFFCDD2);

  static const Color streakOrange = Color(0xFFFF9800);
  static const Color streakOrangeDeep = Color(0xFFE65100);
  static const Color streakOrangeBg = Color(0xFFFFF3E0);
  static const Color badgeOrangeBg = Color(0xFFFFECE0);
  static const Color badgeOrangeText = Color(0xFFFF5722);
  static const Color orangeGradientStart = Color(0xFFFF7043);
  static const Color orangeGradientEnd = Color(0xFFFF5252);
  static const Color cyanGradientStart = Color(0xFF00E5FF);
  static const Color cyanGradientEnd = Color(0xFF0091EA);

  static const Color factGreen = Color(0xFF2E7D32);
  static const Color factGreenBg = Color(0xFFE8F5E9);

  static const Color violet = Color(0xFF6200EE);
  static const Color secondary = Color(0xFF6200EE);
  static const Color violetSoft = Color(0xFFE0CCFF);
  static const Color purpleAccent = Color(0xFF7C3AED);
  static const Color purpleSoft = Color(0xFFEDE9FE);

  static const Color skyBlue = Color(0xFF0284C7);
  static const Color skyBlueSoft = Color(0xFFE0F2FE);

  // ---------------------------------------------------------------------------
  // Third Party Brand Colors
  // ---------------------------------------------------------------------------
  static const Color googleBlue = Color(0xFF4285F4);
  static const Color googleGreen = Color(0xFF34A853);
  static const Color googleYellow = Color(0xFFFBBC05);
  static const Color googleRed = Color(0xFFEA4335);
}
