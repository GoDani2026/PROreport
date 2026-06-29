import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme_context_ext.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.dashboard_rounded,
    this.iconColor,
    this.showLogo = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    final effectiveIconColor = iconColor ?? ctx.accentBlue;
    final now = DateTime.now();
    context.watch<AuthProvider>();
    final dateStr = '${now.day} ${_monthName(now.month)} ${now.year}';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: ctx.dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (showLogo)
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
          if (showLogo) const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Icon(icon, color: effectiveIconColor, size: showLogo ? 28 : 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: ctx.headingLg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(color: ctx.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const _ContratoDropdown(),
          const SizedBox(width: 12),
          const _HeaderBadge(
              icon: Icons.shield_rounded,
              label: 'Seguro',
              color: Color(0xFF00E676)),
          const SizedBox(width: 12),
          const _HeaderBadge(
              icon: Icons.notifications_none_rounded,
              label: '3',
              color: Color(0xFFFFC107)),
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
                Text(
                  dateStr,
                  style: TextStyle(color: ctx.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
              radius: 18,
              backgroundColor: ctx.accentOrange,
              child: Icon(Icons.person, color: Colors.white, size: 20)),
        ],
      ),
    );
  }
}

String _monthName(int month) {
  const names = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
  return names[month - 1];
}

class _ContratoDropdown extends StatelessWidget {
  const _ContratoDropdown();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final contratos = auth.contratosUsuario;

    if (contratos.length <= 1) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: auth.contratoSeleccionadoContexto,
          icon: const Icon(Icons.swap_vert, size: 16),
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          onChanged: (val) {
            if (val != null) {
              auth.actualizarContratoGlobal(val);
            }
          },
          items: contratos.map((codigo) {
            return DropdownMenuItem(
              value: codigo,
              child: Text(codigo),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _HeaderBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

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