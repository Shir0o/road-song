import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BrutalTheme {
  // Theme Colors (mapped to Scrapbook/Typewriter palette)
  static const Color primary = Color(0xFFC05B3E); // Accent (Brick Red)
  static const Color yellow = Color(0xFFF1E7D1); // Paper2 (Secondary beige)
  static const Color cyan = Color(0xFFEBDFC6); // Soft border color
  static const Color backgroundLight = Color(0xFFF8F2E4); // Warm paper cream
  static const Color backgroundDark = Color(0xFF4A3B2C); // Dark wood/tape
  static const Color inkBlack = Color(0xFF443729); // Dark charcoal-brown ink
  static const Color graphite = Color(0xFF8D7C63); // Muted brown

  // Scrapbook specifics
  static const Color paper = Color(0xFFF8F2E4);
  static const Color paper2 = Color(0xFFF1E7D1);
  static const Color card = Color(0xFFFFFDF4);

  // Standard Scrapbook Border (softer and thinner)
  static Border brutalBorder({double width = 1.0, Color color = const Color(0xFFE1D4B6)}) {
    return Border.all(
      color: color,
      width: width,
    );
  }

  // Standard Scrapbook Tactile Shadow
  static List<BoxShadow> brutalShadow({
    Offset offset = const Offset(0, 10),
    Color color = const Color(0x59433729), // rgba(67, 55, 41, 0.35)
  }) {
    return [
      const BoxShadow(
        color: Color(0x0D433729), // 0 1px 0 rgba(67, 55, 41, 0.05)
        offset: Offset(0, 1),
        blurRadius: 0,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: color,
        offset: offset,
        blurRadius: 24,
        spreadRadius: -18,
      ),
    ];
  }

  // Helper decoration
  static BoxDecoration brutalDecoration({
    Color color = Colors.white,
    BorderRadiusGeometry? borderRadius,
    double borderWidth = 1.0,
    Color borderColor = const Color(0xFFE1D4B6),
    Offset shadowOffset = const Offset(0, 10),
    Color shadowColor = const Color(0x59433729),
    bool showShadow = true,
  }) {
    return BoxDecoration(
      color: color,
      border: brutalBorder(width: borderWidth, color: borderColor),
      borderRadius: borderRadius ?? BorderRadius.circular(10.0), // Rounded corners default
      boxShadow: showShadow ? brutalShadow(offset: shadowOffset, color: shadowColor) : null,
    );
  }

  /// Sentence-case CTA label style shared by primary/secondary actions
  /// (Karla 700 with 0.02em tracking, per the design comp).
  static TextStyle ctaLabelStyle({
    double fontSize = 16,
    Color color = Colors.white,
  }) =>
      GoogleFonts.karla(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: fontSize * 0.02,
        color: color,
      );
}
