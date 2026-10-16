import 'package:flutter/material.dart';

/// The only place colours are written. Screens use Theme.of(context) or
/// [AppTokens]; test/theme_test.dart fails on any colour not listed here.
/// A new app replaces these values with its approved palette.
abstract final class AppTokens {
  static const seed = Color(0xFFB08463);

  /// Light-mode buttons: the seed's own tone 40 is a saturated chestnut;
  /// this is the softest brown that keeps white text at 4.5:1.
  static const lightPrimary = Color(0xFF8F6A48);

  static const lightBg = Color(0xFFFAF6F1);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightInk = Color(0xFF2B231C);
  static const lightMuted = Color(0xFF6E6157);

  static const darkBg = Color(0xFF17130F);
  static const darkCard = Color(0xFF221C17);
  static const darkInk = Color(0xFFF1EAE2);
  static const darkMuted = Color(0xFFB3A698);

  static const danger = Color(0xFFB42318);
  static const dangerDark = Color(0xFFF97066);

  /// Skeleton placeholders.
  static const skeletonLight = Color(0xFFEEE5DA);
  static const skeletonDark = Color(0xFF2E2620);

  static const all = <Color>[
    seed, lightPrimary, lightBg, lightCard, lightInk, lightMuted, darkBg, darkCard, darkInk,
    darkMuted, danger, dangerDark, skeletonLight, skeletonDark,
  ];
}

ThemeData appTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppTokens.seed,
    brightness: brightness,
  ).copyWith(
    primary: dark ? null : AppTokens.lightPrimary,
    surface: dark ? AppTokens.darkCard : AppTokens.lightCard,
    onSurface: dark ? AppTokens.darkInk : AppTokens.lightInk,
    onSurfaceVariant: dark ? AppTokens.darkMuted : AppTokens.lightMuted,
    error: dark ? AppTokens.dangerDark : AppTokens.danger,
  );
  return ThemeData(
    colorScheme: scheme,
    fontFamily: 'Rubik',
    scaffoldBackgroundColor: dark ? AppTokens.darkBg : AppTokens.lightBg,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? AppTokens.darkBg : AppTokens.lightBg,
      foregroundColor: dark ? AppTokens.darkInk : AppTokens.lightInk,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: dark ? AppTokens.darkCard : AppTokens.lightCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

Color skeletonColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? AppTokens.skeletonDark
        : AppTokens.skeletonLight;
