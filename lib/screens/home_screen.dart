import 'package:flutter/material.dart';
import '../config/theme_context_ext.dart';
import '../widgets/collapsible_sidebar.dart';
import '../widgets/pressable_tile.dart';
import 'solicitud_levantamiento_screen.dart';
import 'gestion_personal_screen.dart';
import 'deteccion_peligro_screen.dart';

// ──────────────────────────────────────────────────────────────
// MAIN SCREEN – Responsive: Web (>=768) or Mobile (<768)
// ──────────────────────────────────────────────────────────────
class HseDashboardScreen extends StatelessWidget {
  const HseDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    final isWide = MediaQuery.of(context).size.width >= 768;
    return Scaffold(
      backgroundColor: ctx.surfaceBg,
      body: isWide ? const _WebDashboard() : const _MobileDashboard(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// WEB DASHBOARD (16:9)
// ══════════════════════════════════════════════════════════════
class _WebDashboard extends StatelessWidget {
  const _WebDashboard();

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return CollapsibleSidebar(
      items: [
        MenuItem(
          icon: Icons.dashboard_rounded,
          label: 'Inicio / Dashboard',
          color: ctx.accentBlue,
          isActive: true,
          onTap: () {
            // Already on dashboard, no navigation needed
          },
        ),
        MenuItem(
          icon: Icons.warning_amber_rounded,
          label: 'Detecciones de Peligro',
          color: ctx.warningYellow,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const DeteccionPeligroScreen()),
          ),
        ),
        MenuItem(
          icon: Icons.route_rounded,
          label: 'Caminatas de Seguridad',
          color: ctx.successGreen,
          onTap: () {
            // Set isActive for this item
            // TODO: Navigate to security walks screen when implemented
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Módulo en desarrollo'),
                backgroundColor: ctx.warningYellow,
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
        MenuItem(
          icon: Icons.assignment_rounded,
          label: 'Solicitud de Levantamiento',
          color: ctx.accentOrange,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const SolicitudLevantamientoScreen()),
          ),
        ),
        MenuItem(
          icon: Icons.people_rounded,
          label: 'Gestionar Personal',
          color: ctx.successGreen,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GestionPersonalScreen()),
          ),
        ),
      ],
      child: Column(
        children: [
          _buildWebHeader(ctx),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SizedBox(height: 20),
                  _KpiRow(),
                  SizedBox(height: 20),
                  _RiskAreasRow(),
                  SizedBox(height: 20),
                  _TrendChart(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MOBILE DASHBOARD (9:16)
// ══════════════════════════════════════════════════════════════
class _MobileDashboard extends StatelessWidget {
  const _MobileDashboard();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _MobileHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SizedBox(height: 8),
                _MobileKpiCards(),
                SizedBox(height: 14),
                _MobileRiskAreas(),
                SizedBox(height: 14),
                _TrendChart(),
                SizedBox(height: 14),
                _MobileReportabilidadMenu(),
                SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// DASHBOARD HEADER (Web)
// ══════════════════════════════════════════════════════════════
Widget _buildWebHeader(BuildContext ctx) {
  return Container(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: ctx.dividerColor, width: 1),
      ),
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.asset(
            'Logo.png',
            width: 28,
            height: 28,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.assessment_rounded,
              color: ctx.accentOrange,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard HSE',
              style: ctx.headingLg,
            ),
            const SizedBox(height: 2),
            Text(
              'Panel de control en tiempo real',
              style: TextStyle(color: ctx.textSecondary, fontSize: 12),
            ),
          ],
        ),
        const Spacer(),
        _HeaderBadge(
            icon: Icons.shield_rounded, label: 'Seguro', color: ctx.successGreen),
        const SizedBox(width: 12),
        _HeaderBadge(
            icon: Icons.notifications_none_rounded,
            label: '3',
            color: ctx.warningYellow),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: ctx.surfaceCard,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  color: ctx.textMuted, size: 14),
              const SizedBox(width: 6),
              Text('14 Jun 2026',
                  style: TextStyle(
                      color: ctx.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        CircleAvatar(
            radius: 18,
            backgroundColor: ctx.accentOrange,
            child: const Icon(Icons.person, color: Colors.white, size: 20)),
      ],
    ),
  );
}

