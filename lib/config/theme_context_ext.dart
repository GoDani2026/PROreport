import 'package:flutter/material.dart';

/// Extensiones de BuildContext para acceder a colores del tema
/// de forma dinámica, adaptándose a claro/oscuro automáticamente.
extension ThemeContextExtension on BuildContext {
  // ── Detectores ──────────────────────────────────────────────
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  // ── Superficies ─────────────────────────────────────────────
  Color get surfaceBg => isDarkMode ? const Color(0xFF0A1628) : const Color(0xFFF0F2F5);
  Color get surfaceCard => isDarkMode ? const Color(0xFF132336) : Colors.white;
  Color get surfaceSidebar => isDarkMode ? const Color(0xFF0D1B2A) : const Color(0xFFE8EDF2);
  Color get surfaceInput => isDarkMode ? const Color(0xFF1A2D44) : const Color(0xFFF0F2F5);

  // ── Bordes ──────────────────────────────────────────────────
  Color get borderColor => isDarkMode ? const Color(0xFF1E3456) : const Color(0xFFD0D5DD);
  Color get dividerColor => isDarkMode ? const Color(0xFF1E3456) : const Color(0xFFE0E0E0);

  // ── Texto ───────────────────────────────────────────────────
  Color get textPrimary => isDarkMode ? const Color(0xFFECEFF1) : const Color(0xFF1A1A2E);
  Color get textSecondary => isDarkMode ? const Color(0xFF90A4AE) : const Color(0xFF5C6B7A);
  Color get textMuted => isDarkMode ? const Color(0xFF607D8B) : const Color(0xFF4F4F4F); 

  // ── Colores semáforo (con variante oscura para contraste) ───
  Color get successGreen => const Color(0xFF00E676);
  Color get warningYellow =>  isDarkMode ?  const Color(0xFFFFC107) : const Color.fromARGB(255, 248, 219, 1);
  Color get errorRed => const Color(0xFFFF5252);
  Color get accentOrange => const Color(0xFFFF6B35);
  Color get accentBlue => isDarkMode ? const Color(0xFF42A5F5) : const Color(0xFF1B3A5C);

  // ── Sombras dinámicas ───────────────────────────────────────
  List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  // ── Decoración de tarjeta ───────────────────────────────────
  BoxDecoration cardDecoration({
    Color? color,
    Color? borderColor,
    double radius = 14.0,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: color ?? surfaceCard,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? this.borderColor, width: 0.5),
      boxShadow: shadows ?? cardShadow,
    );
  }

  BoxDecoration statusBadgeDecoration(Color statusColor) {
    return BoxDecoration(
      color: statusColor.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(6.0),
      border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 0.5),
    );
  }

  BoxDecoration iconContainer(Color color, {double radius = 6.0}) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(radius),
    );
  }

  // ── Estilos de texto ────────────────────────────────────────
  TextStyle get headingLg => TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      );
  TextStyle get headingMd => TextStyle(
        color: textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      );
  TextStyle get headingSm => TextStyle(
        color: textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      );
  TextStyle get bodySm => TextStyle(
        color: textSecondary,
        fontSize: 12,
      );
  TextStyle get labelXs => TextStyle(
        color: textMuted,
        fontSize: 10,
      );

  // ── Utilidad ────────────────────────────────────────────────
  Color colorForEstado(String? estado) {
    switch (estado) {
      case 'VIGENTE':
      case 'SI':
      case 'ACTIVO':
        return successGreen;
      case 'VENCIDO':
      case 'NO':
      case 'DESVINCULADO':
        return errorRed;
      default:
        return accentOrange;
    }
  }

  // ── Sidebar (adaptados dinámicamente al modo claro/oscuro) ──
  Color get sidebarTextPrimary => isDarkMode ? const Color(0xFFECEFF1) : const Color(0xFF1A1A2E);
  Color get sidebarTextSecondary => isDarkMode ? const Color(0xFFB0BEC5) : const Color(0xFF5C6B7A);
  Color get sidebarTextMuted => isDarkMode ? const Color(0xFF78909C) : const Color(0xFF9E9E9E);
  Color get sidebarHover => isDarkMode ? Colors.white.withValues(alpha: 0.08) : const Color(0xFF1B3A5C).withValues(alpha: 0.06);
  Color get sidebarActive => isDarkMode ? Colors.white.withValues(alpha: 0.18) : const Color(0xFF1B3A5C).withValues(alpha: 0.12);
}