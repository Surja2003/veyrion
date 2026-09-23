import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// DARM visual language: clinical, calm, high-contrast.
/// Dark = deep black; Light = soft "dull white" (never harsh pure white).
class AppTheme {
  AppTheme._();

  static const Color _seed =
      Color(0xFF0E7C86); // calm teal — clinical, not alarming
  static const Color riskLow = Color(0xFF2E7D5B);
  static const Color riskModerate = Color(0xFFB8860B);
  static const Color riskHigh = Color(0xFFC0392B);

  // Deep-black dark palette.
  static const Color _darkBg = Color(0xFF000000);
  static const Color _darkCard = Color(0xFF121316);
  static const Color _darkCardHigh = Color(0xFF1B1D21);
  // Dull-white light palette (soft off-white, easy on the eyes).
  static const Color _lightBg = Color(0xFFF2F1EC);
  static const Color _lightCard = Color(0xFFFAF9F5);

  static Color risk(String band) {
    switch (band) {
      case 'high':
      case 'urgent':
        return riskHigh;
      case 'moderate':
      case 'routine-soon':
        return riskModerate;
      default:
        return riskLow;
    }
  }

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness b) {
    final dark = b == Brightness.dark;
    var scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: b);
    scheme = scheme.copyWith(
      surface: dark ? _darkBg : _lightBg,
      surfaceContainerLowest: dark ? const Color(0xFF0A0B0D) : Colors.white,
      surfaceContainerLow: dark ? _darkCard : _lightCard,
      surfaceContainer: dark ? _darkCard : _lightCard,
      surfaceContainerHigh: dark ? _darkCardHigh : const Color(0xFFECEBE4),
      surfaceContainerHighest:
          dark ? const Color(0xFF23262B) : const Color(0xFFE6E5DE),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
              color:
                  scheme.outlineVariant.withValues(alpha: dark ? 0.35 : 0.5)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? _darkCard : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      snackBarTheme:
          const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// App-wide scroll behaviour: smooth, bouncy (iOS-style) scrolling with a
/// stretch overscroll on ALL platforms and input devices — including mouse/
/// trackpad on large screens — so the scroll feels alive everywhere.
class SmoothScrollBehavior extends MaterialScrollBehavior {
  const SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    // StretchingOverscrollIndicator gives the modern "pull" stretch effect.
    return StretchingOverscrollIndicator(
      axisDirection: details.direction,
      child: child,
    );
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
