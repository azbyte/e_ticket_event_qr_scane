import 'package:flutter/material.dart';

/// Central application theme.
///
/// Colors and typography are defined here so they stay consistent across
/// Android and Web (PRD section 7.1). Uses the Warm Editorial Terracotta &
/// Charcoal palette across the entire platform.
class AppTheme {
  AppTheme._();

  // Brand & Primary Palette
  static const Color primaryColor = Color(0xFFC94426); // Terracotta Red
  static const Color primaryDarkColor = Color(0xFFA8351C); // Deep Terracotta
  static const Color secondaryColor = Color(0xFF1E1E1E); // Charcoal Black

  // Neutral Surfaces & Typography
  static const Color surfaceColor = Color(0xFFF6F6F6); // Soft Alabaster
  static const Color pureWhite = Color(0xFFFFFFFF); // Pure White
  static const Color subtleGray = Color(0xFFE2E2E2); // Subtle Gray
  static const Color warmLightGray = Color(0xFFEAEAEA); // Warm Light Gray
  static const Color softTerracottaBg = Color(0xFFFDF3F1); // Krem Lembut
  static const Color offBlack = Color(0xFF181818); // Off-Black
  static const Color slateGray = Color(0xFF7A7A7A); // Slate Gray
  static const Color ashGray = Color(0xFFA8A8A8); // Ash Gray

  // Semantic Status Colors
  static const Color errorColor = Color(0xFFE03E3E); // Crimson Rose
  static const Color softRedBg = Color(0xFFFDF2F2); // Soft Crimson bg
  static const Color successColor = Color(0xFF2E8B57); // Emerald Green
  static const Color softGreenBg = Color(0xFFE8F5EE); // Soft Emerald bg
  static const Color warningColor = Color(0xFFD97706); // Warm Amber
  static const Color softAmberBg = Color(0xFFFEF3C7); // Soft Amber bg

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      onPrimary: pureWhite,
      primaryContainer: softTerracottaBg,
      onPrimaryContainer: primaryColor,
      secondary: secondaryColor,
      onSecondary: pureWhite,
      secondaryContainer: warmLightGray,
      onSecondaryContainer: offBlack,
      surface: pureWhite,
      onSurface: offBlack,
      onSurfaceVariant: slateGray,
      outline: subtleGray,
      outlineVariant: subtleGray,
      error: errorColor,
      onError: pureWhite,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surfaceColor,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: pureWhite,
        foregroundColor: offBlack,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: offBlack),
        titleTextStyle: TextStyle(
          color: offBlack,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        shape: Border(bottom: BorderSide(color: subtleGray, width: 1)),
      ),
      cardTheme: CardThemeData(
        color: pureWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: subtleGray, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: subtleGray,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: pureWhite,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: pureWhite,
          foregroundColor: offBlack,
          side: const BorderSide(color: subtleGray),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: pureWhite,
        splashColor: primaryDarkColor,
        elevation: 2,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: secondaryColor,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primaryColor,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: pureWhite);
          }
          return const IconThemeData(color: ashGray);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: pureWhite,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            color: ashGray,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pureWhite,
        labelStyle: const TextStyle(color: slateGray),
        hintStyle: const TextStyle(color: ashGray),
        prefixIconColor: slateGray,
        suffixIconColor: slateGray,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: subtleGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: subtleGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: warmLightGray,
        selectedColor: softTerracottaBg,
        side: const BorderSide(color: subtleGray),
        labelStyle: const TextStyle(
          color: offBlack,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          color: primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: primaryColor,
        unselectedLabelColor: slateGray,
        indicatorColor: primaryColor,
        dividerColor: subtleGray,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: pureWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: subtleGray),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: pureWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: primaryColor,
        textColor: offBlack,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: secondaryColor,
        contentTextStyle: const TextStyle(color: pureWhite),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
