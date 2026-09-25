import 'package:flutter/material.dart';

/// Central design tokens for CRaunch Player. Every color, radius, and
/// duration used across the app should be sourced from here so the
/// "dynamic album sync" feature can mutate the accent at runtime without
/// touching widget code.
class AppTokens {
  const AppTokens._();

  static const Duration microInteraction = Duration(milliseconds: 260);
  static const Duration routeTransition = Duration(milliseconds: 420);
  static const Duration backgroundOpDelayMin = Duration(milliseconds: 1200);
  static const Duration backgroundOpDelayMax = Duration(milliseconds: 2200);

  static const double radiusSm = 10;
  static const double radiusMd = 18;
  static const double radiusLg = 28;

  static const Curve entrance =
      Cubic(0.16, 1.0, 0.30, 1.0); // premium overshoot-free ease-out
  static const Curve exit = Cubic(0.7, 0.0, 0.84, 0.0);
}

class AppColors {
  const AppColors._();

  static const Color backgroundDark = Color(0xFF0A0A0D);
  static const Color surfaceDark = Color(0xFF141418);
  static const Color surfaceElevatedDark = Color(0xFF1C1C22);
  static const Color backgroundLight = Color(0xFFF7F7FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceElevatedLight = Color(0xFFF0F0F4);

  /// Default accent before a track's palette has been extracted.
  static const Color accentDefault = Color(0xFF7B5CFF);
  static const Color accentSecondaryDefault = Color(0xFF00E0C6);
}

/// Holds a live, per-track accent pair produced by the album-art palette
/// extractor. Widgets read this via [AccentScope.of] rather than a fixed
/// theme color, which is what lets edge-glow and gradients react to the
/// currently playing track.
class AppAccent {
  final Color primary;
  final Color secondary;
  const AppAccent({required this.primary, required this.secondary});

  static const AppAccent fallback = AppAccent(
    primary: AppColors.accentDefault,
    secondary: AppColors.accentSecondaryDefault,
  );

  AppAccent lerpTo(AppAccent other, double t) {
    return AppAccent(
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      secondary: Color.lerp(secondary, other.secondary, t) ?? secondary,
    );
  }
}

/// Lets [TweenAnimationBuilder]/[AnimationController] interpolate between
/// two [AppAccent] values — Flutter's Tween machinery needs an explicit
/// lerp implementation for any non-built-in type.
class AppAccentTween extends Tween<AppAccent> {
  AppAccentTween(
      {required AppAccent super.begin, required AppAccent super.end});

  @override
  AppAccent lerp(double t) => begin!.lerpTo(end!, t);
}

class AccentScope extends InheritedWidget {
  final AppAccent accent;
  const AccentScope({super.key, required this.accent, required super.child});

  static AppAccent of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AccentScope>();
    return scope?.accent ?? AppAccent.fallback;
  }

  @override
  bool updateShouldNotify(AccentScope oldWidget) =>
      oldWidget.accent.primary != accent.primary ||
      oldWidget.accent.secondary != accent.secondary;
}

class AppTheme {
  const AppTheme._();

  static ThemeData dark() {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surfaceDark,
        primary: AppColors.accentDefault,
        secondary: AppColors.accentSecondaryDefault,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
    return base.copyWith(
      textTheme: _textTheme(base.textTheme, Colors.white),
    );
  }

  static ThemeData light() {
    final base = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: const ColorScheme.light(
        surface: AppColors.surfaceLight,
        primary: AppColors.accentDefault,
        secondary: AppColors.accentSecondaryDefault,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
    return base.copyWith(
      textTheme: _textTheme(base.textTheme, Colors.black),
    );
  }

  static TextTheme _textTheme(TextTheme base, Color color) {
    return base.apply(
      bodyColor: color,
      displayColor: color,
      fontFamily: '.SF Pro Text', // falls back to platform default on Android
    );
  }
}
