import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voxflow/core/theme/app_colors.dart';
import 'package:voxflow/core/theme/app_theme.dart';

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    test('$name theme meets core WCAG contrast targets', () {
      final colors = theme.colorScheme;
      final semantics = theme.extension<AppSemanticColors>()!;

      expect(
        _contrast(colors.onSurface, theme.scaffoldBackgroundColor),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(colors.onPrimary, colors.primary),
        greaterThanOrEqualTo(4.5),
      );
      final disabledButtonBackground = Color.alphaBlend(
        colors.onSurface.withValues(alpha: 0.12),
        colors.surface,
      );
      expect(
        _contrast(colors.onSurface, disabledButtonBackground),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(semantics.focus, colors.surface),
        greaterThanOrEqualTo(3),
      );
    });
  }

  test('app bar themes retain their platform baseline heights', () {
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(
        AppTheme.light.appBarTheme.toolbarHeight,
        AppTheme.androidAppBarHeight,
      );

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(
        AppTheme.light.appBarTheme.toolbarHeight,
        AppTheme.windowsAppBarHeight,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

double _contrast(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter =
      firstLuminance > secondLuminance ? firstLuminance : secondLuminance;
  final darker =
      firstLuminance > secondLuminance ? secondLuminance : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
