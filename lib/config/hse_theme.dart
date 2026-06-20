import 'package:flutter/material.dart';

/// Tema unificado HSE para toda la aplicación PROreport.
/// Centraliza todos los colores, estilos y dimensiones compartidas
/// entre las pantallas del dashboard, gestión de personal, etc.
class HseTheme {
  // ── Colores base ──────────────────────────────────────────
  static const Color bgDark = Color(0xFF0A1628);
  static const Color sidebarDark = Color(0xFF0D1B2A);
  static const Color cardDark = Color(0xFF132336);
  static const Color cardBorder = Color(0xFF1E3456);
  static const Color accentBlue = Color(0xFF1B3A5C);
  static const Color divider = Color(0xFF1E3456);

  // ── Colores semáforo / estado ─────────────────────────────
  static const Color green = Color(0xFF00E676);
  static const Color yellow = Color(0xFFFFC107);
  static const Color red = Color(0xFFFF5252);
  static const Color orange = Color(0xFFFF6B35);

  // ── Colores de texto ──────────────────────────────────────
  static const Color textPrimary = Color(0xFFECEFF1);
  static const Color textSecondary = Color(0xFF90A4AE);
  static const Color textMuted = Color(0xFF607D8B);

  // ── Sidebar ───────────────────────────────────────────────
  static const double sidebarExpandedWidth = 220.0;
  static const double sidebarCollapsedWidth = 72.0;
  static const Duration sidebarAnimationDuration = Duration(milliseconds: 280);
  static const Curve sidebarAnimationCurve = Curves.easeInOutCubic;

  // ── Bordes redondeados ────────────────────────────────────
  static const double borderRadiusSm = 6.0;
  static const double borderRadiusMd = 10.0;
  static const double borderRadiusLg = 14.0;

  // ── Espaciados ────────────────────────────────────────────
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 24.0;

  // ── Sombras ───────────────────────────────────────────────
  static BoxShadow cardShadow(Color color) {
    return BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 12,
      offset: const Offset(0, 4),
    );
  }

  static final List<BoxShadow> defaultCardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // ── Decoraciones reutilizables ────────────────────────────
  static BoxDecoration cardDecoration({
    Color? color,
    Color? borderColor,
    double radius = borderRadiusLg,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: color ?? cardDark,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? cardBorder,
        width: 0.5,
      ),
      boxShadow: shadows ?? defaultCardShadow,
    );
  }

  static BoxDecoration statusBadgeDecoration(Color statusColor) {
    return BoxDecoration(
      color: statusColor.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(borderRadiusSm),
      border: Border.all(
        color: statusColor.withValues(alpha: 0.3),
        width: 0.5,
      ),
    );
  }

  static BoxDecoration iconContainer(Color color, {double radius = borderRadiusSm}) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(radius),
    );
  }

  // ── Estilos de texto ──────────────────────────────────────
  static const TextStyle headingLg = TextStyle(
    color: textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle headingMd = TextStyle(
    color: textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle headingSm = TextStyle(
    color: textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodySm = TextStyle(
    color: textSecondary,
    fontSize: 12,
  );

  static const TextStyle labelXs = TextStyle(
    color: textMuted,
    fontSize: 10,
  );

  // ── Utilidad ──────────────────────────────────────────────
  static Color getColorForEstado(String? estado) {
    switch (estado) {
      case 'VIGENTE':
      case 'SI':
        return green;
      case 'VENCIDO':
      case 'NO':
        return red;
      case 'DESVINCULADO':
        return red;
      case 'ACTIVO':
        return green;
      default:
        return orange;
    }
  }
}