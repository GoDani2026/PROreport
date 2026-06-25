import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/hse_theme.dart';
import '../providers/auth_provider.dart';

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
    final width = _isExpanded
        ? HseTheme.sidebarExpandedWidth
        : HseTheme.sidebarCollapsedWidth;

    return Row(
      children: [
        AnimatedContainer(
          duration: HseTheme.sidebarAnimationDuration,
          curve: HseTheme.sidebarAnimationCurve,
          width: width,
          decoration: const BoxDecoration(
            color: HseTheme.sidebarDark,
            border: Border(
              right: BorderSide(color: HseTheme.divider, width: 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              _buildHeader(),
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
              _buildUserFooter(),
              const SizedBox(height: 12),
            ],
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }

  Widget _buildHeader() {
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
          color: HseTheme.cardDark,
          borderRadius: BorderRadius.circular(HseTheme.borderRadiusSm),
          border: Border.all(color: HseTheme.cardBorder, width: 0.5),
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
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 24,
                  height: 24,
                  color: HseTheme.orange,
                  child: const Icon(
                    Icons.assessment_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
            if (_isExpanded) ...[
              const SizedBox(width: 8),
              const Text(
                'ProReport',
                style: TextStyle(
                  color: HseTheme.textPrimary,
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
              color: HseTheme.textMuted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserFooter() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: _isExpanded ? 10 : 6,
      ),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: HseTheme.cardDark,
        borderRadius: BorderRadius.circular(HseTheme.borderRadiusSm),
        border: Border.all(color: HseTheme.cardBorder, width: 0.5),
      ),
      child: _isExpanded
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 12,
                  backgroundColor: HseTheme.orange,
                  child: Icon(Icons.person, color: Colors.white, size: 12),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Daniel O.',
                    style: TextStyle(color: HseTheme.textPrimary, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.logout, color: HseTheme.red, size: 14),
                  onPressed: () => _showLogoutDialog(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Cerrar Sesión',
                ),
              ],
            )
          : IconButton(
              icon: Icon(Icons.logout, color: HseTheme.red, size: 14),
              onPressed: () => _showLogoutDialog(),
              tooltip: 'Cerrar Sesión',
            ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HseTheme.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HseTheme.borderRadiusMd),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: HseTheme.red, size: 24),
            SizedBox(width: 8),
            Text('Cerrar Sesión'),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que deseas cerrar sesión?',
          style: TextStyle(color: HseTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: HseTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Cerrar diálogo
              final auth = context.read<AuthProvider>();
              await auth.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: HseTheme.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(HseTheme.borderRadiusSm),
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
                ? HseTheme.accentBlue.withValues(alpha: 0.4)
                : _isHovered
                    ? HseTheme.accentBlue.withValues(alpha: 0.2)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(HseTheme.borderRadiusSm),
            border: isActive
                ? Border.all(
                    color: widget.item.color.withValues(alpha: 0.6),
                    width: 1,
                  )
                : _isHovered
                    ? Border.all(
                        color: HseTheme.textMuted.withValues(alpha: 0.3),
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
                              ? HseTheme.textPrimary
                              : HseTheme.textMuted,
                      size: 18,
                    ),
                  ),
                )
              : Row(
                  children: [
                    Icon(
                      widget.item.icon,
                      color: isActive
                          ? HseTheme.orange
                          : _isHovered
                              ? HseTheme.textSecondary
                              : HseTheme.textMuted,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.item.label,
                        style: TextStyle(
                          color: isActive
                              ? HseTheme.textPrimary
                              : _isHovered
                                  ? HseTheme.textPrimary
                                  : HseTheme.textSecondary,
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