class _HeaderBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _HeaderBadge(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// KPI ROW (Web)
// ══════════════════════════════════════════════════════════════
class _KpiRow extends StatelessWidget {
  const _KpiRow();

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
              title: 'Índice Seguridad LTI',
              value: '98%',
              color: ctx.successGreen,
              icon: Icons.verified_rounded,
              subtitle: 'Meta 95%'),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _KpiCard(
              title: 'Peligros Detectados',
              value: '3',
              color: ctx.warningYellow,
              icon: Icons.warning_rounded,
              subtitle: 'Por gestionar'),
        ),
        SizedBox(width: 14),
        Expanded(
          child: _KpiCard(
              title: 'Incidentes Activos',
              value: '0',
              color: ctx.errorRed,
              icon: Icons.error_outline_rounded,
              subtitle: 'Sin novedades'),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final String subtitle;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: ctx.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: ctx.iconContainer(color),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                    color: color,
                    fontSize: 28,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: ctx.headingSm),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(color: ctx.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// RISK AREAS ROW (Web)
// ══════════════════════════════════════════════════════════════
class _RiskAreasRow extends StatelessWidget {
  const _RiskAreasRow();

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Row(
      children: [
        Expanded(
          child: _RiskAreaCard(
              title: 'Apoyo Operacional a Planta',
              status: 'Alerta Preventiva',
              statusColor: ctx.warningYellow,
              icon: Icons.factory_rounded),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _RiskAreaCard(
              title: 'Planta Nanofiltración',
              status: 'Operación Segura',
              statusColor: ctx.successGreen,
              icon: Icons.water_drop_rounded),
        ),
        SizedBox(width: 14),
        Expanded(
          child: _RiskAreaCard(
              title: 'Termofusión HDPE\ny Encarpertad de Pozas',
              status: 'Monitoreo Preventivo',
              statusColor: ctx.accentOrange,
              icon: Icons.construction_rounded),
        ),
      ],
    );
  }
}

class _RiskAreaCard extends StatelessWidget {
  final String title;
  final String status;
  final Color statusColor;
  final IconData icon;

  const _RiskAreaCard({
    required this.title,
    required this.status,
    required this.statusColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ctx.surfaceCard,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
            color: statusColor.withValues(alpha: 0.3), width: 0.5),
        boxShadow: ctx.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: ctx.iconContainer(statusColor, radius: 10),
            child: Icon(icon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ctx.headingSm),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: statusColor.withValues(alpha: 0.5),
                              blurRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TREND CHART
// ══════════════════════════════════════════════════════════════
class _TrendChart extends StatelessWidget {
  const _TrendChart();

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: ctx.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up_rounded,
                  color: ctx.successGreen, size: 20),
              const SizedBox(width: 8),
              Text('Evolución del Riesgo Mensual',
                  style: ctx.headingMd),
              const Spacer(),
              _ChartLegend(color: ctx.successGreen, label: 'Controlado'),
              const SizedBox(width: 12),
              _ChartLegend(color: ctx.warningYellow, label: 'En riesgo'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: CustomPaint(
              size: const Size(double.infinity, 140),
              painter: _TrendChartPainter(),
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MonthLabel('Ene'), _MonthLabel('Feb'), _MonthLabel('Mar'),
              _MonthLabel('Abr'), _MonthLabel('May'), _MonthLabel('Jun'),
              _MonthLabel('Jul'), _MonthLabel('Ago'), _MonthLabel('Sep'),
              _MonthLabel('Oct'), _MonthLabel('Nov'), _MonthLabel('Dic'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: ctx.textMuted, fontSize: 11)),
      ],
    );
  }
}

