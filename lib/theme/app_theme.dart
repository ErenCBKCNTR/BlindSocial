import 'package:flutter/material.dart';

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
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.yellow,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.yellow,
        ),
        bodyLarge: TextStyle(
          fontSize: 24,
          color: Colors.white,
        ),
        bodyMedium: TextStyle(
          fontSize: 20,
          color: Colors.white,
        ),
        labelLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.yellow,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF1E1E1E),
        labelStyle: TextStyle(color: Colors.yellow, fontSize: 20),
        hintStyle: TextStyle(color: Colors.grey, fontSize: 18),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.yellow, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.cyan, width: 3),
        ),
      ),
    );
  }

  // Theme 1: Neon Cyberpunk Theme
  static ThemeData get neonCyberpunkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.pinkAccent,
        brightness: Brightness.dark,
        primary: Colors.pinkAccent,
        onPrimary: Colors.white,
        secondary: Colors.blueAccent,
        onSecondary: Colors.white,
        surface: const Color(0xFF0F0F1B),
        onSurface: const Color(0xFFE0E0FF),
        error: Colors.red,
        onError: Colors.white,
        outline: Colors.purpleAccent,
      ),
      scaffoldBackgroundColor: const Color(0xFF05050A),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w900,
          color: Colors.pinkAccent,
          letterSpacing: 2,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: Colors.blueAccent,
        ),
        bodyLarge: TextStyle(
          fontSize: 22,
          color: Color(0xFFE0E0FF),
        ),
        bodyMedium: TextStyle(
          fontSize: 18,
          color: Color(0xFFC0C0E0),
        ),
        labelLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.pinkAccent,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 10,
          shadowColor: Colors.pinkAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.purpleAccent, width: 2),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF151525),
        labelStyle: const TextStyle(color: Colors.pinkAccent, fontSize: 18),
        hintStyle: const TextStyle(color: Colors.white54, fontSize: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.pinkAccent, width: 2.5),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF151525),
        shadowColor: const Color(0x80FF4081),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.blueAccent, width: 1),
        ),
      ),
    );
  }

  // Theme 2: Modern Minimalist Theme
  static ThemeData get modernMinimalistTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.light,
        primary: Colors.indigo,
        onPrimary: Colors.white,
        secondary: Colors.teal,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: Colors.black87,
        error: Colors.redAccent,
        onError: Colors.white,
        outline: Colors.black26,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w300,
          color: Colors.indigo,
        ),
        displayMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w400,
          color: Colors.indigo,
        ),
        bodyLarge: TextStyle(
          fontSize: 20,
          color: Colors.black87,
          fontWeight: FontWeight.w300,
        ),
        bodyMedium: TextStyle(
          fontSize: 18,
          color: Colors.black54,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: Colors.indigo, fontSize: 16),
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.black12, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.indigo, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        shadowColor: Colors.black12,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
