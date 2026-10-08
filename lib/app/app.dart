import 'package:flutter/material.dart';

class DojoWalkAdminTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF7F7F7),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF6A00),
        brightness: Brightness.light,
      ),
      fontFamily: 'Arial',
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}
