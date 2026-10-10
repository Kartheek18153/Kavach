import 'package:flutter/material.dart';

/// Shared risk bands for the whole app.
enum RiskLevel { safe, caution, danger }

RiskLevel riskLevelFor(int risk) {
  if (risk >= 61) return RiskLevel.danger;
  if (risk >= 31) return RiskLevel.caution;
  return RiskLevel.safe;
}

extension RiskLevelX on RiskLevel {
  String get label {
    switch (this) {
      case RiskLevel.safe:
        return 'Safe';
      case RiskLevel.caution:
        return 'Be careful';
      case RiskLevel.danger:
        return 'Danger';
    }
  }

  String get telugu {
    switch (this) {
      case RiskLevel.safe:
        return 'సురక్షితం';
      case RiskLevel.caution:
        return 'జాగ్రత్త';
      case RiskLevel.danger:
        return 'ప్రమాదం';
    }
  }
}

/// CyberSafe palette: icy-blue screenshot palette — ice background,
/// white + sky cards, vivid blue actions, deep-navy depth accents.
class CyberSafeColors {
  static const bg0 = Color(0xFFE3F2FD);
  static const bg1 = Color(0xFFCDE6FB);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFEAF4FE);
  static const line = Color(0xFFB4D4F4);

  static const safe = Color(0xFF4D7C0F);
  static const caution = Color(0xFF9C6F1E);
  static const danger = Color(0xFFC14E32);
  static const teal = Color(0xFF1976D2);
  static const blue = Color(0xFF2196F3);
  static const sky = Color(0xFF90CAF9);
  static const violet = Color(0xFF0D47A1);

  static const washTeal = Color(0xFFCFE7FC);
  static const washSafe = Color(0xFFF0F7E6);
  static const washCaution = Color(0xFFFCF6E9);
  static const washDanger = Color(0xFFFBE9E5);

  static const ink = Color(0xFF16283F);
  static const sub = Color(0xFF5B7290);

  static Color forLevel(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return safe;
      case RiskLevel.caution:
        return caution;
      case RiskLevel.danger:
        return danger;
    }
  }

  /// Soft tinted background for a level (for pills, banners, bubbles).
  static Color tintForLevel(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return washSafe;
      case RiskLevel.caution:
        return washCaution;
      case RiskLevel.danger:
        return washDanger;
    }
  }
}

ThemeData cyberSafeTheme() {
  const scheme = ColorScheme.light(
    primary: CyberSafeColors.teal,
    secondary: CyberSafeColors.teal,
    surface: CyberSafeColors.surface,
    error: CyberSafeColors.danger,
    onSurface: CyberSafeColors.ink,
    onSurfaceVariant: CyberSafeColors.sub,
    onPrimary: Colors.white,
  );

  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: CyberSafeColors.bg0,
    colorScheme: scheme,
    iconTheme: const IconThemeData(color: CyberSafeColors.teal),
    appBarTheme: const AppBarTheme(
      backgroundColor: CyberSafeColors.bg0,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: CyberSafeColors.ink),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: CyberSafeColors.ink,
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          height: 1.15,
          color: CyberSafeColors.ink),
      displayMedium: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          height: 1.15,
          color: CyberSafeColors.ink),
      displaySmall: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          height: 1.2,
          color: CyberSafeColors.ink),
      headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          height: 1.15,
          color: CyberSafeColors.ink),
      headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          height: 1.2,
          color: CyberSafeColors.ink),
      headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: CyberSafeColors.ink),
      titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: CyberSafeColors.ink),
      titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: CyberSafeColors.ink),
      titleSmall: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: CyberSafeColors.ink),
      bodyLarge: TextStyle(
          fontSize: 16, height: 1.45, color: CyberSafeColors.ink),
      bodyMedium: TextStyle(
          fontSize: 14.5, height: 1.5, color: CyberSafeColors.ink),
      bodySmall: TextStyle(
          fontSize: 13, height: 1.5, color: CyberSafeColors.sub),
      labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: CyberSafeColors.ink),
      labelMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: CyberSafeColors.sub),
      labelSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: CyberSafeColors.sub),
    ),
    cardTheme: CardThemeData(
      color: CyberSafeColors.surface,
      elevation: 0,
      shadowColor: const Color(0x0F1F2937),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: CyberSafeColors.line),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: CyberSafeColors.surface2,
      selectedColor: CyberSafeColors.washTeal,
      labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: CyberSafeColors.ink),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: CyberSafeColors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: CyberSafeColors.sub, fontSize: 14),
      labelStyle: const TextStyle(
          color: CyberSafeColors.sub,
          fontSize: 14,
          fontWeight: FontWeight.w600),
      floatingLabelStyle: const TextStyle(
          color: CyberSafeColors.teal, fontWeight: FontWeight.w700),
      prefixIconColor: CyberSafeColors.sub,
      suffixIconColor: CyberSafeColors.sub,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: CyberSafeColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: CyberSafeColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: CyberSafeColors.teal, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(48, 54),
        backgroundColor: CyberSafeColors.teal,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: CyberSafeColors.washTeal,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
