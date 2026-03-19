import 'package:flutter/material.dart';

class ThemeService extends ChangeNotifier {
  ThemeService._();
  static final ThemeService _instance = ThemeService._();
  factory ThemeService() => _instance;

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }
}
