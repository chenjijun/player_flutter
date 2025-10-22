import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const _themeKey = 'app_theme_color';
  static const List<Color> _availableColors = [
    Color(0xFFD43C33), // 网易云红
    Color(0xFF2196F3), // 蓝色
    Color(0xFF4CAF50), // 绿色
    Color(0xFF9C27B0), // 紫色
    Color(0xFFFF9800), // 橙色
  ];
  
  static List<Color> get availableColors => _availableColors;
  
  Color _primaryColor = _availableColors[0];
  
  Color get primaryColor => _primaryColor;
  
  ThemeData get theme => ThemeData(
    primaryColor: _primaryColor,
    scaffoldBackgroundColor: const Color(0xFFFCFCFC),
    colorScheme: ColorScheme.light(
      primary: _primaryColor,
      onPrimary: Colors.white,
      secondary: _primaryColor,
      onSecondary: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      selectedItemColor: _primaryColor,
      unselectedItemColor: const Color(0xFF666666),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: _primaryColor,
      thumbColor: _primaryColor,
      overlayColor: _primaryColor.withOpacity(0.1),
      inactiveTrackColor: const Color(0xFFE6E6E6),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: _primaryColor,
      unselectedLabelColor: const Color(0xFF666666),
      indicatorColor: _primaryColor,
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        color: Color(0xFF333333),
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: TextStyle(
        color: Color(0xFF666666),
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: Color(0xFF333333),
        fontSize: 14,
      ),
    ),
  );

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_themeKey);
    if (colorValue != null) {
      _primaryColor = Color(colorValue);
      notifyListeners();
    }
  }

  Future<void> setThemeColor(Color color) async {
    if (_primaryColor == color) return;
    _primaryColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, color.value);
    notifyListeners();
  }
}