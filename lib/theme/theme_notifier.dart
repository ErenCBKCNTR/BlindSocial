import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class ThemeNotifier extends ValueNotifier<ThemeData> {
  ThemeNotifier() : super(AppTheme.highContrastTheme);

  int _currentThemeIndex = 0;

  int get currentThemeIndex => _currentThemeIndex;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentThemeIndex = prefs.getInt('theme_index') ?? 0;
    _updateTheme();
  }

  Future<void> setTheme(int index) async {
    if (_currentThemeIndex == index) return;
    _currentThemeIndex = index;
    _updateTheme();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_index', index);
  }

  void _updateTheme() {
    switch (_currentThemeIndex) {
      case 1:
        value = AppTheme.neonCyberpunkTheme;
        break;
      case 2:
        value = AppTheme.modernMinimalistTheme;
        break;
      case 0:
      default:
        value = AppTheme.highContrastTheme;
        break;
    }
  }
}

final appThemeNotifier = ThemeNotifier();
