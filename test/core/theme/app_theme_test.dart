import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voxflow/core/theme/app_colors.dart';
import 'package:voxflow/core/theme/app_spacing.dart';
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
        greaterThanOrEqualTo(3),
        reason: 'The handoff accent is used for emphasized controls and icons.',
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

  test('Windows themes use desktop handoff tokens', () {
    final light = AppTheme.lightFor(TargetPlatform.windows);
    final dark = AppTheme.darkFor(TargetPlatform.windows);

    expect(light.scaffoldBackgroundColor, AppColors.desktopLightCanvas);
    expect(light.colorScheme.surface, AppColors.desktopLightSurface);
    expect(light.colorScheme.onSurface, AppColors.desktopLightTextPrimary);
    expect(
      light.colorScheme.onSurfaceVariant,
      AppColors.desktopLightTextSecondary,
    );
    expect(light.colorScheme.outlineVariant, AppColors.desktopLightBorder);
    expect(light.colorScheme.primary, AppColors.desktopLightAccent);
    expect(light.colorScheme.error, AppColors.desktopLightDanger);
    expect(
      light.extension<AppSemanticColors>()!.success,
      AppColors.desktopLightSuccess,
    );

    expect(dark.scaffoldBackgroundColor, AppColors.desktopDarkCanvas);
    expect(dark.colorScheme.surface, AppColors.desktopDarkSurface);
    expect(dark.colorScheme.onSurface, AppColors.desktopDarkTextPrimary);
    expect(
      dark.colorScheme.onSurfaceVariant,
      AppColors.desktopDarkTextSecondary,
    );
    expect(dark.colorScheme.outlineVariant, AppColors.desktopDarkBorder);
    expect(dark.colorScheme.primary, AppColors.desktopDarkAccent);
    expect(dark.colorScheme.error, AppColors.desktopDarkDanger);
    expect(
      dark.extension<AppSemanticColors>()!.success,
      AppColors.desktopDarkSuccess,
    );

    final desktopCardShape = light.cardTheme.shape! as RoundedRectangleBorder;
    expect(
      desktopCardShape.borderRadius,
      BorderRadius.circular(AppRadii.desktopCard),
    );
  });

  test('Android themes use mobile handoff tokens, radii, and depth', () {
    final light = AppTheme.lightFor(TargetPlatform.android);
    final dark = AppTheme.darkFor(TargetPlatform.android);

    expect(light.scaffoldBackgroundColor, const Color(0xFFF8F9FA));
    expect(light.colorScheme.surface, const Color(0xFFFFFFFF));
    expect(light.colorScheme.onSurface, const Color(0xFF0F172A));
    expect(light.colorScheme.onSurfaceVariant, const Color(0xFF64748B));
    expect(light.colorScheme.outlineVariant, const Color(0xFFE2E8F0));
    expect(light.colorScheme.primary, const Color(0xFF5D5FEF));
    expect(light.colorScheme.error, const Color(0xFFEF4444));
    expect(
      light.extension<AppSemanticColors>()!.success,
      const Color(0xFF10B981),
    );

    expect(dark.scaffoldBackgroundColor, const Color(0xFF121316));
    expect(dark.colorScheme.surface, const Color(0xFF1E1F23));
    expect(dark.colorScheme.onSurface, const Color(0xFFF8FAFC));
    expect(dark.colorScheme.onSurfaceVariant, const Color(0xFF94A3B8));
    expect(dark.colorScheme.outlineVariant, const Color(0xFF2E3038));
    expect(dark.colorScheme.primary, const Color(0xFF6366F1));
    expect(dark.colorScheme.error, const Color(0xFFF87171));
    expect(
      dark.extension<AppSemanticColors>()!.success,
      const Color(0xFF34D399),
    );

    final cardShape = light.cardTheme.shape! as RoundedRectangleBorder;
    final inputShape = light.inputDecorationTheme.border! as OutlineInputBorder;
    final lightEffects = light.extension<AppSurfaceEffects>()!;
    final darkEffects = dark.extension<AppSurfaceEffects>()!;
    expect(cardShape.borderRadius, BorderRadius.circular(AppRadii.mobileCard));
    expect(
      inputShape.borderRadius,
      BorderRadius.circular(AppRadii.mobileControl),
    );
    expect(AppRadii.mobileBadge, 8);
    expect(AppRadii.mobileHero, 28);
    expect(lightEffects.cardShadow.blurRadius, 16);
    expect(lightEffects.floatingShadow.blurRadius, 32);
    expect(lightEffects.glassOpacity, 0.78);
    expect(darkEffects.cardShadow.blurRadius, 16);
    expect(darkEffects.floatingShadow.blurRadius, 40);
    expect(darkEffects.glassOpacity, 0.74);
  });
}

double _contrast(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
