import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData build() {
    const sand = Color(0xFFF7F0E4);
    const ink = Color(0xFF15223B);
    const clay = Color(0xFFC76B38);
    const moss = Color(0xFF6D8B74);

    final scheme = ColorScheme.fromSeed(
      seedColor: clay,
      brightness: Brightness.light,
      primary: ink,
      secondary: moss,
      surface: sand,
    );

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: sand,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: sand,
        foregroundColor: ink,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFD6CCBD)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: clay.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
