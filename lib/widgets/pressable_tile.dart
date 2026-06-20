import 'package:flutter/material.dart';

/// Widget que envuelve elementos de menú con el efecto ripple/splash
/// típico de los botones Material (`ElevatedButton`, `TextButton`).
///
/// Solo aplica efectos si [onTap] no es null.
class PressableTile extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? splashColor;
  final EdgeInsetsGeometry? padding;

  const PressableTile({
    super.key,
    required this.child,
    this.onTap,
    this.splashColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          splashColor: splashColor ?? Colors.white.withValues(alpha: 0.15),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          child: child,
        ),
      ),
    );
  }
}