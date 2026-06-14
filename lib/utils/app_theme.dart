// lib/utils/app_theme.dart
import 'package:flutter/material.dart';
import 'constants.dart';

final Color kNavy = Color(AppConstants.colorNavy);
final Color kGold = Color(AppConstants.colorGold);
final Color kGoldLight = Color(AppConstants.colorGoldLight);

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Color(AppConstants.colorNavy),
      primary: Color(AppConstants.colorNavy),
      secondary: Color(AppConstants.colorGold),
      brightness: Brightness.light,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Color(AppConstants.colorNavy),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.2,
      ),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: Color(AppConstants.colorNavy),
      elevation: 4,
    ),
    scaffoldBackgroundColor: const Color(0xFFF4F6FA),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      margin: EdgeInsets.zero,
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      bodyMedium: TextStyle(fontSize: 13),
      bodySmall: TextStyle(fontSize: 11),
    ),
  );
}
