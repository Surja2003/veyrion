import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme.dart';

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

/// A Liquid-Glass content card — a drop-in, performant replacement for [Card].
///
/// It reads as frosted glass by being *translucent over the ambient background*
/// (a bright top-edge highlight + hairline border + a faint radial sheen),
/// **without** a per-card `BackdropFilter` — so it stays smooth inside long
/// scrolling lists on mid-range phones. Set [blur] > 0 only for a small number
/// of fixed, hero surfaces where a real frost is worth the cost.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.blur = 0,
    this.tint,
    this.tintStrength = 0.0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;

  /// Optional accent colour bled faintly into the glass (e.g. a risk colour).
  final Color? tint;
  final double tintStrength;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = Theme.of(context).colorScheme.surfaceContainerLow;
    final fill = base.withValues(alpha: dark ? 0.44 : 0.62);
    final br = BorderRadius.circular(radius);

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.10, 1.0],
          colors: [
            Colors.white.withValues(alpha: dark ? 0.10 : 0.26),
            fill,
            base.withValues(alpha: dark ? 0.34 : 0.50),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? 0.12 : 0.60),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.30 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Soft specular sheen in the top-left, like light catching glass.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: br,
                  gradient: RadialGradient(
                    center: const Alignment(-0.8, -1.0),
                    radius: 1.4,
                    colors: [
                      Colors.white.withValues(alpha: dark ? 0.06 : 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (tint != null && tintStrength > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: br,
                    color: tint!.withValues(alpha: tintStrength),
                  ),
                ),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );

    if (blur > 0) {
      surface = BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: surface);
    }
    return ClipRRect(borderRadius: br, child: surface);
  }
}

/// Ambient backdrop that gives the glass something to refract: the base surface
/// colour plus a couple of soft, brand-tinted light "blobs". Cheap (static
/// gradients, no blur) and it makes every translucent [GlassCard] read as glass.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = Theme.of(context).colorScheme.surface;
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: base)),
        // Teal glow, upper area.
        Positioned(
          top: -140,
          left: -100,
          child: _Blob(
              color: AppTheme.risk('low'),
              size: 340,
              alpha: dark ? 0.18 : 0.14),
        ),
        // Warm glow, lower-right.
        Positioned(
          bottom: -160,
          right: -120,
          child: _Blob(
              color: const Color(0xFF0E7C86),
              size: 380,
              alpha: dark ? 0.16 : 0.10),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size, required this.alpha});
  final Color color;
  final double size;
  final double alpha;
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: alpha), Colors.transparent],
          ),
        ),
      ),
    );
  }
}
