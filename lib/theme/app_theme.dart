import 'package:flutter/material.dart';

class AppTheme {
  static const primaryRed = Color(0xFFD43C33);
  static const backgroundColor = Color(0xFFFCFCFC);
  static const textColor = Color(0xFF333333);
  static const secondaryTextColor = Color(0xFF666666);
  static const dividerColor = Color(0xFFE6E6E6);
  
  static ThemeData get theme => ThemeData(
    primaryColor: primaryRed,
    scaffoldBackgroundColor: backgroundColor,
    colorScheme: ColorScheme.light(
      primary: primaryRed,
      onPrimary: Colors.white,
      secondary: primaryRed,
      onSecondary: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryRed,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: primaryRed,
      unselectedItemColor: secondaryTextColor,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: primaryRed,
      thumbColor: primaryRed,
      overlayColor: primaryRed.withOpacity(0.1),
      inactiveTrackColor: dividerColor,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: primaryRed,
      unselectedLabelColor: secondaryTextColor,
      indicatorColor: primaryRed,
    ),
  );
}