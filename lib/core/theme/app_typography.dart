import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  static const monoFontFamily = 'Cascadia Code';
  static const monoFontFallback = <String>['JetBrains Mono', 'Consolas'];

  static TextStyle numeric(TextStyle? base) {
    return (base ?? const TextStyle()).copyWith(
      fontFamily: monoFontFamily,
      fontFamilyFallback: monoFontFallback,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}
