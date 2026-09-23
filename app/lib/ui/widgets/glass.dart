import 'dart:ui';

import 'package:flutter/material.dart';

/// Liquid-glass surface: a translucent, softly-blurred panel with a bright top
/// edge and hairline border — the frosted look, kept light enough for
/// mid-range phones (bounded blur, used only on non-scrolling chrome).
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.blur = 22,
    this.radius = 24,
    this.padding = EdgeInsets.zero,
    this.opacity,
  });

  final Widget child;
  final double blur;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double? opacity;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = Theme.of(context).colorScheme.surface;
    final tint = base.withValues(alpha: opacity ?? (dark ? 0.55 : 0.65));
    final borderRadius = BorderRadius.circular(radius);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.06, 1.0],
              colors: [
                Colors.white.withValues(alpha: dark ? 0.08 : 0.18),
                tint,
                base.withValues(
                    alpha: (opacity ?? (dark ? 0.55 : 0.65)) - 0.08),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: dark ? 0.10 : 0.55),
              width: 0.8,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
