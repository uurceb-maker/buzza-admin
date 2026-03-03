import 'package:flutter/material.dart';

class AppTheme {
  // ─── Primary Palette ───
  static const Color primary = Color(0xFF775BE6);
  static const Color primaryLight = Color(0xFF9D86F0);
  static const Color primaryDark = Color(0xFF5E43C9);
  static const Color accentPink = Color(0xFFD946EF);

  // ─── Background & Surface ───
  static const Color bgDark = Color(0xFF0A0E27);
  static const Color bgCard = Color(0xFF151A37);
  static const Color bgSurface = Color(0xFF1E1A29);
  static const Color bgInput = Color(0xFF252033);

  // ─── Text ───
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // ─── Status ───
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFEAB308);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ─── Glass ───
  static const Color glassBg = Color(0x0AFFFFFF);
  static const Color glassBorder = Color(0x14FFFFFF);

  // ─── Glass card decoration ───
  static BoxDecoration glassDecoration({double radius = 16, Color? borderColor}) {
    return BoxDecoration(
      color: glassBg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? glassBorder),
    );
  }

  static BoxDecoration glassGradientDecoration({double radius = 20}) {
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xB31E1B26), Color(0xCC14111C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: glassBorder),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 24, offset: const Offset(0, 4))],
    );
  }

  // ─── Status helpers ───
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
      case 'completed': return 'Tamamlandı';
      case 'processing':
      case 'in_progress': return 'İşleniyor';
      case 'partial': return 'Kısmi';
      case 'pending': return 'Bekliyor';
      case 'cancelled':
      case 'canceled': return 'İptal';
      case 'refunded': return 'İade';
      case 'approved': return 'Onaylandı';
      case 'rejected': return 'Reddedildi';
      case 'error': return 'Hata';
      default: return status;
    }
  }

  // ─── Input decoration ───
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
      hintStyle: const TextStyle(color: Color(0x4DFFFFFF), fontSize: 15),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: const Color(0x66FFFFFF), size: 22)
          : null,
      suffixIcon: suffix,
      filled: true,
      fillColor: glassBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primary.withValues(alpha: 0.5), width: 1.5),
      ),
    );
  }

  // ─── ThemeData ───
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accentPink,
        surface: bgSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgInput,
        hintStyle: const TextStyle(color: Color(0x4DFFFFFF)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: glassBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: glassBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: primary.withValues(alpha: 0.5))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Colors.white),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary),
        labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textMuted, letterSpacing: 1),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bgDark,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }
}
