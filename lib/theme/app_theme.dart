import 'package:flutter/material.dart';
import 'package:blind_social/theme/app_fonts.dart';

class AppTheme {
  // Theme 0: High Contrast Theme (Original)
  static ThemeData get highContrastTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.yellow,
        brightness: Brightness.dark,
        primary: Colors.yellow,
        onPrimary: Colors.black,
        secondary: Colors.cyan,
        onSecondary: Colors.black,
        surface: Colors.black,
        onSurface: Colors.white,
        error: Colors.redAccent,
        onError: Colors.black,
        outline: Colors.grey,
      ),
      scaffoldBackgroundColor: Colors.black,
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: AppFonts.size(32),
          fontWeight: FontWeight.bold,
          color: Colors.yellow,
        ),
        displayMedium: TextStyle(
          fontSize: AppFonts.size(28),
          fontWeight: FontWeight.bold,
          color: Colors.yellow,
        ),
        bodyLarge: TextStyle(fontSize: AppFonts.size(24), color: Colors.white),
        bodyMedium: TextStyle(fontSize: AppFonts.size(20), color: Colors.white),
        labelLarge: TextStyle(
          fontSize: AppFonts.size(22),
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.yellow,
          foregroundColor: Colors.black,
          textStyle: TextStyle(fontSize: AppFonts.size(22), fontWeight: FontWeight.bold),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF1E1E1E),
        labelStyle: TextStyle(color: Colors.yellow, fontSize: AppFonts.size(20)),
        hintStyle: TextStyle(color: Colors.grey, fontSize: AppFonts.size(18)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.yellow, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.cyan, width: 3),
        ),
      ),
    );
  }
}
