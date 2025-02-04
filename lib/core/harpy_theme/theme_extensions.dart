import 'package:flutter/material.dart';
import 'package:rby/rby.dart';

/// Extension methods for easy access to theme extensions
extension ThemeExtensions on ThemeData {
  /// Access the Harpy icon theme
  RbyIconDataTheme get iconData =>
      extension<RbyIconDataTheme>() ??
      RbyIconDataTheme(
        drawer: _defaultIconBuilder,
        close: _defaultIconBuilder,
        back: _defaultIconBuilder,
        expand: _defaultIconBuilder,
      );
}

Widget _defaultIconBuilder(BuildContext context) => const SizedBox();
