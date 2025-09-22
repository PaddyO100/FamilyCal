import 'package:flutter/material.dart';

class FamilyCalTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: const Color(0xFF5B67F1),
        secondary: const Color(0xFF6F75F3),
        tertiary: const Color(0xFF9D7BFF),
      ),
      scaffoldBackgroundColor: const Color(0xFFF8F9FE),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF14151A),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: const Color(0xFF5B67F1),
        backgroundColor: const Color(0xFFE8E9FF),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      textTheme: base.textTheme.apply(
        fontFamily: 'Inter',
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: const Color(0xFF8C9EFF),
        secondary: const Color(0xFFADB5FF),
        tertiary: const Color(0xFFC7D0FF),
      ),
      scaffoldBackgroundColor: const Color(0xFF101226),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: const Color(0xFF8C9EFF),
        backgroundColor: const Color(0xFF1B1D3D),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