class _MonthLabel extends StatelessWidget {
  final String label;
  const _MonthLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Text(label,
        style: TextStyle(
            color: ctx.textMuted, fontSize: 10));
  }
}

class _TrendChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final data = [65.0, 58, 72, 68, 80, 75, 85, 78, 90, 82, 88, 84];
    final data2 = [50.0, 42, 55, 48, 60, 52, 62, 56, 68, 58, 65, 60];
    const orange = Color(0xFFFF6B35);
    const green = Color(0xFF00E676);

    final paintFill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x55FF6B35), Color(0x00FF6B35)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final paintLine = Paint()
      ..color = orange
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintFill2 = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x4400E676), Color(0x0000E676)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final paintLine2 = Paint()
      ..color = green
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = orange
      ..style = PaintingStyle.fill;
    final dotPaint2 = Paint()
      ..color = green
      ..style = PaintingStyle.fill;

    final path = Path();
    final path2 = Path();
    final stepX = w / (data.length - 1);
    const paddingTop = 10.0;
    const paddingBottom = 10.0;
    final range = 100.0;

    const gridPaintColor = Color(0xFF1E3456);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = h - paddingBottom -
          (data[i] / range) * (h - paddingTop - paddingBottom);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    for (int i = 0; i < data2.length; i++) {
      final x = i * stepX;
      final y = h - paddingBottom -
          (data2[i] / range) * (h - paddingTop - paddingBottom);
      if (i == 0) {
        path2.moveTo(x, y);
      } else {
        path2.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path);
    fillPath.lineTo((data.length - 1) * stepX, h - paddingBottom);
    fillPath.lineTo(0, h - paddingBottom);
    fillPath.close();
    canvas.drawPath(fillPath, paintFill);

    final fillPath2 = Path.from(path2);
    fillPath2.lineTo((data2.length - 1) * stepX, h - paddingBottom);
    fillPath2.lineTo(0, h - paddingBottom);
    fillPath2.close();
    canvas.drawPath(fillPath2, paintFill2);

    canvas.drawPath(path, paintLine);
    canvas.drawPath(path2, paintLine2);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = h - paddingBottom -
          (data[i] / range) * (h - paddingTop - paddingBottom);
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
      canvas.drawCircle(
          Offset(x, y), 1.5, Paint()..color = Colors.white);
    }
    for (int i = 0; i < data2.length; i++) {
      final x = i * stepX;
      final y = h - paddingBottom -
          (data2[i] / range) * (h - paddingTop - paddingBottom);
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint2);
      canvas.drawCircle(
          Offset(x, y), 1.5, Paint()..color = Colors.white);
    }

    final gridPaint = Paint()
      ..color = gridPaintColor.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;
    for (int i = 0; i < 4; i++) {
      final y =
          paddingTop + (h - paddingTop - paddingBottom) * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════
// MOBILE COMPONENTS
// ══════════════════════════════════════════════════════════════
class _MobileHeader extends StatelessWidget {
  const _MobileHeader();

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: ctx.dividerColor, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.assessment_rounded,
              color: ctx.accentOrange, size: 22),
          const SizedBox(width: 8),
          Text('ProReport',
              style: TextStyle(
                  color: ctx.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: ctx.warningYellow.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6.0),
            ),
            child: Icon(Icons.notifications_none_rounded,
                color: ctx.warningYellow, size: 18),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
              radius: 14,
              backgroundColor: ctx.accentOrange,
              child: const Icon(Icons.person, color: Colors.white, size: 14)),
        ],
      ),
    );
  }
}

