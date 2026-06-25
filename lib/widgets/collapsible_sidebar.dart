import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme_context_ext.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

// ──────────────────────────────────────────────────────────────
// MENU ITEM MODEL
// ──────────────────────────────────────────────────────────────
class MenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback? onTap;
  const MenuItem({
    required this.icon,
    required this.label,
    required this.color,
    this.isActive = false,
    this.onTap,
  });
}

// ──────────────────────────────────────────────────────────────
// COLLAPSIBLE SIDEBAR
// ──────────────────────────────────────────────────────────────
class CollapsibleSidebar extends StatefulWidget {
  final Widget child;
  final List<MenuItem> items;

  const CollapsibleSidebar({
    super.key,
    required this.child,
    required this.items,
  });

  @override
  State<CollapsibleSidebar> createState() => _CollapsibleSidebarState();
}

class _CollapsibleSidebarState extends State<CollapsibleSidebar> {
  bool _isExpanded = true;

  void _toggle() {
    setState(() => _isExpanded = !_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    const expandedWidth = 220.0;
    const collapsedWidth = 72.0;
    const duration = Duration(milliseconds: 280);
    const curve = Curves.easeInOutCubic;

    final width = _isExpanded ? expandedWidth : collapsedWidth;

    return Row(
      children: [
        AnimatedContainer(
          duration: duration,
          curve: curve,
          width: width,
          decoration: BoxDecoration(
            color: ctx.surfaceSidebar,
            border: Border(
              right: BorderSide(color: ctx.borderColor, width: 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              _buildHeader(ctx),
              const SizedBox(height: 24),
              ...widget.items.map(
                (item) => _MenuItemTile(
                  item: item,
                  collapsed: !_isExpanded,
                  onTap: () {
                    if (item.onTap != null) item.onTap!();
                  },
                ),
              ),
              const Spacer(),
              if (_isExpanded) _buildThemeSelector(ctx),
              !_isExpanded ? _buildThemeIconButton(ctx) : const SizedBox.shrink(),
              const SizedBox(height: 4),
              _buildUserFooter(ctx),
              const SizedBox(height: 12),
            ],
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }

  Widget _buildHeader(BuildContext ctx) {
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: _isExpanded ? 10 : 8,
          vertical: 8,
        ),
        margin: EdgeInsets.symmetric(
          horizontal: _isExpanded ? 10 : 6,
        ),
        decoration: BoxDecoration(
          color: ctx.surfaceCard,
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(color: ctx.borderColor, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                'Logo.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Enhanced fallback with better error handling
                  return Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: ctx.accentOrange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.assessment_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  );
                },
              ),
            ),
            if (_isExpanded) ...[
              const SizedBox(width: 8),
              Text(
                'ProReport',
                style: TextStyle(
                  color: ctx.sidebarTextPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
            Icon(
              _isExpanded
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              color: ctx.sidebarTextMuted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext ctx) {
    final themeProvider = context.watch<ThemeProvider>();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ctx.surfaceCard,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: ctx.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Apariencia',
            style: TextStyle(
              color: ctx.sidebarTextMuted,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          _ThemeOption(
            icon: Icons.light_mode_rounded,
            label: 'Claro',
            isSelected: themeProvider.mode == AppThemeMode.light,
            onTap: () => themeProvider.setMode(AppThemeMode.light),
            ctx: ctx,
          ),
          const SizedBox(height: 2),
          _ThemeOption(
            icon: Icons.dark_mode_rounded,
            label: 'Oscuro',
            isSelected: themeProvider.mode == AppThemeMode.dark,
            onTap: () => themeProvider.setMode(AppThemeMode.dark),
            ctx: ctx,
          ),
          const SizedBox(height: 2),
          _ThemeOption(
            icon: Icons.brightness_auto_rounded,
            label: 'Automático',
            isSelected: themeProvider.mode == AppThemeMode.system,
            onTap: () => themeProvider.setMode(AppThemeMode.system),
            ctx: ctx,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeIconButton(BuildContext ctx) {
    final themeProvider = context.watch<ThemeProvider>();
    final icon = _getThemeIcon(themeProvider.mode);
    return Tooltip(
      message: 'Tema: ${themeProvider.mode.name.toUpperCase()}',
      child: IconButton(
        icon: Icon(icon, color: ctx.sidebarTextMuted, size: 18),
        onPressed: () => _cycleThemeMode(themeProvider),
        tooltip: 'Cambiar tema',
      ),
    );
  }

  IconData _getThemeIcon(AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.light => Icons.light_mode_rounded,
      AppThemeMode.dark => Icons.dark_mode_rounded,
      AppThemeMode.system => Icons.brightness_auto_rounded,
    };
  }

  void _cycleThemeMode(ThemeProvider themeProvider) {
    final next = switch (themeProvider.mode) {
      AppThemeMode.light => AppThemeMode.dark,
      AppThemeMode.dark => AppThemeMode.system,
      AppThemeMode.system => AppThemeMode.light,
    };
    themeProvider.setMode(next);
  }

  Widget _buildUserFooter(BuildContext ctx) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: _isExpanded ? 10 : 6,
      ),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: ctx.surfaceCard,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: ctx.borderColor, width: 0.5),
      ),
      child: _isExpanded
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: ctx.accentOrange,
                  child: const Icon(Icons.person, color: Colors.white, size: 12),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Daniel O.',
                    style: TextStyle(color: ctx.sidebarTextPrimary, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.logout, color: ctx.errorRed, size: 14),
                  onPressed: () => _showLogoutDialog(ctx),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Cerrar Sesión',
                ),
              ],
            )
          : IconButton(
              icon: Icon(Icons.logout, color: ctx.errorRed, size: 14),
              onPressed: () => _showLogoutDialog(ctx),
              tooltip: 'Cerrar Sesión',
            ),
    );
  }

void _showLogoutDialog(BuildContext ctx) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ctx.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: ctx.errorRed, size: 24),
            const SizedBox(width: 8),
            const Text('Cerrar Sesión'),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas cerrar sesión?',
          style: TextStyle(color: ctx.textSecondary),
        ),
          actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancelar',
              style: TextStyle(color: ctx.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final auth = dialogContext.read<AuthProvider>();
              await auth.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ctx.errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6.0),
              ),
            ),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// THEME OPTION ROW
