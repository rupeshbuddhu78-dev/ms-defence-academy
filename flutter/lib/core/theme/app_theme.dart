import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AcademyColors {
  static const forest = Color(0xFF153E2E);
  static const green = Color(0xFF26734D);
  static const mint = Color(0xFFEAF4EE);
  static const orange = Color(0xFFD9822B);
  static const ink = Color(0xFF1F2924);
  static const muted = Color(0xFF77827B);
  static const surface = Color(0xFFF5F7F5);
  static const line = Color(0xFFE6EBE7);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AcademyColors.surface,
        colorScheme: ColorScheme.fromSeed(
            seedColor: AcademyColors.green,
            primary: AcademyColors.green,
            secondary: AcademyColors.orange,
            surface: Colors.white),
        textTheme: GoogleFonts.poppinsTextTheme().apply(
            bodyColor: AcademyColors.ink, displayColor: AcademyColors.ink),
        appBarTheme: const AppBarTheme(
            backgroundColor: AcademyColors.forest,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: false),
        cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: AcademyColors.line))),
        inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AcademyColors.line)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AcademyColors.line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AcademyColors.green, width: 1.5))),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
                backgroundColor: AcademyColors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)))),
      );
}
