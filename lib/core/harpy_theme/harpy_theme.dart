import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:harpy/core/core.dart';
import 'package:rby/rby.dart';
import 'package:rby/theme/radius_scheme.dart';
import 'package:rby/theme/spacing_scheme.dart';

part 'harpy_text_theme.dart';
part 'harpy_theme_colors.dart';

class HarpyTheme {
  HarpyTheme({
    required this.data,
    required double fontSizeDelta,
    required String displayFont,
    required String bodyFont,
    required bool compact,
  })  : _fontSizeDelta = fontSizeDelta,
        _paddingValue = compact ? 12 : 16 {
    name = data.name;
    colors = HarpyThemeColors(data: data);

    text = HarpyTextTheme(
      brightness: colors.brightness,
      fontSizeDelta: fontSizeDelta,
      displayFont: displayFont,
      bodyFont: bodyFont,
    );

    _setupThemeData();
  }

  final HarpyThemeData data;

  final double _fontSizeDelta;
  final double _paddingValue;

  late final String name;

  late final HarpyThemeColors colors;
  late final HarpyTextTheme text;

  late final ThemeData themeData;

  void _setupThemeData() {
    final shapeTheme = RbyShapeTheme(
      radius: const Radius.circular(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );

    final theme = RbyTheme(
      colorScheme: ColorScheme(
        brightness: colors.brightness,
        primary: colors.primary,
        onPrimary: colors.onPrimary,
        secondary: colors.secondary,
        onSecondary: colors.onSecondary,
        error: colors.error,
        onError: colors.onError,
        onSurface: colors.onSurface,
        surface: colors.averageBackgroundColor,
      ),
      spacingScheme: SpacingScheme(
        xxs: _paddingValue / 4,
        xs: _paddingValue / 2,
        s: _paddingValue * 0.75,
        m: _paddingValue,
        l: _paddingValue * 1.5,
        xl: _paddingValue * 2,
        xxl: _paddingValue * 3,
      ),
      radiusScheme: const RadiusScheme(
        tiny: Radius.circular(4),
        small: Radius.circular(6),
        medium: Radius.circular(9),
        large: Radius.circular(12),
        huge: Radius.circular(24),
      ),
    );

    themeData = theme.data.copyWith(
      textTheme: text.textTheme,

      //
      iconTheme: IconThemeData(
        color: colors.onSurface,
        opacity: 1,
        size: 20 + _fontSizeDelta,
      ),
      cardTheme: CardTheme(
        color: colors.cardColor,
        shape: shapeTheme.shape,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.alternateCardColor,
        actionTextColor: colors.primary,
        disabledActionTextColor: colors.primary.withAlpha(128),
        contentTextStyle: text.textTheme.titleSmall,
        elevation: 0,
        shape: shapeTheme.shape,
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: EdgeInsets.all(_paddingValue),
        border: OutlineInputBorder(borderRadius: shapeTheme.borderRadius),
      ),

      // only used in license page
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        color: colors.averageBackgroundColor,
      ),

      // animation durations
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      extensions: <ThemeExtension<dynamic>>{
        const RbyAnimationTheme(
          short: Duration(milliseconds: 200),
          long: Duration(milliseconds: 400),
        ),
        RbySpacingTheme(
          base: _paddingValue,
          small: _paddingValue / 2,
        ),
        RbyShapeTheme(
          radius: const Radius.circular(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // Add the icon theme with proper builders
        RbyIconDataTheme(
          drawer: (context) => Icon(CupertinoIcons.bars, color: colors.onSurface),
          close: (context) => Icon(CupertinoIcons.xmark, color: colors.onSurface),
          back: (context) => Icon(CupertinoIcons.back, color: colors.onSurface),
          expand: (context) => Icon(CupertinoIcons.chevron_down, color: colors.onSurface),
        ),
      },
    );
  }

  @override
  String toString() {
    return '$runtimeType: $name';
  }
}
