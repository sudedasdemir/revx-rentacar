import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode;

  ThemeProvider({bool isDarkMode = false})
    : _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() async {
    final isDark = _themeMode == ThemeMode.dark;
    _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', !isDark);

    notifyListeners();
  }
}
