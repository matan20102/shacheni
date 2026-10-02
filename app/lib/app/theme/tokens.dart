import 'package:flutter/material.dart';

/// Design tokens (Phase 4 prototype). Light, warm, rounded — "friendly neighbors",
/// not "property management". All colors/spacing/radii used by the app live here.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF1F6F6B);
  static const primaryDark = Color(0xFF14504D);
  static const primarySoft = Color(0xFFE2F0EE);

  static const accent = Color(0xFFF29A4A);
  static const accentSoft = Color(0xFFFDEBD8);

  static const bg = Color(0xFFF8F5EF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF2EEE6);

  static const ink = Color(0xFF1B2B2A);
  static const inkSoft = Color(0xFF5E6F6D);
  static const inkFaint = Color(0xFF93A09E);
  static const line = Color(0xFFE6E1D8);

  static const success = Color(0xFF2E9E6B);
  static const successSoft = Color(0xFFE0F3E9);
  static const danger = Color(0xFFD64545);
  static const dangerSoft = Color(0xFFFBE3E3);
  static const warn = Color(0xFFC98A00);
  static const warnSoft = Color(0xFFFFF1CC);
  static const info = Color(0xFF3B7DD8);
  static const infoSoft = Color(0xFFE3EEFB);

  /// Avatar palette (deterministic per person).
  static const avatars = <Color>[
    Color(0xFF1F6F6B),
    Color(0xFFF29A4A),
    Color(0xFF7A5AF8),
    Color(0xFFD6537A),
    Color(0xFF3B7DD8),
    Color(0xFF2E9E6B),
  ];
}

class AppSpace {
  AppSpace._();
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;
}

class AppRadius {
  AppRadius._();
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double pill = 999;
}

/// Text styles. Heebo is a bundled variable font (no runtime download); the weight is
/// driven through `fontVariations`, so styles are defined once per weight and not
/// re-weighted with `copyWith(fontWeight: …)`.
class AppText {
  AppText._();

  static TextStyle _t(double size, int weight, Color color, {double height = 1.35}) =>
      TextStyle(
        fontFamily: 'Heebo',
        fontSize: size,
        fontWeight: FontWeight.values[(weight ~/ 100) - 1],
        fontVariations: [FontVariation('wght', weight.toDouble())],
        color: color,
        height: height,
      );

  static TextStyle get display => _t(30, 800, AppColors.ink, height: 1.15);
  static TextStyle get h1 => _t(24, 700, AppColors.ink, height: 1.2);
  static TextStyle get h2 => _t(19, 700, AppColors.ink, height: 1.25);
  static TextStyle get h3 => _t(16, 700, AppColors.ink);
  static TextStyle get body => _t(15, 400, AppColors.ink, height: 1.45);
  static TextStyle get bodyMedium => _t(15, 500, AppColors.ink, height: 1.45);
  static TextStyle get bodyBold => _t(15, 700, AppColors.ink, height: 1.45);
  static TextStyle get small => _t(13, 400, AppColors.inkSoft);
  static TextStyle get smallBold => _t(13, 700, AppColors.inkSoft);
  static TextStyle get tiny => _t(11.5, 500, AppColors.inkSoft);
  static TextStyle get button => _t(16, 700, Colors.white, height: 1.2);
  static TextStyle get price => _t(20, 800, AppColors.primary, height: 1.1);
  static TextStyle get code => _t(40, 800, AppColors.primary, height: 1.0);
}
