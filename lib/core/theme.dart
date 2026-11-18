import 'package:flutter/material.dart';

/// LEDiHA Brand Color Palette based on the official logo:
/// - "LED" is Golden Yellow
/// - Vintage TV box is Bright Red
/// - "iHA" inside the screen is Teal / Turquoise
/// - Tagline: "Your TV Repair Partner"
class AppColors {
  // Primary Logo Colors
  static const Color brandRed = Color(0xFFED3833);       // TV box frame
  static const Color brandRedDark = Color(0xFFC62828);
  static const Color brandRedLight = Color(0xFFFFEBEE);

  static const Color brandYellow = Color(0xFFFFB300);    // "LED" gold/amber
  static const Color brandYellowDark = Color(0xFFF57F17);
  static const Color brandYellowLight = Color(0xFFFFF8E1);

  static const Color brandTeal = Color(0xFF0D8A7D);      // "iHA" turquoise
  static const Color brandTealDark = Color(0xFF00695C);
  static const Color brandTealLight = Color(0xFFE0F2F1);

  // Neutral Colors
  static const Color darkSlate = Color(0xFF1E293B);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  static const Color scaffoldBg = Color(0xFFF8FAFC);
  static const Color cardBg = Colors.white;
  static const Color divider = Color(0xFFE2E8F0);

  // Status Colors for TV Repairs
  static const Color statusNew = Color(0xFF0284C7);        // Blue
  static const Color statusContacted = Color(0xFFF59E0B);  // Amber
  static const Color statusFollowup = Color(0xFF8B5CF6);   // Violet
  static const Color statusConverted = Color(0xFF10B981);  // Green (Work Done/Delivered)
  static const Color statusLost = Color(0xFFEF4444);       // Red
  static const Color statusHot = Color(0xFFEA580C);        // Deep Orange
  static const Color statusPending = Color(0xFF3B82F6);    // Blue
  static const Color statusInProgress = Color(0xFFF97316); // Orange (In Workshop)
}

class AppTheme {
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.brandRed,
      onPrimary: Colors.white,
      primaryContainer: AppColors.brandRedLight,
      onPrimaryContainer: AppColors.brandRedDark,
      secondary: AppColors.brandTeal,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.brandTealLight,
      onSecondaryContainer: AppColors.brandTealDark,
      tertiary: AppColors.brandYellow,
      onTertiary: Colors.black,
      tertiaryContainer: AppColors.brandYellowLight,
      onTertiaryContainer: AppColors.brandYellowDark,
      error: const Color(0xFFDC2626),
      onError: Colors.white,
      surface: AppColors.cardBg,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: const Color(0xFFF1F5F9),
      outline: const Color(0xFFCBD5E1),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.scaffoldBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.brandRed,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 1.5,
        shadowColor: Colors.black.withAlpha(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.brandRed, width: 1.8),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandRed,
          foregroundColor: Colors.white,
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brandRed,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandRed,
          side: const BorderSide(color: AppColors.brandRed, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 6,
        height: 65,
        indicatorColor: AppColors.brandRed.withAlpha(30),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.brandRed,
            );
          }
          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.brandRed, size: 24);
          }
          return const IconThemeData(color: AppColors.textSecondary, size: 22);
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 0.8,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.brandRed.withAlpha(30),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
      ),
    );
  }
}
