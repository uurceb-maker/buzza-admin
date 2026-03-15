import 'package:flutter/material.dart';

class AppTheme {
  // Primary palette
  static const Color primary = Color(0xFF0EA5E9);
  static const Color primaryLight = Color(0xFF38BDF8);
  static const Color primaryDark = Color(0xFF0369A1);

  // Legacy field name kept for compatibility across existing screens.
  static const Color accentPink = Color(0xFF14B8A6);

  // Background & Surface
  static const Color bgDark = Color(0xFF060B14);
  static const Color bgCard = Color(0xFF0F172A);
  static const Color bgSurface = Color(0xFF111E33);
  static const Color bgInput = Color(0xFF17263E);

  // Text
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF94A3B8);

  // Status
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF38BDF8);

  // Glass
  static const Color glassBg = Color(0x1A1E293B);
  static const Color glassBorder = Color(0x3354759A);

  static const LinearGradient appBackgroundGradient = LinearGradient(
    colors: [Color(0xFF050A12), Color(0xFF0A1426), Color(0xFF071023)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient panelGradient = LinearGradient(
    colors: [Color(0xC11A2A42), Color(0xB0142034)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF0284C7), Color(0xFF14B8A6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration appBackgroundDecoration() {
    return const BoxDecoration(gradient: appBackgroundGradient);
  }

  static BoxDecoration shellChromeDecoration({double radius = 18}) {
    return BoxDecoration(
      gradient: panelGradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: glassBorder),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.24),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration glassDecoration({
    double radius = 16,
    Color? borderColor,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          bgCard.withValues(alpha: 0.78),
          bgSurface.withValues(alpha: 0.64),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? glassBorder),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.16),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration glassGradientDecoration({double radius = 20}) {
    return BoxDecoration(
      gradient: panelGradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: glassBorder),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 24,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  // Status helpers
  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'approved':
        return success;
      case 'processing':
      case 'in_progress':
      case 'partial':
        return info;
      case 'pending':
        return warning;
      case 'cancelled':
      case 'canceled':
      case 'rejected':
      case 'refunded':
      case 'error':
        return error;
      default:
        return textSecondary;
    }
  }

  static String statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Tamamlandı';
      case 'processing':
      case 'in_progress':
        return 'İşleniyor';
      case 'partial':
        return 'Kısmi';
      case 'pending':
        return 'Bekliyor';
      case 'cancelled':
      case 'canceled':
        return 'İptal';
      case 'refunded':
        return 'İade';
      case 'approved':
        return 'Onaylandı';
      case 'rejected':
        return 'Reddedildi';
      case 'error':
        return 'Hata';
      default:
        return status;
    }
  }

  // Input decoration
  static InputDecoration inputDecoration({
    required String hint,
    IconData? prefixIcon,
    Widget? suffix,
    String? label,
  }) {
    return InputDecoration(
      hintText: hint,
      labelText: label,
      labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
      hintStyle: const TextStyle(color: Color(0xA694A3B8), fontSize: 15),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: textMuted, size: 22)
          : null,
      suffixIcon: suffix,
      filled: true,
      fillColor: glassBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: primary.withValues(alpha: 0.72),
          width: 1.5,
        ),
      ),
    );
  }

  // ThemeData
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accentPink,
        surface: bgSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgInput.withValues(alpha: 0.94),
        hintStyle: const TextStyle(color: Color(0x4DFFFFFF)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary.withValues(alpha: 0.5)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textMuted,
          letterSpacing: 1,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textSecondary,
          side: const BorderSide(color: glassBorder),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bgSurface.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      cardTheme: CardThemeData(
        color: bgSurface.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: glassBorder, thickness: 0.8),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: primaryLight,
        unselectedItemColor: textMuted,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:
            TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }
}
