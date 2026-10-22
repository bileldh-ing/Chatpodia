import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Design tokens sampled from the Chatpodia mockup.
/// Bundled (offline) brand font — see assets/google_fonts.
const kFontFamily = 'PlusJakartaSans';

class AppColors {
  AppColors._();

  static const bgDeep = Color(0xFF07141A);
  static const bgBase = Color(0xFF0B1C22);
  static const bgElevated = Color(0xFF10252C);

  static const glowGreen = Color(0xFF2E9E78);
  static const glowTeal = Color(0xFF1C5B5C);
  static const glowLime = Color(0xFF9BC88A);

  static const mint = Color(0xFF3FE0B0);
  static const mintSoft = Color(0xFF8FF0D2);
  static const accent = Color(0xFF26B38A);
  static const accentDark = Color(0xFF168067);

  static const textPrimary = Color(0xFFF4F7F6);
  static const textSecondary = Color(0xFF9AA8AB);
  static const textTertiary = Color(0xFF617175);
  static const textOnLight = Color(0xFF0E1A1D);

  static const glassFill = Color(0x1AFFFFFF);
  static const glassFillStrong = Color(0x26FFFFFF);
  static const glassStroke = Color(0x24FFFFFF);
  static const divider = Color(0x14FFFFFF);

  static const danger = Color(0xFFFF6B6B);
  static const warning = Color(0xFFFFC56B);

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4BE3B5), Color(0xFF1FA17D)],
  );
}

class AppText {
  AppText._();

  static TextStyle _base(double size, FontWeight w, Color c, {double height = 1.3, double ls = 0}) =>
      TextStyle(fontFamily: kFontFamily, fontSize: size, fontWeight: w, color: c, height: height, letterSpacing: ls);

  static TextStyle get display => _base(26, FontWeight.w600, AppColors.textPrimary, height: 1.22, ls: -0.4);
  static TextStyle get title => _base(17, FontWeight.w600, AppColors.textPrimary, ls: -0.2);
  static TextStyle get section => _base(15, FontWeight.w600, AppColors.textPrimary, ls: -0.1);
  static TextStyle get body => _base(14, FontWeight.w400, AppColors.textPrimary, height: 1.45);
  static TextStyle get bodyMuted => _base(14, FontWeight.w400, AppColors.textSecondary, height: 1.45);
  static TextStyle get small => _base(12, FontWeight.w500, AppColors.textPrimary);
  static TextStyle get caption => _base(11, FontWeight.w500, AppColors.textSecondary);
  static TextStyle get transcript => _base(21, FontWeight.w600, AppColors.textPrimary, height: 1.38, ls: -0.3);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true, fontFamily: kFontFamily);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgBase,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.mint,
        surface: AppColors.bgElevated,
        error: AppColors.danger,
      ),
      textTheme: base.textTheme
          .apply(fontFamily: kFontFamily, bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.mint,
        selectionColor: Color(0x553FE0B0),
        selectionHandleColor: AppColors.mint,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}

class Insets {
  Insets._();
  static const radiusChip = 14.0, radiusCard = 18.0, radiusBubble = 16.0;
}
