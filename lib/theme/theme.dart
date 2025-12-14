import 'package:flutter/material.dart';

class AppTheme {
  // Define a single white color
  static const white = Color(0xFFFFFFFF);

  // Primary colors
  static const secondary = Color(0xFFE74C3C); // Already red
  static const tertiaryColor = Color(0xFFE57373); // Changed to light red
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color surfaceColor = Color(0xFFF8FAFC);

  // Text colors
  static const textPrimary = Color(0xFF2C3E50); // Dark gray instead of purple
  static const textSecondary = Color(0xFF757575); // Changed to neutral gray

  // State colors
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color textLight = white; // Updated to use consistent white

  // Background colors
  static const Color darkBackgroundColor = Color(0xFF121212);
  static const Color borderColor = Color(0xFFCCCCCC);
  static const Color darkFillColor = Color(0xFF121212);
  static const Color lightFillColor = white; // Updated to use consistent white

  static ThemeData get LightTheme {
    return ThemeData(
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.light(
        primary: secondary,
        secondary: secondary,
        tertiary: tertiaryColor,
        surface: surfaceColor,
        error: error,
        onPrimary: white, // Updated to use consistent white
        onSecondary: white, // Updated to use consistent white
        onSurface: textPrimary,
      ),
      fontFamily: 'Poppins',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
      ),
    );
  }
}
