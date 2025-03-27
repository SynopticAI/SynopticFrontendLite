import 'package:flutter/material.dart';
// instead of        color: const Color.fromARGB(255, 51, 73, 152)
// use               color: Theme.of(context).colorScheme.primary
// or                color: AppTheme.withOpacity(AppTheme.primaryColor, 0.5)





class AppTheme {
  // Primary colors
  static const Color primaryColor = Color.fromARGB(255, 51, 73, 152);
  static const Color secondaryColor = Color.fromARGB(255, 58, 193, 209);
  static const Color primaryColorMuted = Color.fromARGB(255, 92, 110, 142);
  
  // Accent colors
  static const Color accentColor = Color.fromARGB(255, 255, 203, 24);
  static const Color secondaryAccentColor = Color.fromARGB(255, 247, 141, 31);
  
  // Background colors
  static const Color backgroundColor = Colors.white;
  static const Color surfaceColor = Color.fromARGB(255, 250, 250, 250);
  
  // Text colors
  static const Color primaryTextColor = Color.fromARGB(255, 30, 30, 30);
  static const Color secondaryTextColor = Color.fromARGB(255, 100, 100, 100);
  
  // Grays
  static const Color primaryGray = Color.fromARGB(255, 150, 150, 150);
  static const Color secondaryGray = Color.fromARGB(255, 211, 211, 211);
  
  // Status colors
  static const Color successColor = Color.fromARGB(255, 76, 175, 80);
  static const Color errorColor = Color.fromARGB(255, 244, 67, 54);
  static const Color warningColor = Color.fromARGB(255, 255, 165, 0);
  static const Color infoColor = Color.fromARGB(255, 33, 150, 243);
  
  // Helper method to create colors with custom opacity
  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }
  
  // Create a complete ThemeData object
  static ThemeData getTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: secondaryColor,
        onSecondary: Colors.white,
        error: errorColor,
        onError: Colors.white,
        background: backgroundColor,
        onBackground: primaryTextColor,
        surface: surfaceColor,
        onSurface: primaryTextColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: secondaryGray,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColorMuted,
          foregroundColor: Colors.white,
        ),
      ),
      cardTheme: CardTheme(
        color: backgroundColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: primaryTextColor,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: primaryTextColor,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: primaryTextColor,
        ),
        bodyMedium: TextStyle(
          color: secondaryTextColor,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: primaryColor, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}