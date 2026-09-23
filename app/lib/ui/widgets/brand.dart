import 'package:flutter/material.dart';

/// Veyrion brand mark — renders the logo asset at the requested [size].
/// Drop-in replacement for the old CustomPainter reticle icon.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/veyrion_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        // Avoid flicker on hot-reload / rebuild.
        gaplessPlayback: true,
      ),
    );
  }
}
