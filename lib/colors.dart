import 'package:flutter/material.dart';

class AppColors {
  // Define a single white color to use throughout
  static const white = Color(0xFFFFFFFF);

  // Primary and secondary colors (red theme)
  static const primary = Color(0xFFE74C3C);
  static const secondary = Color(0xFFE74C3C);
  static const accent = Color(0xFFE74C3C);
  static const Color error = Color(0xFFB00020);

  // Background and card colors
  static const background = Color(0xFFF8F9FA);
  static const cardBg = white; // Updated to use consistent white

  // Text colors
  static const textDark = Color(0xFF2C3E50);
  static const textLightGray = Color(0xFF95A5A6);

  // State colors
  static const success = Color(0xFF2ECC71);
  static const veryLightPrimaryColor = Color(0xFFFFEBEE);

  // Basic colors
  static const whiteColor = white; // Updated to use consistent white
  static const blackColor = Color(0xFF000000);
  static const borderColor = Color(0xFFDADBE1);

  // Dark theme colors
  static const backgroundColor = Color(0xFF222222);
  static const grayColor = Color(0xFF757575);
  static const lightGrayColor = Color(0xFFD9D9D9);
  static const cardColor = Color(0xFF373737);

  // Gradient
  static const List<Color> primaryGradient = [
    Color(0xFFE74C3C),
    Color(0xFFC0392B),
  ];

  // Additional colors
  static const black = Color(0xFF000000);
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = white; // Updated to use consistent white

  // Theme specific colors
  static const Color darkFillColor = Color(0xFF121212);
  static const Color lightFillColor = white; // Updated to use consistent white
  static const Color darkGrayColor = Color(0xFF4A4A4A);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color cardColorDark = Color(0xFF121212);

  // Theme accent colors
  static const Color secondaryDark = Color(0xFFC0392B);
  static const Color darkBorderColor = Color(0xFF444444);
  static const Color primaryDark = Color(0xFFE74C3C);
}