class _MobileKpiCards extends StatelessWidget {
  const _MobileKpiCards();

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Row(
      children: [
        Expanded(
          child: _CompactKpiCard(
              title: 'Índice Seguridad',
              value: '98%',
              color: ctx.successGreen,
              icon: Icons.verified_rounded),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CompactKpiCard(
              title: 'Peligros',
              value: '3',
              color: ctx.warningYellow,
              icon: Icons.warning_rounded),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CompactKpiCard(
              title: 'Incidentes',
              value: '0',
              color: ctx.errorRed,
              icon: Icons.error_outline_rounded),
        ),
      ],
    );
  }
}

class _CompactKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _CompactKpiCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ctx.surfaceCard,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: ctx.borderColor, width: 0.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: ctx.iconContainer(color),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
                color: ctx.textMuted, fontSize: 9),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MobileRiskAreas extends StatelessWidget {
  const _MobileRiskAreas();

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Column(
      children: [
        _CompactRiskCard(
            title: 'Apoyo Operacional a Planta',
            status: 'Alerta Preventiva',
            statusColor: ctx.warningYellow,
            icon: Icons.factory_rounded),
        const SizedBox(height: 8),
        _CompactRiskCard(
            title: 'Planta Nanofiltración',
            status: 'Operación Segura',
            statusColor: ctx.successGreen,
            icon: Icons.water_drop_rounded),
        const SizedBox(height: 8),
        _CompactRiskCard(
            title: 'Termofusión HDPE y Encarpertad de Pozas',
            status: 'Monitoreo Preventivo',
            statusColor: ctx.accentOrange,
            icon: Icons.construction_rounded),
      ],
    );
  }
}

class _CompactRiskCard extends StatelessWidget {
  final String title;
  final String status;
  final Color statusColor;
  final IconData icon;

  const _CompactRiskCard({
    required this.title,
    required this.status,
    required this.statusColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ctx.surfaceCard,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
            color: statusColor.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: ctx.iconContainer(statusColor, radius: 8),
            child: Icon(icon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ctx.headingSm),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right,
              color: ctx.textMuted, size: 18),
        ],
      ),
    );
  }
}

class _MobileReportabilidadMenu extends StatelessWidget {
  const _MobileReportabilidadMenu();

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Container(
      decoration: BoxDecoration(
        color: ctx.surfaceCard,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: ctx.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: ctx.dividerColor, width: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.menu_book_rounded,
                    color: ctx.accentOrange, size: 18),
                const SizedBox(width: 8),
                Text('Reportabilidad',
                    style: ctx.headingMd),
                const Spacer(),
                Icon(Icons.expand_less,
                    color: ctx.textMuted, size: 20),
              ],
            ),
          ),
          _MobileSubItem(
              icon: Icons.warning_amber_rounded,
              label: 'Detecciones de Peligro',
              color: ctx.warningYellow,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const DeteccionPeligroScreen()))),
          _MobileSubItem(
              icon: Icons.route_rounded,
              label: 'Caminatas de Seguridad',
              color: ctx.successGreen),
          _MobileSubItem(
              icon: Icons.assignment_rounded,
              label: 'Solicitud de Levantamiento de Incidentes',
              color: ctx.accentOrange,
              showBorder: false,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const SolicitudLevantamientoScreen()))),
          _MobileSubItem(
              icon: Icons.people_rounded,
              label: 'Gestionar Personal',
              color: ctx.successGreen,
              showBorder: false,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const GestionPersonalScreen()))),
        ],
      ),
    );
  }
}

class _MobileSubItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool showBorder;
  final VoidCallback? onTap;

  const _MobileSubItem({
    required this.icon,
    required this.label,
    required this.color,
    this.showBorder = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return PressableTile(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: showBorder
            ? BoxDecoration(
                border: Border(
                    bottom:
                        BorderSide(color: ctx.dividerColor, width: 0.5)))
            : null,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: ctx.iconContainer(color, radius: 8),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: ctx.textSecondary, fontSize: 13)),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: ctx.textMuted, size: 12),
          ],
        ),
      ),
    );
  }
}