// ──────────────────────────────────────────────────────────────
class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final BuildContext ctx;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.ctx,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? ctx.accentOrange.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? ctx.accentOrange : ctx.sidebarTextMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? ctx.sidebarTextPrimary : ctx.sidebarTextSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check, size: 12, color: ctx.accentOrange),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// MENU ITEM TILE
// ──────────────────────────────────────────────────────────────
class _MenuItemTile extends StatefulWidget {
  final MenuItem item;
  final bool collapsed;
  final VoidCallback onTap;

  const _MenuItemTile({
    required this.item,
    required this.collapsed,
    required this.onTap,
  });

  @override
  State<_MenuItemTile> createState() => _MenuItemTileState();
}

class _MenuItemTileState extends State<_MenuItemTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    final isActive = widget.item.isActive;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.symmetric(
            horizontal: widget.collapsed ? 6 : 10,
            vertical: 2,
          ),
          padding: widget.collapsed
              ? const EdgeInsets.all(8)
              : const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
          decoration: BoxDecoration(
            color: isActive
                ? ctx.sidebarActive
                : _isHovered
                    ? ctx.sidebarHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6.0),
            border: isActive
                ? Border.all(
                    color: widget.item.color.withValues(alpha: 0.6),
                    width: 1,
                  )
                : _isHovered
                    ? Border.all(
                        color: ctx.sidebarTextMuted.withValues(alpha: 0.3),
                        width: 0.5,
                      )
                    : null,
          ),
          child: widget.collapsed
              ? Center(
                  child: Tooltip(
                    message: widget.item.label,
                    child: Icon(
                      widget.item.icon,
                      color: isActive
                          ? widget.item.color
                          : _isHovered
                              ? ctx.sidebarTextPrimary
                              : ctx.sidebarTextMuted,
                      size: 18,
                    ),
                  ),
                )
              : Row(
                  children: [
                    Icon(
                      widget.item.icon,
                      color: isActive
                          ? widget.item.color
                          : _isHovered
                              ? ctx.sidebarTextSecondary
                              : ctx.sidebarTextMuted,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.item.label,
                        style: TextStyle(
                          color: isActive
                              ? ctx.sidebarTextPrimary
                              : _isHovered
                                  ? ctx.sidebarTextPrimary
                                  : ctx.sidebarTextSecondary,
                          fontSize: 12,
                          fontWeight: isActive || _isHovered
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}