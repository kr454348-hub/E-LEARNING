import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ──────────────────────────────────────────────────────────
// AppTheme — Premium Design System (Light/Dark)
// ──────────────────────────────────────────────────────────
// Defines:
// - Colors: Semantic palette for Primary, Secondary, Backgrounds
// - Typography: Refined Poppins/Inter usage
// - Shapes: Consistent 16px border radiuses, soft shadows
// ──────────────────────────────────────────────────────────

class AppTheme {
  // ─── Semantic Colors ───
  // Primary (Indigo/Violet): Used for key actions, branding
  static const Color primaryLight = Color(0xFF4F46E5); // Indigo 600
  static const Color primaryDark = Color(0xFF818CF8); // Indigo 400

  // Secondary (Teal/Coral): Used for accents, new features
  static const Color secondaryLight = Color(0xFF0EA5E9); // Sky 500
  static const Color secondaryDark = Color(0xFF38BDF8); // Sky 400

  // Surfaces (Backgrounds, Cards)
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceLight = Colors.white;

  static const Color backgroundDark = Color(0xFF0F172A); // Slate 900
  static const Color surfaceDark = Color(0xFF1E293B); // Slate 800

  // Text Colors
  static const Color textLightPrimary = Color(0xFF1E293B); // Slate 800
  static const Color textLightSecondary = Color(0xFF64748B); // Slate 500

  static const Color textDarkPrimary = Color(0xFFF1F5F9); // Slate 100
  static const Color textDarkSecondary = Color(0xFF94A3B8); // Slate 400

  // ─── Theme Builders ───

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryLight,
        primary: primaryLight,
        secondary: secondaryLight,
        tertiary: const Color(0xFF14B8A6), // Teal 500
        surface: surfaceLight,
        onSurface: textLightPrimary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: backgroundLight,

      // TYPOGRAPHY
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme)
          .copyWith(
            displayLarge: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: textLightPrimary,
            ),
            displayMedium: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: textLightPrimary,
            ),
            titleLarge: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: textLightPrimary,
            ),
            titleMedium: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: textLightPrimary,
            ),
            bodyLarge: GoogleFonts.inter(color: textLightPrimary),
            bodyMedium: GoogleFonts.inter(color: textLightSecondary),
          ),

      // APP BAR which is minimal clean
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: backgroundLight, // Transparent/Blend
        foregroundColor: textLightPrimary,
        titleTextStyle: GoogleFonts.poppins(
          color: textLightPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: textLightPrimary),
      ),

      // CARDS
      cardTheme: CardThemeData(
        elevation:
            0, // Using subtle borders/shadows manually often better, but for theme:
        color: surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // BUTTONS
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0, // Flat modern look
          shadowColor: primaryLight.withValues(alpha: 0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryLight,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: primaryLight, width: 1.5),
        ),
      ),

      // INPUTS
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
        labelStyle: const TextStyle(color: textLightSecondary),
      ),
      iconTheme: const IconThemeData(color: textLightSecondary),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryDark,
        primary: primaryDark,
        secondary: secondaryDark,
        tertiary: const Color(0xFF2DD4BF), // Teal 400
        surface: surfaceDark,
        onSurface: textDarkPrimary,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: backgroundDark,

      // TYPOGRAPHY
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
          .copyWith(
            displayLarge: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: textDarkPrimary,
            ),
            displayMedium: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: textDarkPrimary,
            ),
            titleLarge: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: textDarkPrimary,
            ),
            titleMedium: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: textDarkPrimary,
            ),
            bodyLarge: GoogleFonts.inter(color: textDarkPrimary),
            bodyMedium: GoogleFonts.inter(color: textDarkSecondary),
          ),

      // APP BAR
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: backgroundDark,
        foregroundColor: textDarkPrimary,
        titleTextStyle: GoogleFonts.poppins(
          color: textDarkPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: textDarkPrimary),
      ),

      // CARDS
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // BUTTONS
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor:
              backgroundDark, // Dark text on light button for contrast
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDark,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: primaryDark, width: 1.5),
        ),
      ),

      // INPUTS
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
        labelStyle: const TextStyle(color: textLightSecondary),
      ),
      iconTheme: const IconThemeData(color: textLightSecondary),
    );
  }

  // ─── Premium Background Decoration ───
  static BoxDecoration premiumBackground(bool isDark) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                const Color(0xFF0F172A),
                const Color(0xFF1E293B),
                const Color(0xFF0F172A),
              ]
            : [
                const Color(0xFFF8FAFC),
                const Color(0xFFF1F5F9),
                const Color(0xFFF8FAFC),
              ],
      ),
    );
  }

  static Widget backgroundScaffold({
    required Widget body,
    PreferredSizeWidget? appBar,
    Widget? floatingActionButton,
    Widget? drawer,
    bool isDark = false,
  }) {
    return Scaffold(
      appBar: appBar,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      backgroundColor: isDark ? backgroundDark : backgroundLight,
      body: Stack(
        children: [
          Positioned.fill(child: Container(decoration: premiumBackground(isDark))),
          body,
        ],
      ),
    );
  }
}
